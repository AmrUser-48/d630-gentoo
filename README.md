# Dell Latitude D630 Linux

This repository contains two distinct operating systems and three distinct kernel profiles for the Dell Latitude D630 / Intel Core 2 Duo T7250. Keep their files and boot entries separate.

## Two operating systems

| OS directory | What it is | Root/runtime | Boot files | Status |
|---|---|---|---|---|
| [d630-tiny/](d630-tiny/README.md) | Standalone BusyBox shell and utilities; no Portage and no Gentoo root | RAM-only initramfs; changes vanish on reboot | /d630-tiny/kernel, /d630-tiny/initramfs | QEMU-tested release [d630-tiny-shell-40818375822](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822); physical D630 test pending |
| [d630-gentoo/](d630-gentoo/README.md) | Gentoo/OpenRC live OS, from console to Openbox runtime | Read-only SquashFS plus temporary RAM OverlayFS | /d630-gentoo/kernel, /d630-gentoo/initramfs, /d630-gentoo/squashfs | Openbox SFS release [2026-10-29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29); QEMU console/OpenRC boot verified; graphical and physical tests pending |

These are not two package variants of the same image. Tiny is initramfs-only. Gentoo live boots a separate SquashFS root. The preferred boot method loads files directly from a normal partition. An ISO remains an optional container/distribution target; the ISO-specific persistent boot path is still being implemented and validated.

## Three kernel profiles

The configurations are in [kernels/profiles/](kernels/README.md). They are mutually exclusive configuration overlays:

| Profile | Purpose | Driver policy |
|---|---|---|
| [20-d630-base.config](kernels/profiles/20-d630-base.config) | Full modular kernel for a conventional installed Gentoo system | Gentoo defaults retained; optional D630 hardware drivers as modules |
| [30-d630-live.config](kernels/profiles/30-d630-live.config) | Minimal standalone kernel for d630-tiny | Tiny-required hardware built in; no SquashFS/OverlayFS/loop |
| [40-d630-builtin.config](kernels/profiles/40-d630-builtin.config) | Built-in kernel for the d630-gentoo live SquashFS | Root-discovery path and D630 hardware built in |

Do not merge these three profiles together. For a conventional Gentoo installation, use the modular profile with sys-kernel/gentoo-kernel and /etc/kernel/config.d/; read the kernel profile guide. The existing standalone kernel workflow builds the 40 built-in SFS profile. A dedicated 30-profile Tiny kernel release is still pending; the current Tiny release reuses the existing 6.18.56 D630 kernel bundle.

## Target hardware and build policy

Primary hardware: Dell Latitude D630, Core 2 Duo T7250 (Merom), Intel GM965/GMA X3100, Intel PRO/Wireless 3945ABG, Intel HDA/SigmaTel, SATA AHCI/ATA_PIIX, USB 2.0 and legacy BIOS/GRUB. Wi-Fi and Android USB RNDIS are in scope. Wired Ethernet is intentionally omitted from the D630 live profiles; Bluetooth transport remains unconfirmed.

Use -O2 -pipe -march=core2 -mtune=core2 for target userland. For 64-bit Linux kernel builds keep the generic x86-64 ISA baseline and use KCFLAGS=-mtune=core2; there is no x86-64 CONFIG_MCORE2 selector.

## Repository map

- d630-tiny/: standalone Tiny OS, initramfs builder, firmware manifest, network/setup tools and GRUB entry.
- d630-gentoo/: Gentoo live SFS initramfs, runtime package sets, SquashFS builders, direct-file GRUB entries and optional ISO packaging assets under d630-gentoo/iso/.
- kernels/: three mutually exclusive D630 kernel profiles and configuration rules.
- config/portage/, config/make.conf: shared Gentoo builder/Portage configuration.
- scripts/: shared runner-state, binpkg export/import and validation utilities.
- docs/: D630 hardware inventory, known issues and archived planning notes.
- output/: historical CI/build staging files. Do not treat these as current releases without checking manifests and Actions runs.

## Main workflows

- Build D630 kernel and initramfs: builds the built-in Gentoo SFS kernel profile (40).
- Build D630 Tiny standalone initramfs: currently reuses a pinned D630 kernel bundle; it does not yet build profile 30.
- Build D630 Gentoo runtime SquashFS: assembles the Gentoo runtime from binpkgs/stage3 and creates the SFS.
- Gentoo interactive builder / restored runner: builds packages and preserves the full source/build root and binpkg cache.
- Validate d630-gentoo sources: static source checks and workflow lint; not a package build or hardware test.

## Verification rules

Report these separately: source validation, successful package/kernel build, artifact integrity, QEMU boot, graphical session, and physical D630 hardware tests. A green validation workflow does not prove that the OS boots. Always use a matching kernel/modules/firmware release and inspect its checksums.

For current status, check [Actions](https://github.com/AmrUser-48/d630-gentoo/actions), [releases](https://github.com/AmrUser-48/d630-gentoo/releases), and [known issues](docs/known-issues.md).
