#!/bin/sh
set -eu
modular=kernels/profiles/20-d630-base.config
tiny=kernels/profiles/30-d630-live.config
builtin=kernels/profiles/40-d630-builtin.config
for file in "$modular" "$tiny" "$builtin"; do
    test -s "$file" || { echo "Missing kernel profile: $file" >&2; exit 1; }
    if grep -q '^CONFIG_MCORE2=' "$file"; then
        echo "CONFIG_MCORE2 is not a valid x86-64 processor-family setting: $file" >&2
        exit 1
    fi
done
require() {
    file=$1 key=$2 value=$3
    grep -Fxq "$key=$value" "$file" || { echo "Expected $file to contain $key=$value" >&2; exit 1; }
}
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_SCSI CONFIG_BLK_DEV_SD CONFIG_EXT4_FS; do require "$modular" "$key" y; done
for key in CONFIG_DRM_I915 CONFIG_IWLEGACY CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_SND_HDA_INTEL; do require "$modular" "$key" m; done
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_EXT4_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST; do require "$tiny" "$key" y; done
for key in CONFIG_BLK_DEV_LOOP CONFIG_OVERLAY_FS CONFIG_SQUASHFS; do require "$tiny" "$key" n; done
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_BLK_DEV_LOOP CONFIG_OVERLAY_FS CONFIG_SQUASHFS CONFIG_SQUASHFS_ZSTD CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_EXT4_FS CONFIG_BTRFS_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_SND_HDA_INTEL; do require "$builtin" "$key" y; done
grep -Fxq 'CONFIG_DEVTMPFS_MOUNT=n' "$builtin"
grep -Fxq 'CONFIG_LOCALVERSION="-d630-gentoo"' "$builtin"
echo "All three independent D630 kernel profiles passed static policy checks."
