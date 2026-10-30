#!/bin/sh
set -eu
live=kernels/profiles/40-d630-builtin.config
test -s "$live"
require_y() {
    key=$1
    if ! awk -F= -v key="$key" '$1 == key { value = substr($0, index($0, "=") + 1) } END { exit !(value == "y") }' "$live"; then
        echo "Missing required built-in live-kernel option: $key=y" >&2
        exit 1
    fi
}
for key in CONFIG_X86_64 CONFIG_X86_MSR CONFIG_BLK_DEV_INITRD CONFIG_BLK_DEV_LOOP CONFIG_OVERLAY_FS CONFIG_SQUASHFS CONFIG_SQUASHFS_ZSTD CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_EXT4_FS CONFIG_BTRFS_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_USB_NET_CDCETHER CONFIG_BT CONFIG_BT_HCIBTUSB CONFIG_ZRAM CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL; do require_y "$key"; done
grep -Fxq 'CONFIG_DEVTMPFS_MOUNT=n' "$live"
! grep -Eq '^CONFIG_TIGON3=[ym]$' "$live"
grep -Fq 'CONFIG_INITRAMFS_SOURCE=""' "$live"
grep -Fq 'CONFIG_LOCALVERSION="-d630-gentoo"' "$live"
grep -Fxq 'CONFIG_X86_VERBOSE_BOOTUP=n' "$live"
sh -n d630-gentoo/initramfs/init
echo "D630 built-in SFS kernel profile: static validation passed"
