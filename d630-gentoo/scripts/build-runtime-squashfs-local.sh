#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "d630-local-squashfs: ERROR: $*" >&2; exit 2; }
usage() {
  echo "Usage: sudo $0 <boot-directory> [scratch-directory] [existing-gentoo-binpkgs.tar.zst]" >&2
  exit 2
}

[[ "$EUID" -eq 0 ]] || die "run with sudo"
[[ $# -ge 1 && $# -le 3 ]] || usage

DEST="$(realpath -m "$1")"
[[ "$DEST" != "/" ]] || die "refusing to write to /"
mkdir -p "$DEST"
[[ ! -e "$DEST/squashfs" ]] || die "refusing to overwrite $DEST/squashfs; move the old image first"

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ -x "$REPO/d630-gentoo/scripts/build-runtime-squashfs.sh" ]] || die "repository checkout is incomplete"
WORK_BASE="${2:-$(dirname "$DEST")/.d630-gentoo-build}"
WORK_BASE="$(realpath -m "$WORK_BASE")"
[[ "$WORK_BASE" != "$DEST" ]] || die "scratch directory must differ from the boot directory"
case "$WORK_BASE/" in "$DEST/"*) die "scratch directory must be outside the boot directory" ;; esac
mkdir -p "$WORK_BASE"

available_mb() { df -Pm --output=avail "$1" | tail -n 1 | tr -d ' '; }
WORK_FREE="$(available_mb "$WORK_BASE")"
DEST_FREE="$(available_mb "$DEST")"
(( WORK_FREE >= 6000 )) || die "scratch filesystem needs 6000 MB free; found ${WORK_FREE} MB at $WORK_BASE"
(( DEST_FREE >= 1000 )) || die "output filesystem needs 1000 MB free; found ${DEST_FREE} MB at $DEST"

for tool in curl sha256sum zstd unzstd tar xz rsync mksquashfs unsquashfs chroot mount umount realpath findmnt; do
  command -v "$tool" >/dev/null || die "missing host tool '$tool'; install curl ca-certificates xz-utils zstd rsync squashfs-tools e2fsprogs util-linux"
done
WORK_FS="$(findmnt -no FSTYPE -T "$WORK_BASE" | head -n 1)"
case "$WORK_FS" in
  ext2|ext3|ext4|btrfs|xfs|f2fs|zfs) ;;
  *) die "scratch filesystem '$WORK_FS' cannot safely hold a Gentoo root; pass a work directory on ext4/Btrfs/XFS/F2FS (the boot directory may be FAT/NTFS)" ;;
esac

PKG_URL="https://github.com/AmrUser-48/d630-gentoo/releases/download/gentoo-core2-2026.10.14/gentoo-binpkgs.tar.zst"
PKG_SHA256="d2634d6f1266dd21c5b902185c2574042ce4c494be7a13f7b841b0de9835708c"
if [[ $# -eq 3 ]]; then
  PKG_ARCHIVE="$(realpath "$3")"
  [[ -s "$PKG_ARCHIVE" ]] || die "package archive not found: $PKG_ARCHIVE"
  case "$PKG_ARCHIVE" in "$WORK_BASE"/*) die "existing package archive must be outside scratch directory so it isn't deleted on success" ;; esac
else
  PKG_ARCHIVE="$WORK_BASE/gentoo-binpkgs.tar.zst"
  echo "Downloading the existing 256-package binary bundle..."
  curl --fail --location --retry 3 --retry-all-errors "$PKG_URL" -o "$PKG_ARCHIVE"
fi
printf '%s  %s\n' "$PKG_SHA256" "$PKG_ARCHIVE" | sha256sum --check -
zstd -t "$PKG_ARCHIVE" >/dev/null || die "package archive failed Zstandard validation"

mkdir -p "$WORK_BASE/tmp"
export RUNTIME_PROFILE="console"
export BINPKG_RUN_IDS=""
export LOCAL_RELEASE_ASSETS_DIR=""
export LOCAL_BINPKG_ARCHIVE="$PKG_ARCHIVE"
export SOURCE_FALLBACK="false"
export KERNEL_BUNDLE_TAG=""
export RUNNER_TEMP="$WORK_BASE/tmp"
export TMPDIR="$WORK_BASE"
export GITHUB_WORKSPACE="$REPO"
export GITHUB_REPOSITORY="AmrUser-48/d630-gentoo"
export GITHUB_STEP_SUMMARY="$WORK_BASE/summary.md"
export GH_TOKEN=""
export OUTPUT_DIR="$DEST"

echo "Building a minimal Gentoo OpenRC console root on Debian."
echo "Source builds are disabled; Portage must use Stage 3 and available binpkgs."
if bash "$REPO/d630-gentoo/scripts/build-runtime-squashfs.sh"; then
  [[ -s "$DEST/squashfs" ]] || die "builder returned success but did not create $DEST/squashfs"
  echo
  echo "SquashFS ready: $DEST/squashfs"
  ls -lh "$DEST/squashfs"
  rm -rf "$WORK_BASE"
else
  status=$?
  echo "Build failed. Scratch data retained at: $WORK_BASE" >&2
  exit "$status"
fi
