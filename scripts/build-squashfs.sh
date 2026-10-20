#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 <clean-runtime-rootfs> <output.squashfs>" >&2
  exit 2
}
[[ $# -eq 2 ]] || usage
[[ "$EUID" -eq 0 ]] || { echo "Run as root: sudo $0 ROOTFS OUTPUT.squashfs" >&2; exit 1; }
command -v rsync >/dev/null || { echo "Required command missing: rsync" >&2; exit 1; }
command -v mksquashfs >/dev/null || { echo "Required command missing: mksquashfs (squashfs-tools)" >&2; exit 1; }

src="$(realpath "$1")"
output="$(realpath -m "$2")"
[[ -d "$src/etc" && -d "$src/usr" ]] || {
  echo "Input does not look like a Linux rootfs: $src" >&2
  exit 1
}
[[ "$output" != "$src" && "$output" != "$src/"* ]] || {
  echo "Output must not be inside the source rootfs." >&2
  exit 1
}
mkdir -p "$(dirname "$output")"
stage="$(mktemp -d "${TMPDIR:-/var/tmp}/d630-squashfs.XXXXXXXX")"
tmp_output=""
cleanup() {
  for mountpoint in run sys proc dev; do
    if mountpoint -q "$stage/$mountpoint" 2>/dev/null; then
      umount -R "$stage/$mountpoint" 2>/dev/null || true
    fi
  done
  [[ -z "$tmp_output" ]] || rm -f "$tmp_output"
  rm -rf "$stage"
}
trap cleanup EXIT

echo "Copying clean runtime root to staging: $src -> $stage"
rsync -aHAX --numeric-ids --one-file-system --delete \
  --exclude='/dev/***' \
  --exclude='/proc/***' \
  --exclude='/sys/***' \
  --exclude='/run/***' \
  --exclude='/tmp/***' \
  --exclude='/var/tmp/portage/***' \
  --exclude='/var/cache/distfiles/***' \
  --exclude='/var/cache/binpkgs/***' \
  --exclude='/var/cache/edb/dep/***' \
  --include='/var/db/repos/gentoo/' \
  --include='/var/db/repos/gentoo/profiles/***' \
  --exclude='/var/db/repos/gentoo/***' \
  --exclude='/var/log/portage/***' \
  --exclude='/var/log/emerge.log' \
  --exclude='/var/log/gentoo-build-set.log' \
  --exclude='/usr/share/doc/***' \
  --exclude='/usr/share/info/***' \
  --exclude='/usr/share/gtk-doc/***' \
  --exclude='/usr/share/help/***' \
  --exclude='/usr/share/gnome/help/***' \
  --exclude='/usr/include/***' \
  --exclude='/usr/lib*/pkgconfig/***' \
  --exclude='/usr/lib*/cmake/***' \
  --exclude='/usr/share/aclocal/***' \
  --exclude='/usr/share/gettext/***' \
  --exclude='/usr/src/debug/***' \
  --exclude='/usr/lib/debug/***' \
  --exclude='/usr/lib64/debug/***' \
  "$src/" "$stage/"

# Static archives, libtool metadata, and Python bytecode caches are not used by
# installed runtime executables. Keep shared libraries and package metadata.
find "$stage/usr" -type f \( -name '*.a' -o -name '*.la' -o -name '*.pyc' \) -delete 2>/dev/null || true
find "$stage" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true

# Do not blindly delete LLVM files from an arbitrary root: a runtime package
# could genuinely link to them. The image must be staged from a runtime-only
# package set, with build-time dependencies excluded by Portage.
if find "$stage/var/db/pkg/llvm-core" -mindepth 1 -maxdepth 1 -type d \
    \( -name 'llvm-*' -o -name 'clang-*' \) -print -quit 2>/dev/null | grep -q .; then
  echo "WARNING: LLVM/Clang package records are present in the input root." >&2
  echo "This script will not forcibly delete them. Build a clean runtime root with --with-bdeps=n first." >&2
fi

# Refresh the man-db index inside staging, while leaving /usr/share/man intact.
if [[ -x "$stage/usr/bin/mandb" ]]; then
  for mountpoint in dev proc sys run; do
    mkdir -p "$stage/$mountpoint"
    mount --rbind "/$mountpoint" "$stage/$mountpoint"
    mount --make-rslave "$stage/$mountpoint"
  done
  chroot "$stage" /usr/bin/mandb --create || {
    echo "WARNING: mandb index regeneration failed; man pages themselves are preserved." >&2
  }
  for mountpoint in run sys proc dev; do
    umount -R "$stage/$mountpoint" 2>/dev/null || true
  done
fi

tmp_output="$output.tmp.$$"
rm -f "$tmp_output"
echo "Creating SquashFS using zstd compression (kernel must enable SQUASHFS_ZSTD)..."
mksquashfs "$stage" "$tmp_output" -noappend -comp zstd -b 1M -Xcompression-level 15
mv -f "$tmp_output" "$output"
tmp_output=""
echo
du -sh "$src" "$output"
echo "Preserved: /usr/share/man, /usr/share/licenses, and /var/db/pkg."
echo "Removed from the image staging copy: documentation/info trees, Portage build/download caches, ebuild repository checkout, headers and common development metadata."
echo "Original rootfs was not modified: $src"
