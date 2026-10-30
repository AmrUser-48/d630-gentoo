# D630 Tiny Linux

## Overview

D630 Tiny is a standalone, text-mode Linux environment for the Dell Latitude D630. It boots a Linux kernel with one external initramfs and runs from RAM. It is not a complete Gentoo installation and does not include Portage.

## Status

The current [Tiny release](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822) passed the project's QEMU boot checks. Physical D630 validation—including Intel 3945ABG Wi-Fi, graphics, audio and laptop-specific devices—remains pending. Changes are volatile and disappear on reboot unless a rebuilt initramfs is saved externally.

## Layout

- `init`, `build-initramfs.sh`: initramfs init and build entry point.
- `build-network-tools.sh`, `build-setup-tools.sh`: network and setup utility builders.
- `firmware-files.list`: firmware input list.
- `boot/grub.cfg`: GRUB entry.
- `run-qemu.sh`: checksum-verified QEMU launcher.
- `docs/USER-GUIDE.md`: full installation, GRUB, QEMU, shell, networking and persistence guide.

## Requirements

Target: x86_64 Dell Latitude D630 with legacy BIOS and a GRUB-readable partition. For QEMU testing, install `qemu-system-x86` and `sha256sum`. Host-side release downloads use `curl`; automatic asset retrieval also uses GitHub CLI (`gh`).

## Use

Read the [Tiny user guide](docs/USER-GUIDE.md) for complete boot and shell instructions.

From repository root, run `./d630-tiny/run-qemu.sh`. The launcher selects the newest `d630-tiny-shell-*` release, downloads the matching kernel/initramfs/checksum set if needed, verifies it and starts QEMU. To use an already downloaded release, pass `--assets-dir DIRECTORY`.

Keep the separate `/d630-gentoo/` boot files intact.

## Build

Canonical CI entry point: [Build D630 Tiny standalone initramfs](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-tiny-initramfs.yml). It consumes pinned kernel and binary-package assets, builds the Tiny initramfs and publishes a `d630-tiny-shell-*` release.

The workflow currently reuses a pinned D630 kernel bundle. It does not yet build the dedicated profile 30 kernel.

## Releases

Current release: [d630-tiny-shell-40818375822](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822). Use `kernel`, `initramfs` and `SHA256SUMS` as one matching set. See the [repository release index](../docs/releases.md).

## Validation

Run `./scripts/validate-sources.sh` from the repository root for static source checks.

The published workflow verifies hashes and initramfs contents, then boots the actual kernel/initramfs pair in QEMU. QEMU uses emulated USB Ethernet and does not test the physical Intel Wi-Fi adapter.

## Related documentation

- [Complete Tiny user guide](docs/USER-GUIDE.md)
- [Repository overview](../README.md)
- [Kernel profiles](../kernels/README.md)
- [Known issues](../docs/known-issues.md)
- [Release index](../docs/releases.md)
- [Agent rules](AGENTS.md)
