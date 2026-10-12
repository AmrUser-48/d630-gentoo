#!/usr/bin/env bash
set -Eeuo pipefail

# Export Portage binary packages as GitHub Release assets. Each shard stays
# comfortably below GitHub's per-asset upload limit. Package paths inside each
# archive remain relative to PKGDIR so they can be extracted directly there.
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 /path/to/PKGDIR /path/to/release-assets [MAX_SHARD_BYTES]" >&2
    exit 2
fi

src="$(realpath "$1")"
dest="$(realpath -m "$2")"
max_bytes="${3:-${MAX_SHARD_BYTES:-1500000000}}"

[[ -d "$src" ]] || { echo "Missing PKGDIR: $src" >&2; exit 2; }
[[ "$max_bytes" =~ ^[0-9]+$ ]] && (( max_bytes >= 1048576 )) ||
    { echo "MAX_SHARD_BYTES must be an integer of at least 1 MiB." >&2; exit 2; }
command -v python3 >/dev/null
command -v tar >/dev/null
command -v zstd >/dev/null

mkdir -p "$dest"
find "$dest" -maxdepth 1 -type f -name 'binpkgs-part-*.tar.zst' -delete
rm -f "$dest/PACKAGE-LIST.txt"

python3 - "$src" "$dest" "$max_bytes" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
out = Path(sys.argv[2])
max_bytes = int(sys.argv[3])

suffixes = (".gpkg.tar", ".tbz2")
files = sorted(
    (p for p in root.rglob("*") if p.is_file() and p.name.endswith(suffixes)),
    key=lambda p: p.relative_to(root).as_posix(),
)
if not files:
    print(f"No GPKG/XPAK binpkgs found under {root}", file=sys.stderr)
    sys.exit(3)

sizes = {p: p.stat().st_size for p in files}
oversize = [(p, sizes[p]) for p in files if sizes[p] > max_bytes]
if oversize:
    for path, size in oversize:
        print(
            f"Package is larger than the shard limit ({size} > {max_bytes} bytes): "
            f"{path.relative_to(root)}",
            file=sys.stderr,
        )
    print("Lowering shard size cannot split a single package; publish it separately.", file=sys.stderr)
    sys.exit(4)

groups = []
current = []
current_size = 0
for path in files:
    size = sizes[path]
    if current and current_size + size > max_bytes:
        groups.append(current)
        current = []
        current_size = 0
    current.append(path)
    current_size += size
if current:
    groups.append(current)

listing = ["# Shard\tSizeBytes\tPackagePath"]
for index, group in enumerate(groups, start=1):
    shard_name = f"binpkgs-part-{index:03d}.tar.zst"
    list_path = out / f".{shard_name}.files0"
    archive_path = out / shard_name
    relative_paths = [p.relative_to(root).as_posix() for p in group]
    with list_path.open("wb") as f:
        for rel in relative_paths:
            f.write(os.fsencode(rel))
            f.write(b"\0")
    command = [
        "tar",
        "--use-compress-program=zstd -T0 -1",
        "-cf",
        str(archive_path),
        "-C",
        str(root),
        "--null",
        "-T",
        str(list_path),
    ]
    subprocess.run(command, check=True)
    list_path.unlink()
    actual_size = archive_path.stat().st_size
    if actual_size >= 2_000_000_000:
        raise SystemExit(
            f"{shard_name} is {actual_size} bytes; this exceeds the safety limit for a release asset."
        )
    for path in group:
        listing.append(
            f"{shard_name}\t{sizes[path]}\t{path.relative_to(root).as_posix()}"
        )
    print(
        f"Created {shard_name}: {len(group)} package(s), "
        f"{sum(sizes[p] for p in group)} input bytes, {actual_size} archive bytes"
    )

(out / "PACKAGE-LIST.txt").write_text("\n".join(listing) + "\n", encoding="utf-8")
print(f"Packaged {len(files)} binary packages in {len(groups)} release shard(s).")
PY
