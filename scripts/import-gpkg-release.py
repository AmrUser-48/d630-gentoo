#!/usr/bin/env python3
"""Import checksum-verified GPKG build variants from a GitHub release into Portage PKGDIR."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
import os
import pathlib
import re
import shutil
import subprocess
import tarfile
import time
import urllib.request


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def get_release(url: str, token: str | None) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "d630-gpkg-import",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def download(asset: dict, directory: pathlib.Path) -> pathlib.Path:
    name = asset["name"]
    match = re.fullmatch(r"sha256:([0-9a-fA-F]{64})", asset.get("digest") or "")
    if not match:
        raise RuntimeError(f"{name}: GitHub asset has no SHA-256 digest")
    expected_hash = match.group(1).lower()
    expected_size = int(asset["size"])
    target = directory / name
    request = urllib.request.Request(
        asset["browser_download_url"],
        headers={"User-Agent": "d630-gpkg-import"},
    )
    last_error: Exception | None = None
    for attempt in range(1, 4):
        partial = target.with_name(target.name + ".part")
        digest = hashlib.sha256()
        size = 0
        try:
            with urllib.request.urlopen(request, timeout=180) as response, partial.open("wb") as output:
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    output.write(block)
                    digest.update(block)
                    size += len(block)
            if size != expected_size or digest.hexdigest() != expected_hash:
                raise RuntimeError(f"{name}: size or SHA-256 verification failed")
            os.replace(partial, target)
            return target
        except Exception as error:
            last_error = error
            partial.unlink(missing_ok=True)
            if attempt < 3:
                time.sleep(attempt * 2)
    raise RuntimeError(f"{name}: download failed after 3 attempts: {last_error}")


def package_metadata(path: pathlib.Path) -> dict[str, str]:
    with tarfile.open(path, mode="r:") as outer:
        members = [
            member for member in outer.getmembers()
            if member.isfile()
            and pathlib.PurePosixPath(member.name).name.startswith("metadata.tar")
        ]
        if len(members) != 1:
            raise RuntimeError(f"{path.name}: expected one nested metadata archive")
        member = members[0]
        stream = outer.extractfile(member)
        if stream is None:
            raise RuntimeError(f"{path.name}: cannot read nested metadata")
        raw_metadata = stream.read()

    if member.name.lower().endswith((".zst", ".zstd")):
        decoded = subprocess.run(
            ["zstd", "-q", "-d", "-c"],
            input=raw_metadata,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if decoded.returncode:
            raise RuntimeError(
                f"{path.name}: zstd metadata decode failed: "
                f"{decoded.stderr.decode(errors='replace')}"
            )
        raw_metadata = decoded.stdout

    wanted = {"CATEGORY", "PN", "PF", "BUILD_ID", "SLOT", "USE", "repository"}
    values: dict[str, str] = {}
    with tarfile.open(fileobj=io.BytesIO(raw_metadata), mode="r:*") as metadata:
        for item in metadata.getmembers():
            key = pathlib.PurePosixPath(item.name).name
            if key not in wanted or key in values or not item.isfile():
                continue
            content = metadata.extractfile(item)
            if content is not None:
                values[key] = content.read().decode("utf-8", errors="replace").strip()

    for key in ("CATEGORY", "PF"):
        if not values.get(key):
            raise RuntimeError(f"{path.name}: metadata is missing {key}")
    # Gentoo GPKG metadata stores CATEGORY and PF; PN is not guaranteed.
    # Recover PN from PF = PN-PV, where Gentoo PV always starts with a digit.
    if not values.get("PN"):
        match = re.fullmatch(r"(.+)-([0-9].*)", values["PF"])
        if not match:
            raise RuntimeError(f"{path.name}: cannot derive PN from PF={values['PF']!r}")
        values["PN"] = match.group(1)
    if not values.get("BUILD_ID"):
        match = re.search(r"-(\d+)\.gpkg\.tar$", path.name)
        if not match:
            raise RuntimeError(f"{path.name}: BUILD_ID missing from metadata and filename")
        values["BUILD_ID"] = match.group(1)

    for key in ("CATEGORY", "PN", "PF", "BUILD_ID"):
        if values[key] in {"", ".", ".."} or "/" in values[key]:
            raise RuntimeError(f"{path.name}: unsafe {key} metadata")
    if not re.fullmatch(r"\d+", values["BUILD_ID"]):
        raise RuntimeError(f"{path.name}: invalid BUILD_ID {values['BUILD_ID']!r}")
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", "AmrUser-48/d630-gentoo"))
    parser.add_argument("--tag", default="v0.2.0")
    parser.add_argument("--pkgdir", required=True)
    parser.add_argument("--workdir", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise SystemExit(f"Invalid GitHub repository: {args.repository!r}")

    workdir = pathlib.Path(args.workdir)
    downloads = workdir / "downloads"
    backups = workdir / "replaced-same-build-id"
    pkgdir = pathlib.Path(args.pkgdir)
    report = pathlib.Path(args.report)
    downloads.mkdir(parents=True, exist_ok=True)
    pkgdir.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)

    release = get_release(
        f"https://api.github.com/repos/{args.repository}/releases/tags/{args.tag}",
        os.environ.get("GH_TOKEN"),
    )
    assets = sorted(
        (asset for asset in release.get("assets", []) if asset.get("name", "").endswith(".gpkg.tar")),
        key=lambda asset: asset["name"],
    )
    if len(assets) < 100:
        raise SystemExit(f"Release {args.tag} contains only {len(assets)} GPKG assets; refusing a partial import.")

    print(
        f"Release {args.tag}: {len(assets)} GPKG files "
        f"({sum(int(asset['size']) for asset in assets):,} bytes); preserve every BUILD_ID."
    )
    rows: list[str] = []
    added = identical = replaced = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = {
            executor.submit(download, asset, downloads): asset["name"]
            for asset in assets
        }
        for number, future in enumerate(concurrent.futures.as_completed(futures), start=1):
            asset_name = futures[future]
            source = future.result()
            info = package_metadata(source)
            destination_dir = pkgdir / info["CATEGORY"] / info["PN"]
            destination_dir.mkdir(parents=True, exist_ok=True)
            destination = destination_dir / f"{info['PF']}-{info['BUILD_ID']}.gpkg.tar"
            digest = sha256(source)
            action = "added"

            if destination.exists():
                if sha256(destination) == digest:
                    action = "identical"
                    identical += 1
                else:
                    backup_dir = backups / info["CATEGORY"] / info["PN"]
                    backup_dir.mkdir(parents=True, exist_ok=True)
                    backup = backup_dir / destination.name
                    if backup.exists():
                        backup = backup.with_name(backup.name + ".saved-copy")
                    shutil.copy2(destination, backup)
                    shutil.copy2(source, destination)
                    action = "release-replaced-existing-build-id"
                    replaced += 1
            else:
                shutil.copy2(source, destination)
                added += 1

            rows.append("\t".join([
                action,
                info["CATEGORY"],
                info["PN"],
                info["PF"],
                info["BUILD_ID"],
                info.get("SLOT", ""),
                info.get("USE", ""),
                info.get("repository", ""),
                asset_name,
                digest,
            ]))
            source.unlink(missing_ok=True)
            if number % 32 == 0 or number == len(assets):
                print(f"Verified and imported {number}/{len(assets)} GPKG assets.")

    rows.sort(key=lambda row: (row.split("\t")[1], row.split("\t")[2], row.split("\t")[4]))
    report.write_text(
        "ACTION\tCATEGORY\tPN\tPF\tBUILD_ID\tSLOT\tUSE\tREPOSITORY\tASSET\tSHA256\n"
        + "\n".join(rows)
        + "\n",
        encoding="utf-8",
    )
    print(f"Complete: {added} added, {identical} identical, {replaced} same-BUILD_ID files replaced.")
    print(f"Variant/USE report: {report}")
    if replaced:
        print(f"Original package files preserved under: {backups}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
