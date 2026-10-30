#!/bin/sh
set -eu

usage() {
    echo "Usage: $0 /path/next-to-ISO/gentoo-data.img [SIZE]" >&2
    echo "Example: $0 ~/ISOs/gentoo-data.img 4G" >&2
    exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage

image=$1
size=${2:-4G}

case "$image" in
    *.img) ;;
    *) echo "ERROR: persistence image path should end in .img" >&2; exit 2 ;;
esac

command -v truncate >/dev/null 2>&1 || {
    echo "ERROR: GNU truncate is required (install coreutils)." >&2
    exit 1
}
command -v mkfs.ext4 >/dev/null 2>&1 || {
    echo "ERROR: mkfs.ext4 is required (install e2fsprogs)." >&2
    exit 1
}

if [ -e "$image" ]; then
    echo "ERROR: $image already exists; refusing to overwrite it." >&2
    exit 1
fi

dir=$(dirname "$image")
mkdir -p "$dir"
umask 077

# The file is sparse: its logical size is SIZE, but initially it consumes
# substantially less physical space. It grows as persistent changes are made.
# Leave enough free space on the host filesystem for future growth.
truncate -s "$size" "$image"
if ! mkfs.ext4 -F -m 0 -L D630-GENTOO-DATA "$image"; then
    rm -f "$image"
    echo "ERROR: failed to format persistence image." >&2
    exit 1
fi

chmod 600 "$image"
echo "Created ext4 persistence image: $image"
ls -lh "$image"
du -h "$image"
echo
echo "Place this file beside the D630 Gentoo ISO."
echo "Default logical size: $size"
echo "It stores persistent OverlayFS changes; it is not a backup."
echo "Back up this file before replacing the base ISO or experimenting with upgrades."
