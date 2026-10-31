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
    duplicates="$(awk -F= '/^CONFIG_[A-Za-z0-9_]+=/{if (seen[$1]++) print $1}' "$file")"
    if [ -n "$duplicates" ]; then
        echo "Duplicate Kconfig assignments in $file:" >&2
        printf '%s\n' "$duplicates" >&2
        exit 1
    fi
done
require() {
    file=$1 key=$2 value=$3
    grep -Fxq "$key=$value" "$file" || { echo "Expected $file to contain $key=$value" >&2; exit 1; }
}
# Profile 20: conventional installed Gentoo; root path built in, device drivers modular.
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_SCSI CONFIG_BLK_DEV_SD CONFIG_EXT4_FS CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_EXPERT CONFIG_X86_MSR; do require "$modular" "$key" y; done
for key in CONFIG_DRM_I915 CONFIG_IWLEGACY CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_SND_HDA_INTEL CONFIG_BLUETOOTH CONFIG_BT_HCIBTUSB; do require "$modular" "$key" m; done
for key in CONFIG_ACPI CONFIG_ACPI_BATTERY CONFIG_ACPI_THERMAL CONFIG_DRM CONFIG_WLAN CONFIG_USB CONFIG_INPUT CONFIG_SND; do require "$modular" "$key" y; done
for key in CONFIG_MEDIA_SUPPORT CONFIG_DVB_CORE CONFIG_VIDEO_DEV CONFIG_FIREWIRE CONFIG_ETHERNET CONFIG_NVME_CORE CONFIG_BLK_DEV_NVME CONFIG_DRM_AMDGPU CONFIG_DRM_RADEON CONFIG_DRM_NOUVEAU CONFIG_DRM_VIRTIO_GPU CONFIG_HYPERV CONFIG_VIRTIO_PCI; do require "$modular" "$key" n; done
# Profile 30: Tiny live kernel.
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_EXT4_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST; do require "$tiny" "$key" y; done
for key in CONFIG_BLK_DEV_LOOP CONFIG_OVERLAY_FS CONFIG_SQUASHFS; do require "$tiny" "$key" n; done
# Profile 40: Gentoo live SquashFS kernel.
for key in CONFIG_MODULES CONFIG_BLK_DEV_INITRD CONFIG_BLK_DEV_LOOP CONFIG_OVERLAY_FS CONFIG_SQUASHFS CONFIG_SQUASHFS_ZSTD CONFIG_DEVTMPFS CONFIG_TMPFS CONFIG_SATA_AHCI CONFIG_ATA_PIIX CONFIG_EXT4_FS CONFIG_BTRFS_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS CONFIG_VFAT_FS CONFIG_DRM_I915 CONFIG_IWL3945 CONFIG_USB_STORAGE CONFIG_USB_NET_RNDIS_HOST CONFIG_SND_HDA_INTEL; do require "$builtin" "$key" y; done
grep -Fxq 'CONFIG_DEVTMPFS_MOUNT=n' "$builtin"
grep -Fxq 'CONFIG_LOCALVERSION="-d630-gentoo"' "$builtin"
echo "All three independent D630 kernel profiles passed static policy checks."
