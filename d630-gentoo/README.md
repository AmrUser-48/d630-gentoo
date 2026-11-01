# D630 Gentoo live OS

## Overview

This directory contains the Gentoo/OpenRC live operating system. It is separate from D630 Tiny, which is a BusyBox-only initramfs without a Gentoo root. Gentoo live boots a read-only SquashFS root and creates a temporary RAM-backed OverlayFS upper layer.

## Status

The current runtime is [d630-gentoo-openbox-2026.10.29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29). Its kernel/initramfs/SquashFS bundle passed QEMU boot through initramfs discovery, SquashFS mount, OverlayFS setup and OpenRC console startup. Xorg/Openbox startup, Crocus acceleration in the virtual display and physical D630 validation remain pending.

Direct three-file boot is implemented and preferred. OverlayFS changes disappear at reboot. The initramfs source now supports the optional `toram` flag; the published 2026-10-29 initramfs predates that change and must be rebuilt before using it. ISO is an optional packaging target, but ISO-specific early userspace and persistent boot remain incomplete.

## Layout

Expected boot partition:

    /d630-gentoo/
    ├── kernel
    ├── initramfs
    └── squashfs

- `initramfs/init`: early userspace and SquashFS discovery.
- `boot/grub/three-file.cfg`: preferred direct-file GRUB entry.
- `boot/grub/gui.cfg`: graphical boot entry.
- `config/package-sets/`: console, desktop, Openbox and other runtime sets.
- `config/desktop/`: curated Xresources, Openbox and MPD user skeletons.
- `config/wifi/`: external NetworkManager profile template; credentials are not embedded in the image.
- `config/xorg/`: D630 input configuration and optional graphics-driver test profiles.
- `scripts/`: runtime assembly and SquashFS builders.
- `iso/`: optional ISO layout, loopback menu and persistence-image helper.

## Requirements

Use kernel profile 40, which builds in the block-device, filesystem, loop, SquashFS-Zstd and OverlayFS support needed before the Gentoo root is mounted. The host filesystem containing `/d630-gentoo/squashfs` must be supported by early userspace. Shared Portage settings are in repository-root `config/portage/`.

## Use

Copy the matching `kernel`, `initramfs` and `squashfs` assets to `/d630-gentoo/` on a GRUB-readable partition. Configure GRUB with [three-file.cfg](boot/grub/three-file.cfg). Prefer loading the individual files; the ISO does not need to be selected as the boot device.

Current direct-folder mode is volatile. The optional ext4 `gentoo-data.img` belongs beside the ISO on writable host storage, not inside the read-only ISO; it is not part of the tested direct-folder path.

### Wi-Fi auto-connect

The image contains no Wi-Fi credentials. Place a NetworkManager keyfile named `wifi.nmconnection` at `/d630-gentoo/wifi.nmconnection` on the **same host partition as the SquashFS**. Start from [wifi.nmconnection.example](config/wifi/wifi.nmconnection.example) and replace the SSID and key. The host partition remains mounted read-only by the initramfs; the first-boot service copies the file into the volatile root at `/etc/NetworkManager/system-connections/`, owned by root with mode `0600`, before NetworkManager starts.

Credentials stay outside the SquashFS and are not committed to Git. The host-side keyfile is plaintext, so protect that partition. The import service enforces secure permissions on the Linux copy even when the host filesystem does not support Unix permissions. The example uses WPA2-PSK; provide the actual SSID, security type and key to generate the matching profile.

### Boot methods

| Method | Files and GRUB entry | Status |
|---|---|---|
| Direct three-file boot | `/d630-gentoo/kernel`, `initramfs`, `squashfs`; use [three-file.cfg](boot/grub/three-file.cfg) | Preferred and QEMU-tested through OpenRC console startup |
| Complete GUI initramfs | `/d630-gui/kernel` and `gui-initram`; use [gui.cfg](boot/grub/gui.cfg) | Separate build target; not the three-file SquashFS path |
| ISO loopback | ISO menu in [loopback.cfg](iso/boot/grub/loopback.cfg) | Experimental source only; ISO-specific early userspace and persistence are not implemented end to end |

