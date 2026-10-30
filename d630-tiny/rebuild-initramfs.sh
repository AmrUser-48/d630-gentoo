#!/bin/bash
set -Eeuo pipefail

if [[ $# -ne 1 || "$1" != /* ]]; then
  echo "Usage: doas rebuild-initramfs /mounted/storage/initramfs" >&2
  exit 2
fi
if [[ "$EUID" -ne 0 ]]; then
  echo "Run this command as root, for example: doas rebuild-initramfs /mnt/usb/initramfs" >&2
  exit 1
fi

destination=$1
destination_name=$(basename -- "$destination")
destination_dir=$(dirname -- "$destination")
[[ "$destination_name" != "/" && -d "$destination_dir" ]] || {
  echo "Destination directory does not exist: $destination_dir" >&2
  exit 1
}
destination_dir=$(cd -P -- "$destination_dir" && pwd)
destination="$destination_dir/$destination_name"
[[ ! -d "$destination" ]] || {
  echo "Destination is a directory: $destination" >&2
  exit 1
}

root_device=$(stat -c '%d' /)
destination_device=$(stat -c '%d' "$destination_dir")
[[ "$root_device" != "$destination_device" ]] || {
  echo "Destination must be on mounted persistent storage, not the RAM root: $destination" >&2
  exit 1
}

microcode=/usr/share/d630-tiny/early-microcode.cpio
[[ -s "$microcode" ]] || {
  echo "The original early microcode archive is missing: $microcode" >&2
  exit 1
}
for command_name in find cpio zstd; do
  command -v "$command_name" >/dev/null || {
    echo "Required rebuild tool is missing: $command_name" >&2
    exit 1
  }
done

workdir=$(mktemp -d "$destination_dir/.d630-initramfs.XXXXXX")
cleanup() {
  rm -rf -- "$workdir"
}
trap cleanup EXIT

echo "Packing the running root filesystem (mounted filesystems are excluded)..."
if ! (
  cd /
  find . -xdev -print0 | cpio --null --create --format=newc --owner=0:0
) > "$workdir/rootfs.cpio"; then
  echo "Could not create the initramfs CPIO archive." >&2
  exit 1
fi
zstd -q -T0 -3 -f "$workdir/rootfs.cpio" -o "$workdir/rootfs.cpio.zst"
cat "$microcode" "$workdir/rootfs.cpio.zst" > "$workdir/initramfs"
chmod 0644 "$workdir/initramfs"
mv -f -- "$workdir/initramfs" "$destination"
sync

echo "New initramfs written to $destination"
echo "Select this file from GRUB on your next boot; the current boot is unchanged."
