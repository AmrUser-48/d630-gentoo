# Dell Latitude D630 Linux

## Overview

A Core 2-targeted Linux project for the Dell Latitude D630. It contains **two separate live operating systems** and **three mutually exclusive kernel profiles**. Their source trees, boot entries, root filesystems and release artifacts must remain distinct.

## Status

| Component | Purpose | Runtime model | Current verification |
|---|---|---|---|
| [D630 Tiny](d630-tiny/README.md) | Standalone BusyBox shell; no Gentoo root or Portage | External initramfs; RAM-only changes | [Current release](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822) boots in QEMU; physical D630 validation pending |
| [D630 Gentoo](d630-gentoo/README.md) | Gentoo/OpenRC live OS, console and Openbox profiles | Read-only SquashFS plus volatile RAM OverlayFS | [Current SFS release](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29) passed QEMU console/OpenRC boot; graphics and physical tests pending |
| [Kernel profiles](kernels/README.md) | Modular installed-Gentoo kernel, Tiny kernel, Gentoo SFS live kernel | Three distinct config fragments | Profile 40 has published bundles; profiles 20 and 30 still need dedicated build/installation validation |

## Layout

- `d630-tiny/`: standalone Tiny OS, initramfs builder, network/setup utilities and GRUB entry.
- `d630-gentoo/`: Gentoo live OS, external initramfs, runtime package sets, SquashFS builders, direct-file GRUB entries and optional ISO packaging.
- `kernels/`: profiles 20, 30 and 40 with kernel-specific guidance.
- `config/portage/` and `config/make.conf`: shared Gentoo/Portage builder configuration.
- `scripts/`: runner-state, binary-package, release-index and validation utilities.
- `docs/`: hardware inventory, known issues, README template, release catalog and archived notes.
- `output/`: historical CI staging files; do not assume these are current published assets.

## Requirements

Target hardware: Dell Latitude D630, Intel Core 2 Duo T7250 (Merom), Intel GM965/GMA X3100, Intel PRO/Wireless 3945ABG, Intel HDA/SigmaTel, SATA AHCI/ATA_PIIX, USB 2.0 and legacy BIOS/GRUB.

Gentoo userland flags: `-O2 -pipe -march=core2 -mtune=core2`. For 64-bit kernel builds, retain the generic x86-64 ISA baseline and use `KCFLAGS=-mtune=core2`; do not add `CONFIG_MCORE2` or use `-march=native` in CI.

## Use

Preferred boot method: GRUB loads normal kernel/initramfs/SquashFS files from a GRUB-readable partition.

- Tiny: `/d630-tiny/kernel` and `/d630-tiny/initramfs`.
- Gentoo live: `/d630-gentoo/kernel`, `/d630-gentoo/initramfs` and `/d630-gentoo/squashfs`.

The ISO remains an optional packaging/distribution container; the preferred path is not to boot the ISO as the boot medium. ISO-specific early userspace and persistent boot still require implementation and end-to-end testing. See [ISO packaging](d630-gentoo/iso/README.md).

## Build

Select the workflow for the target:

- `Build D630 Gentoo SFS built-in kernel and initramfs`: builds profile 40.
- `Build D630 Tiny standalone initramfs`: reuses a pinned kernel bundle; it does not yet build profile 30.
- `Build D630 Gentoo runtime SquashFS`: assembles the Gentoo runtime image.
- Gentoo interactive/restored-runner workflows: build packages and preserve the source/build root and binary-package cache.
- `Validate d630-gentoo sources`: static source checks and workflow lint only.

## Releases

See the [release index](docs/releases.md) for the complete GitHub Releases inventory and cleanup status. Keep kernel/modules/firmware and OS image assets matched by release tag, manifest and checksums.

## Validation

From the repository root:

- `./scripts/validate-sources.sh`
- `bash scripts/validate-kernel-profiles.sh`
- `bash scripts/validate-kernel-config.sh`

These are static checks. Report package/kernel builds, artifact integrity, QEMU boot, graphical startup and physical D630 tests separately. A green source-validation workflow does not prove that the OS boots.

## Related documentation

- [Tiny user guide](d630-tiny/docs/USER-GUIDE.md)
- [Gentoo live OS guide](d630-gentoo/README.md)
- [Kernel profile guide](kernels/README.md)
- [Hardware inventory](docs/hardware-inventory.md)
- [Known issues](docs/known-issues.md)
- [README template](docs/README-TEMPLATE.md)
- [Agent rules](AGENTS.md)
- [LLM context](llms.txt)
- [Release index](docs/releases.md)
