# D630 Gentoo ISO packaging

## Overview

The ISO is an optional distribution and packaging container for the Gentoo live runtime. The preferred use is to boot ordinary kernel/initramfs/SquashFS files from a GRUB-readable partition rather than selecting the ISO as the boot medium.

## Status

The ISO remains an active packaging target, not an obsolete design. Its GRUB loopback menu and persistence-image helper are present. A complete ISO assembly workflow and ISO-specific early userspace have not yet been implemented or tested end to end. The direct-folder three-file boot path remains the current tested method.

## Layout

Intended ISO contents:

    /boot/vmlinuz-d630-gentoo
    /boot/grub/loopback.cfg
    /LiveOS/rootfs.squashfs

Repository assets:

- `boot/grub/loopback.cfg`: GRUB loopback menu.
- `scripts/create-persistence-image.sh`: sparse ext4 persistence-image helper.
- Parent `../initramfs/`: current direct-folder early userspace; it does not implement this ISO menu's separate `d630.iso_*` parameters.

## Requirements

The ISO target is intended for legacy BIOS/GRUB. Writable ext4 `gentoo-data.img` must stay beside the ISO on writable host storage, not inside the read-only ISO. A future end-to-end test needs ISO filesystem tooling and QEMU.

## Use

Preferred method: extract/copy kernel, initramfs and SquashFS to a normal partition and use [the direct-file GRUB entry](../boot/grub/three-file.cfg).

Optional method: store or mount the ISO as a container and access its contents. It does not have to be selected as the boot device. The same runtime can be extracted and booted from an ordinary partition.

Do not enable persistent ISO boot expecting it to work until the ISO-specific initramfs and persistence flow have passed end-to-end testing.

## Build

There is no complete ISO assembly workflow yet. Implement early userspace support for `d630.iso_uuid`, `d630.iso_path`, `d630.persistence`, `d630.datafile` and `d630.rootfs`, then assemble and test the ISO and its adjacent persistence image. Keep this separate from the working direct-folder initramfs.

## Releases

No verified ISO release is published. Current Gentoo runtime assets are distributed in [d630-gentoo-openbox-2026.10.29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29). See the [release index](../../docs/releases.md).

## Validation

The direct-folder boot path is QEMU-tested. The ISO loopback menu and helper are source assets only; there is no ISO build, boot or persistent-overlay test result.

## Related documentation

- [Gentoo live OS](../README.md)
- [Direct-file GRUB entry](../boot/grub/three-file.cfg)
- [Release index](../../docs/releases.md)
- [Repository overview](../../README.md)
