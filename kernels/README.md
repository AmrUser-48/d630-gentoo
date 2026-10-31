# D630 kernel profiles

## Overview

This directory contains three mutually exclusive kernel configuration profiles for the Dell Latitude D630. They are overlays/fragments, not complete standalone `.config` files. Select one profile per target; never merge all three.

## Status

| Profile | Target | Status |
|---|---|---|
| [20-d630-base.config](profiles/20-d630-base.config) | Conventional installed Gentoo | Gentoo distribution-kernel overlay, adapted for D630; Portage build validation pending |
| [30-d630-live.config](profiles/30-d630-live.config) | D630 Tiny | Prepared standalone Tiny profile; dedicated workflow/release pending |
| [40-d630-builtin.config](profiles/40-d630-builtin.config) | Gentoo live SquashFS | Current kernel workflow target; published bundles exist |

## Layout

- `profiles/20-d630-base.config`: one modular overlay for Gentoo's distribution-kernel configuration. It enables the confirmed D630 hardware, keeps the ext4 root path built in and prunes unrelated driver families.
- `profiles/30-d630-live.config`: Tiny profile with required hardware built in; no SFS/OverlayFS/loop dependency.
- `profiles/40-d630-builtin.config`: Gentoo live profile with built-in root-discovery, loop, SquashFS-Zstd, OverlayFS and D630 hardware support.
- `NOTES-legacy.md`: historical hardware/build notes; this README and `docs/hardware-inventory.md` are current sources of truth.

## Gentoo distribution-kernel baseline

Profile 20 was prepared against Gentoo's 6.1 distribution-kernel configuration, not against `x86_64_defconfig`.

The Gentoo `sys-kernel/gentoo-kernel-6.1.190` ebuild selects:

- Fedora amd64 baseline: `kernel-x86_64-fedora.config.6.1.102-gentoo`.
- Gentoo common overlay: `gentoo-kernel-config-g19/base.config`.
- `gentoo-kernel-config-g19/no-debug.config` only when the package's `debug` USE flag is disabled.
- `/etc/kernel/config.d/*.config` fragments are then merged in lexical order by Gentoo's kernel build integration.

Sources: [Gentoo 6.1.190 ebuild](https://github.com/gentoo/gentoo/blob/master/sys-kernel/gentoo-kernel/gentoo-kernel-6.1.190.ebuild), [Gentoo g19 base.config](https://github.com/gentoo/gentoo-kernel-config/blob/g19/base.config), [Gentoo g19 no-debug.config](https://github.com/gentoo/gentoo-kernel-config/blob/g19/no-debug.config), [Fedora 6.1.102 amd64 baseline](https://github.com/projg2/fedora-kernel-config-for-gentoo/tree/6.1.102-gentoo).

For the current Gentoo `sys-kernel/gentoo-kernel-7.2.14` ebuild, the corresponding upstream Fedora baseline is `kernel-x86_64-fedora.config.7.2.10-gentoo`; it still uses the same Gentoo `gentoo-kernel-config-g19` common overlay. Thus the D630 fragment is layered onto the **7.2-specific** default when you build 7.2.14; it does not replace that default with a 6.1 full configuration. See the [Gentoo 7.2.14 ebuild](https://github.com/gentoo/gentoo/blob/master/sys-kernel/gentoo-kernel/gentoo-kernel-7.2.14.ebuild).

The D630 file is deliberately a **single config.d overlay**, not a copied 228 KiB Fedora `.config` and not a `savedconfig` file. Portage still supplies the version-specific Gentoo baseline; Kconfig resolves this D630 overlay against the selected kernel version. This allows the same hardware policy to be tested against Gentoo-patched 6.1, 6.18 and 7.2 kernels without carrying a stale full `.config`.

`CONFIG_EXPERT=y` is included in profile 20, so no separate expert fragment is needed. Keep the package's `debug` USE choice separate: it controls Gentoo's own debug/no-debug fragment and is not changed by this profile.

## Requirements

CPU: Intel Core 2 Duo T7250 (Merom). For 64-bit Linux kernel builds, preserve generic x86-64 ISA baseline and use `KCFLAGS=-mtune=core2`. Do not use `-march=core2` as kernel ISA baseline and do not add the nonexistent x86-64 `CONFIG_MCORE2`. Gentoo userland may use `-O2 -pipe -march=core2 -mtune=core2`.

## Use

- **Profile 20:** copy only `profiles/20-d630-base.config` into `/etc/kernel/config.d/20-d630-base.config` for a conventional installed Gentoo system. Do not leave profiles 30 or 40, or an old expert fragment, active beside it. This profile keeps AHCI/ATA_PIIX and ext4 built in; laptop GPU, Wi-Fi, audio, Bluetooth, USB host and rescue filesystems are modules where practical. Wired Ethernet, DVB/capture, FireWire, NVMe and unrelated virtual hardware are pruned. USB RNDIS host networking remains enabled.
- **Profile 30:** use only for Tiny. Hardware required before mounting a root must be built in; do not depend on a module loader.
- **Profile 40:** use for `/d630-gentoo/kernel` + `initramfs` + `squashfs`. Root-discovery dependencies must be built in because modules cannot be loaded from the not-yet-mounted SquashFS.

Do not install or merge all three profiles together. Gentoo's `/etc/kernel/config.d` is global rather than version-specific; use one active D630 overlay when comparing kernel versions.

## Build

For profile 20, install the one fragment and build with Portage:

```sh
curl -fsSL https://raw.githubusercontent.com/AmrUser-48/d630-gentoo/main/kernels/profiles/20-d630-base.config -o /etc/kernel/config.d/20-d630-base.config
echo '=sys-kernel/gentoo-kernel-7.2.14 ~amd64' > /etc/portage/package.accept_keywords/d630-kernel-test
emerge --ask --verbose --buildpkgonly =sys-kernel/gentoo-kernel-7.2.14
```

Add a `~amd64` keyword exception for the exact testing version before emerging it. `--buildpkgonly` creates the binary package without replacing the installed kernel. After the build, inspect the resolved `.config` under `/var/tmp/portage/sys-kernel/gentoo-kernel-*/work/`; confirm AHCI, ATA_PIIX, ext4, i915, iwl3945, HDA/SigmaTel and USB RNDIS resolved as intended. Do not treat the fragment alone as proof that every symbol survived Kconfig dependency resolution.

Current custom workflow: [Build D630 Gentoo SFS built-in kernel and initramfs](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-kernel.yml). It merges profile 40 and publishes a kernel/initramfs bundle.

Run static checks from repository root:

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
