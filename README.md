# Dell Latitude D630 Linux

## Overview

A Core 2-targeted Linux project for the Dell Latitude D630. It maintains two separate live systems and three mutually exclusive kernel profiles.

## Status

| Component | Current state |
|---|---|
| [D630 Tiny](d630-tiny/README.md) | Text-mode initramfs release boots in QEMU; physical D630 validation remains pending. |
| [D630 Gentoo](d630-gentoo/README.md) | Gentoo/OpenRC SquashFS release boots to console in QEMU; Xorg/Openbox and physical graphics validation remain pending. |
| [Kernel profiles](kernels/README.md) | Profile 40 has published bundles. Profiles 20 and 30 still need dedicated build/boot validation. |

## Layout

- d630-tiny/: standalone BusyBox shell and external initramfs; no Portage.
- d630-gentoo/: Gentoo/OpenRC live system, SquashFS builders, desktop and optional ISO packaging.
- kernels/: the three D630 kernel configuration fragments.
- config/ and scripts/: shared Portage configuration, build helpers and validation.
- docs/: hardware inventory, known issues, release index and technical references.
- .github/workflows/: build, validation, QEMU and runner-state workflows.

## Requirements

Target: Core 2 Duo T7250, Intel GM965/GMA X3100, Intel 3945ABG Wi-Fi, HDA/SigmaTel, SATA AHCI/ATA_PIIX, USB 2.0 and legacy BIOS/GRUB.

Gentoo userland targets Merom with -O2 -pipe -march=core2 -mtune=core2. Kernel builds retain a generic x86-64 ISA baseline and use -mtune=core2 only.

## Use

Preferred Gentoo boot loads the matching kernel, initramfs and SquashFS directly from a GRUB-readable partition:

- Tiny: /d630-tiny/
- Gentoo: /d630-gentoo/

The Gentoo ISO is an optional packaging target. Direct three-file boot remains the preferred path; see the [Gentoo guide](d630-gentoo/README.md).

## Build

Use the workflow for the target component:

- [Gentoo kernel and initramfs](.github/workflows/build-d630-kernel.yml) — profile 40.
- [Tiny initramfs](.github/workflows/build-d630-tiny-initramfs.yml).
- [Gentoo runtime SquashFS](.github/workflows/build-d630-runtime-squashfs.yml).
- [Gentoo interactive builder](.github/workflows/gentoo-interactive-build.yml) — package builds and runner sessions.

## Releases

The [release index](docs/releases.md) is the authoritative inventory of published OS images, kernel bundles, package sets and retained runner-state releases. Keep each kernel, module and firmware set matched to its manifest and checksums.

## Validation

From the repository root:

~~~bash
./scripts/validate-sources.sh
bash scripts/validate-kernel-profiles.sh
bash scripts/validate-kernel-config.sh
~~~

These are static checks. Compilation, artifact verification, QEMU boot, graphical startup and physical D630 testing are separate validation stages.

## Related documentation

- [Tiny user guide](d630-tiny/docs/USER-GUIDE.md)
- [Gentoo live OS guide](d630-gentoo/README.md)
- [GM965/GMA X3100 graphics guide](d630-gentoo/gma-readme.md)
- [Kernel profiles](kernels/README.md)
- [Hardware inventory](docs/hardware-inventory.md) · [Known issues](docs/known-issues.md) · [Release index](docs/releases.md)
- [AI agent rules](AGENTS.md) · [LLM context](llms.txt)
