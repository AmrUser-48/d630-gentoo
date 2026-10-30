# D630 kernel profiles

These are three separate configurations for three jobs. They are snippets to merge over a kernel distribution/default config, not complete standalone configs. Never place all three in /etc/kernel/config.d/ together.

## The three profiles

| Profile | Intended system | Driver policy | Build status |
|---|---|---|---|
| 20-d630-base.config | Conventional installed Gentoo | Gentoo's broad distribution config; selected optional D630 drivers as modules | Config snippet prepared; not yet built/tested as a kernel |
| 30-d630-live.config | d630-tiny standalone BusyBox initramfs | Tiny-required storage, i915, Wi-Fi and USB/RNDIS drivers built in; no SFS/loop/overlay | Config snippet prepared; dedicated kernel build/release pending |
| 40-d630-builtin.config | d630-gentoo live SquashFS | Boot path and D630 hardware built in | Current D630 kernel workflow uses this profile; existing 6.18.56 bundle is the reference |

## 20 — full modular Gentoo

Use this with sys-kernel/gentoo-kernel on a normal installed Gentoo system. It preserves Gentoo's distribution defaults and adds D630 policy. SATA/AHCI, ATA_PIIX, SCSI disk and ext4 root support remain built in. Optional graphics, Wi-Fi, USB peripherals/tethering, HDA audio, Bluetooth transport and rescue filesystems are modules.

Activate only this profile on the Gentoo host:

    sudo install -D -m 0644 kernels/profiles/20-d630-base.config /etc/kernel/config.d/20-d630-base.config
    sudo emerge --ask --buildpkg sys-kernel/gentoo-kernel

Remove other D630 profile snippets from /etc/kernel/config.d/ before switching. The Gentoo kernel ebuild merges these snippets over its own config and compiles/installs kernel and modules through Portage. For any root filesystem or boot controller not built in, make sure its modules are included in the initramfs.

## 30 — Tiny standalone kernel

This is for d630-tiny: BusyBox and tools run from the external initramfs; there is no Gentoo root, SquashFS, loop mount or OverlayFS. The Tiny shell needs no kernel module tree for its target hardware: i915, Intel 3945ABG Wi-Fi, USB storage/RNDIS and laptop input are built in. The profile retains module infrastructure for kernel-build/eclass compatibility.

The Tiny kernel does not require HDA audio, Bluetooth, Btrfs, SquashFS, loop or OverlayFS. It keeps ext4, NTFS3, exFAT and VFAT for local disk access.

## 40 — full built-in Gentoo live/SFS kernel

This is the three-file live kernel for d630-gentoo: /d630-gentoo/kernel, /d630-gentoo/initramfs and /d630-gentoo/squashfs.

It includes the built-in root-discovery path: loop, SquashFS Zstandard, OverlayFS, NTFS3, exFAT, VFAT, ext4 and Btrfs; plus D630 AHCI/ATA, USB, i915, 3945ABG, RNDIS, SigmaTel HDA, ACPI, zram and input. The external initramfs scans supported partitions for the SquashFS file and uses a volatile RAM overlay. Changes disappear on reboot.

The earlier d630-base.fragment and d630-live.fragment were two halves of this one profile, not independent kernel variants. Their merged content is now in kernels/profiles/40-d630-builtin.config.

## CPU tuning and Kconfig caveat

The D630 uses a Core 2 Duo T7250 (Merom). Userland packages may use:

    -O2 -pipe -march=core2 -mtune=core2

For 64-bit Linux kernels, keep the generic x86-64 instruction baseline and use KCFLAGS=-mtune=core2. Linux x86-64 Kconfig does not provide the old CONFIG_MCORE2 processor-family selector; do not add CONFIG_MCORE2=y.

## Configuration validation

From repository root:

    bash scripts/validate-kernel-profiles.sh
    bash scripts/validate-kernel-config.sh

Static config validation is not a build or boot test. Validate each generated config, kernel image, matching modules/firmware, then QEMU and physical hardware separately.
