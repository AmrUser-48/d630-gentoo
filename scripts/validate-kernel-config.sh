#!/bin/sh
set -eu

base=config/kernel/d630-base.fragment
live=config/kernel/d630-live.fragment
test -s "$base"
test -s "$live"

require_y() {
    key=$1
    if ! awk -F= -v key="$key" '$1 == key { value = substr($0, index($0, "=") + 1) } END { exit !(value == "y") }' "$base" "$live"; then
        echo "Missing required built-in kernel config: $key=y" >&2
        exit 1
    fi
}

for key in \
    CONFIG_MCORE2 CONFIG_X86_MSR CONFIG_BLK_DEV_INITRD CONFIG_BLK_DEV_LOOP \
    CONFIG_OVERLAY_FS CONFIG_SQUASHFS CONFIG_SQUASHFS_ZSTD CONFIG_DEVTMPFS \
    CONFIG_TMPFS CONFIG_EXT4_FS CONFIG_BTRFS_FS CONFIG_NTFS3_FS \
    CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 \
    CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_USB_NET_CDCETHER \
    CONFIG_BT CONFIG_BT_HCIBTUSB CONFIG_ZRAM CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
do
    require_y "$key"
done

# The script mounts /dev itself; avoid the kernel pre-mounting devtmpfs on
# the initramfs root, which can make the explicit mount fail.
if ! grep -Fxq 'CONFIG_DEVTMPFS_MOUNT=n' "$live"; then
    echo "Set CONFIG_DEVTMPFS_MOUNT=n for the standalone initramfs." >&2
    exit 1
fi
if grep -Eq '^CONFIG_TIGON3=[ym]$' "$base" "$live"; then
    echo "Wired Ethernet/tigon3 must remain disabled." >&2
    exit 1
fi
grep -Fq 'CONFIG_INITRAMFS_SOURCE=""' "$live"
grep -Fq 'CONFIG_LOCALVERSION="-d630-gentoo"' "$base"
sh -n initramfs/init
echo "D630 kernel fragments: static validation passed"
