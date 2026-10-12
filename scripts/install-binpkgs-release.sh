#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "Usage: $0 <run-id|binpkgs-run-id>" >&2
    echo "Downloads a persistent d630-gentoo Release and imports its binary packages into Portage PKGDIR." >&2
    exit 2
}
[[ $# -eq 1 ]] || usage
(( EUID == 0 )) || { echo "Run as root, e.g. sudo $0 38291001362" >&2; exit 1; }

tag="$1"
tag="${tag#binpkgs-}"
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || usage

for tool in curl python3 tar zstd sha256sum portageq emaint; do
    command -v "$tool" >/dev/null || { echo "Required tool not found: $tool" >&2; exit 1; }
done

pkgdir="$(portageq envvar PKGDIR)"
[[ -n "$pkgdir" && "$pkgdir" == /* ]] || pkgdir=/var/cache/binpkgs
mkdir -p "$pkgdir"
work="$(mktemp -d "${TMPDIR:-/var/tmp}/d630-binpkgs.XXXXXXXX")"
trap 'rm -rf "$work"' EXIT

api="https://api.github.com/repos/AmrUser-48/d630-gentoo/releases/tags/binpkgs-$tag"
echo "Reading package release: binpkgs-$tag"
curl --fail --location --retry 3 --silent --show-error \
    -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: d630-gentoo-binpkg-importer' \
    "$api" -o "$work/release.json"

python3 - "$work/release.json" > "$work/assets.tsv" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    release = json.load(f)
assets = release.get("assets", [])
checksums = [a for a in assets if a.get("name") == "SHA256SUMS"]
parts = sorted(
    (a for a in assets if re.fullmatch(r"binpkgs-part-\d+\.tar\.zst", a.get("name", ""))),
    key=lambda a: a["name"],
)
if not checksums or not parts:
    raise SystemExit(
        "This release has no binpkg shards/SHA256SUMS. Check the source run and its artifact."
    )
for asset in checksums + parts:
    print(f'{asset["name"]}\t{asset["browser_download_url"]}')
PY

checksum_url=""
while IFS=$'\t' read -r name url; do
    if [[ "$name" == "SHA256SUMS" ]]; then checksum_url="$url"; break; fi
done < "$work/assets.tsv"
[[ -n "$checksum_url" ]] || { echo "Release has no SHA256SUMS asset." >&2; exit 1; }
curl --fail --location --retry 3 --silent --show-error "$checksum_url" -o "$work/SHA256SUMS"

echo "Importing into PKGDIR=$pkgdir"
count=0
while IFS=$'\t' read -r name url; do
    [[ "$name" == "SHA256SUMS" ]] && continue
    [[ "$name" =~ ^binpkgs-part-[0-9]+\.tar\.zst$ ]] || continue
    echo "Downloading $name"
    curl --fail --location --retry 3 --show-error "$url" -o "$work/$name"
    (
        cd "$work"
        sha256sum --check --ignore-missing SHA256SUMS
    )
    tar --use-compress-program=unzstd -xf "$work/$name" -C "$pkgdir"
    rm -f "$work/$name"
    count=$((count + 1))
done < "$work/assets.tsv"

(( count > 0 )) || { echo "No package shards were imported." >&2; exit 1; }
echo "Refreshing the local Portage binpkg index..."
emaint binhost --fix
echo
echo "Imported $count package shard(s) into $pkgdir."
echo "Review available binaries with: emerge --ask --verbose --usepkgonly --pretend <atoms>"
echo "Install selected packages with: emerge --ask --verbose --usepkgonly <atoms>"
