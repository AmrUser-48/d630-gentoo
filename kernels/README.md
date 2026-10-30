# D630 kernel profiles

## Overview

This directory contains three mutually exclusive kernel configuration profiles for the Dell Latitude D630. They are overlays/fragments, not complete standalone `.config` files. Select one profile per target; never merge all three.

## Status

| Profile | Target | Status |
|---|---|---|
| [20-d630-base.config](profiles/20-d630-base.config) | Conventional installed Gentoo | Prepared modular overlay; not yet built/validated as a complete installed-system kernel |
| [30-d630-live.config](profiles/30-d630-live.config) | D630 Tiny | Prepared standalone Tiny profile; dedicated workflow/release pending |
| [40-d630-builtin.config](profiles/40-d630-builtin.config) | Gentoo live SquashFS | Current kernel workflow target; published bundles exist |

## Layout

- `profiles/20-d630-base.config`: modular hardware overlay for normal Gentoo.
- `profiles/30-d630-live.config`: Tiny profile with required hardware built in; no SFS/OverlayFS/loop dependency.
- `profiles/40-d630-builtin.config`: Gentoo live profile with built-in root-discovery, loop, SquashFS-Zstd, OverlayFS and D630 hardware support.
- `NOTES-legacy.md`: historical hardware/build notes; this README and `docs/hardware-inventory.md` are current sources of truth.

## Requirements

CPU: Intel Core 2 Duo T7250 (Merom). For 64-bit Linux kernel builds, preserve generic x86-64 ISA baseline and use `KCFLAGS=-mtune=core2`. Do not use `-march=core2` as kernel ISA baseline and do not add the nonexistent x86-64 `CONFIG_MCORE2`. Gentoo userland may use `-O2 -pipe -march=core2 -mtune=core2`.

## Use

- **Profile 20:** apply to Gentoo's normal distribution kernel configuration (for example `sys-kernel/gentoo-kernel`) using `/etc/kernel/config.d/`. Retain Gentoo's broad generic driver coverage.
- **Profile 30:** use only for Tiny. Hardware required before mounting a root must be built in; do not depend on a module loader.
- **Profile 40:** use for `/d630-gentoo/kernel` + `initramfs` + `squashfs`. Root-discovery dependencies must be built in because modules cannot be loaded from the not-yet-mounted SquashFS.

Do not install or merge all three profiles together.

## Build

Current workflow: [Build D630 Gentoo SFS built-in kernel and initramfs](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-kernel.yml). It merges profile 40 and publishes a kernel/initramfs bundle.

Run from repository root:

    bash scripts/validate-kernel-profiles.sh
    bash scripts/validate-kernel-config.sh

Profiles 20 and 30 still need dedicated complete build/boot workflows.

## Releases

Latest bundle: [d630-kernel-6.18.56-run-41134237939](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-41134237939). Older bundles remain while workflows pin their exact tags; see the [release index](../docs/releases.md).

## Validation

Static profile validators inspect fragments and selected Kconfig requirements; they do not compile a kernel. For every release, verify manifest/checksums and matching modules/firmware, then test QEMU boot. Physical D630 testing is separate.

## Related documentation

- [Repository overview](../README.md)
- [Hardware inventory](../docs/hardware-inventory.md)
- [Known issues](../docs/known-issues.md)
- [Legacy notes](NOTES-legacy.md)
- [Release index](../docs/releases.md)
- [Agent rules](AGENTS.md)