For the normal direct boot path, GRUB loads the kernel and initramfs. The initramfs scans block devices for the SquashFS path. The kernel, initramfs and SquashFS may reside on different GRUB/Linux-readable partitions. The SquashFS host filesystem must be one of NTFS3, exFAT, VFAT, ext4 or Btrfs.

### Kernel command-line options

These are the options relevant to this D630 image, not an exhaustive list of every Linux kernel parameter.

| Parameter | Effect |
|---|---|
| `quiet` | Reduce routine kernel boot messages. |
| `loglevel=3` | Show errors and more severe kernel messages. Values range from 0 (emergency) to 7 (debug). |
| `loglevel=7 ignore_loglevel` | Show kernel messages for diagnosis, overriding quiet filtering. |
| `d630.squashfs=/absolute/path` | Override the default `/d630-gentoo/squashfs` path. The path is relative to each probed host partition and must contain no spaces. |
| `d630.persistence=volatile` | Select the supported RAM-only OverlayFS mode. This is the default; other values fail in direct three-file mode. |
| `d630.debug=1` | Enable shell tracing in the early initramfs script. |
| `toram` | Copy the compressed SquashFS into RAM before mounting it, then unmount the source partition. Requires available RAM of at least the SquashFS size plus 256 MiB. Use only with an initramfs rebuilt from the current source; the published 2026-10-29 initramfs does not yet include this change. |
| `rdinit=/bin/sh` | Start a rescue shell in the initramfs instead of running its normal `/init` script. From that shell, inspect `/proc/cmdline`, `/dev` and mounts; run `exec /init` to resume normal startup. |
| `initcall_debug` | Print kernel initcall timing and progress for early-kernel diagnosis. |
| `nomodeset` | Disable kernel modesetting. Diagnostic fallback only; it disables normal i915 KMS and can prevent the intended accelerated graphics setup. |
| `pci=nomsi` | Disable PCI MSI interrupts system-wide. Use only to diagnose interrupt/device problems. |
| `maxcpus=1` | Limit startup to one CPU for SMP-related diagnosis; it disables use of the second Core 2 core. |

The direct initramfs does not use `root=`, `rootfstype=`, `d630.boot_uuid` or the ISO-only `d630.iso_*` parameters. It discovers the SquashFS by scanning supported filesystems. Do not use `acpi=off` as a routine option: it disables laptop ACPI functionality, including important power and thermal-management paths.

`ppc=1` is not a valid D630/x86-64 kernel option. PowerPC-specific options are for a different CPU architecture; this machine uses Intel x86-64. Leave `ppc=1` out.

For the full upstream parameter reference, see the [Linux kernel command-line documentation](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html).

## Build

Canonical builder: [Build D630 Gentoo runtime SquashFS](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-runtime-squashfs.yml). It supports console and graphical profiles and writes staging outputs to repository-root `output/`.

The [kernel and initramfs workflow](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-kernel.yml) builds profile 40 and packages the external initramfs from `d630-gentoo/initramfs/init`. Rebuild and redeploy the matching initramfs after changing that script; a kernel rebuild is currently part of the same workflow. Preserve the original restored build root and `/var/cache/binpkgs`; trim only a separate runtime staging root. Shared builder configuration lives in repository-root `config/` and `scripts/`.

## Releases

Current runtime: [d630-gentoo-openbox-2026.10.29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29). It includes `kernel`, `initramfs`, `squashfs` and checksums. The SquashFS is reported as 198.43 MiB. See the [release index](../docs/releases.md).

## Validation

Run `./scripts/validate-sources.sh`, `bash scripts/validate-kernel-profiles.sh` and `bash scripts/validate-kernel-config.sh` from the repository root.

The release QEMU test covered console/OpenRC startup and the direct three-file root path. It does not prove graphical startup or physical D630 compatibility. ISO assembly and persistent boot are not end-to-end tested.

## Related documentation

- [Desktop configuration skeleton](config/desktop/README.md)
- [Xorg configuration and driver profiles](config/xorg/README.md)
- [GM965/GMA X3100 graphics, Mesa, DRI and historical drivers](gma-readme.md)
- [ISO packaging](iso/README.md)
- [Kernel profiles](../kernels/README.md)
- [Hardware inventory](../docs/hardware-inventory.md)
- [Known issues](../docs/known-issues.md)
- [Repository overview](../README.md)
- [Release index](../docs/releases.md)
