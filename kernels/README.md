# D630 kernel profiles

## Overview

This directory contains three mutually exclusive kernel configuration profiles for the Dell Latitude D630. They are overlays/fragments, not complete standalone `.config` files. Select one profile per target; never merge all three.

## Status

| Profile | Target | Status |
|---|---|---|
| [20-d630-base.config](profiles/20-d630-base.config) | Conventional installed Gentoo | Gentoo distribution-kernel overlay, adapted for D630; Portage build validation pending |
| [30-d630-live.config](profiles/30-d630-live.config) | D630 Tiny | Tinyconfig-based built-in kernel under active development; dedicated workflow, release and end-to-end boot validation pending |
| [40-d630-builtin.config](profiles/40-d630-builtin.config) | Gentoo live SquashFS | Current kernel workflow target; published bundles exist |

## Layout

- `profiles/20-d630-base.config`: one modular overlay for Gentoo's distribution-kernel configuration. It enables the confirmed D630 hardware, keeps the ext4 root path built in and prunes unrelated driver families.
- `profiles/30-d630-live.config`: D630 Tiny hardware and filesystem fragment, layered over a minimal upstream `tinyconfig` baseline; no Gentoo root, SquashFS, OverlayFS or loop-device dependency.
- `profiles/40-d630-builtin.config`: Gentoo live profile with built-in root-discovery, loop, SquashFS-Zstd, OverlayFS and D630 hardware support.
- `NOTES-legacy.md`: historical hardware/build notes; this README and `docs/hardware-inventory.md` are current sources of truth.

### Gentoo distribution-kernel baseline

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
- **Profile 30:** use only for D630 Tiny. Its kernel is paired with the standalone BusyBox initramfs in `d630-tiny/`; it does not boot the Gentoo SquashFS root. The target is a single built-in kernel with `CONFIG_MODULES=n`, so the runtime does not need a module loader or `/lib/modules` tree. Every required tristate driver must resolve to `=y` in the final `.config`.
- **Profile 40:** use for `/d630-gentoo/kernel` + `initramfs` + `squashfs`. Root-discovery dependencies must be built in because modules cannot be loaded from the not-yet-mounted SquashFS.

Do not install or merge all three profiles together. Gentoo's `/etc/kernel/config.d` is global rather than version-specific; use one active D630 overlay when comparing kernel versions.

### Profile 30 — D630 Tiny standalone kernel

D630 Tiny is a text-mode, RAM-oriented system. GRUB loads a kernel image and the separate BusyBox initramfs; the initramfs supplies the root filesystem and userspace. This kernel is deliberately separate from profile 40: it does not need a Gentoo root, SquashFS, OverlayFS or a loop device. Runtime changes are volatile unless the initramfs is rebuilt and saved.

The Tiny kernel is being reduced from upstream `make tinyconfig`, then expanded only with the subsystem foundations and hardware required by the D630. A bare `tinyconfig` is not a usable D630 hardware configuration: it leaves major parent subsystems such as the block layer, PCI and networking disabled. Kconfig then discards dependent settings from a hardware fragment even when those individual lines say `=y`. Enable the prerequisite subsystem roots before merging the D630 fragment, run `make olddefconfig`, and inspect the resolved full `.config`. The fragments alone do not prove that a driver survived dependency resolution.

The intended no-module design is explicit: `CONFIG_MODULES=n`. With module support disabled, there must be no `=m` entries and no runtime dependency on kernel modules. Do not confuse this with merely omitting a modules archive; required drivers must be compiled into the kernel itself.

| Built-in area | D630 Tiny requirements |
|---|---|
| Boot and root filesystems | External initramfs, devtmpfs, procfs, sysfs and tmpfs |
| Local and removable storage | PCI, block layer, libata, AHCI, ATA_PIIX, SCSI disk, ext4, NTFS3, FAT/VFAT and exFAT |
| USB 2.0 | USB core, Intel UHCI and EHCI host controllers, HID and USB mass storage; xHCI/USB 3.0 is disabled for this machine |
| Android connectivity | USB networking framework, CDC Ethernet and RNDIS host for phone tethering; keep ADB/fastboot userspace tools in the initramfs separately |
| Graphics and console | Intel AGP, DRM/i915 for GM965/GMA X3100, framebuffer emulation and framebuffer console |
| Wi-Fi | cfg80211, mac80211 and Intel 3945ABG (`iwl3945`); include the matching firmware and regulatory database in the initramfs |
| Keyboard and pointing devices | i8042/serio, AT keyboard, evdev, PS/2 ALPS DualPoint touchpad and TrackPoint, plus USB HID |
| Dell laptop platform | ACPI-WMI, Dell SMBIOS WMI/SMM backends, Dell WMI hotkeys and Dell Laptop Extras |
| Power and thermal management | ACPI battery/buttons/thermal, CPU frequency scaling, thermal framework and Core temperature sensors |
| Compressed swap | Built-in ZRAM with the LZ4 backend and `CONFIG_SWAP=y`; userspace must create `/dev/zram0`, set its size, run `mkswap` and `swapon` |

ZRAM is initialized automatically by the Tiny `/init` script after `/dev`, `/proc` and `/sys` are mounted. The startup code sizes `/dev/zram0` to 40% of detected `MemTotal`, runs `mkswap`, and enables it with `swapon`; allocation of compressed pages remains demand-driven. The kernel profile enables `CONFIG_SWAP=y`, `CONFIG_ZRAM=y`, `CONFIG_ZRAM_BACKEND_LZ4=y` and `CONFIG_ZRAM_DEF_COMP_LZ4=y`; ZRAM selects its `zsmalloc` allocator. Optional compressors, writeback, multi-compression and debug statistics remain disabled. The initramfs builder checks that BusyBox contains both `mkswap` and `swapon`, and the Tiny QEMU workflow checks that `/dev/zram0` appears in `/proc/swaps`. This automated path is implemented in source; it still requires a successful workflow run and physical D630 validation.

The current low-latency experiment also evaluates PREEMPT_RT, a 1000 Hz kernel tick and high-resolution timers. These are tuning choices, not prerequisites for boot. A 1000 Hz tick does not by itself guarantee a 1 ms scheduling deadline; measure latency, throughput, power use and thermal behavior on the physical two-core D630 before treating this combination as the default.

The compiler experiment uses Clang/LLVM with the kernel's Clang ThinLTO Kconfig option and `KCFLAGS="-mtune=core2 -O3"`. Keep the kernel's generic x86-64 instruction-set baseline: do not use `-march=core2`, `-march=native` or a nonexistent x86-64 `CONFIG_MCORE2` selector. ThinLTO and `-O3` are experimental until the resulting image builds, boots and is benchmarked on the D630. Build parallelism such as `-j8` affects build time only; it is not a runtime optimization.

## Build

For profile 20, install the one fragment and build with Portage:

```sh
curl -fsSL https://raw.githubusercontent.com/AmrUser-48/d630-gentoo/main/kernels/profiles/20-d630-base.config -o /etc/kernel/config.d/20-d630-base.config
echo '=sys-kernel/gentoo-kernel-7.2.14 ~amd64' > /etc/portage/package.accept_keywords/d630-kernel-test
emerge --ask --verbose --buildpkgonly =sys-kernel/gentoo-kernel-7.2.14
```

Add a `~amd64` keyword exception for the exact testing version before emerging it. `--buildpkgonly` creates the binary package without replacing the installed kernel. After the build, inspect the resolved `.config` under `/var/tmp/portage/sys-kernel/gentoo-kernel-*/work/`; confirm AHCI, ATA_PIIX, ext4, i915, iwl3945, HDA/SigmaTel and USB RNDIS resolved as intended. Do not treat the fragment alone as proof that every symbol survived Kconfig dependency resolution.

Current custom workflow: [Build D630 Gentoo SFS built-in kernel and initramfs](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-kernel.yml). It merges profile 40 and publishes a kernel/initramfs bundle.

For interactive Gentoo kernel work, use [Kernel Builder — Interactive](../.github/workflows/kernel-builder-interactive.yml). Dispatch it with one profile selected: profile 20 is the Gentoo distribution-kernel `config.d` overlay; profiles 30 and 40 are standalone fragments for Tiny and the Gentoo live/SquashFS kernel paths. The workflow downloads a fresh official OpenRC Stage 3 and opens a temporary Tailnet-only SSH session. Profile 20 is installed in `/etc/kernel/config.d/`; profiles 30 and 40 are made available under `/root/d630-kernel-profiles/` without being merged into Gentoo's distribution-kernel build. Each dispatch has its own concurrency group. The runner does not import prior runner state or binpkg archives, and it does not save a session snapshot, upload session artifacts or publish a release.

Run static checks from repository root:

    bash scripts/validate-kernel-profiles.sh
    bash scripts/validate-kernel-config.sh

The Tiny initramfs workflow currently consumes a pinned kernel bundle; it does not yet build profile 30. The interactive kernel builder makes the selected profile fragment available inside the temporary Gentoo chroot, but the Tiny configuration still has to be generated and compiled there. Profile 30 needs a dedicated kernel build/release path before it can replace the pinned kernel in the Tiny release workflow.

For the manual Tiny kernel experiment, compile only the kernel image when `CONFIG_MODULES=n`; there is no `modules_install` stage:

```sh
export ARCH=x86_64
export LLVM=/usr/lib/llvm/22/bin/
export LLVM_IAS=1
export KCFLAGS="-mtune=core2 -O3"
make -j8 bzImage
```

Select ThinLTO in the resolved kernel configuration; do not pass GCC-style `-flto` as a substitute. Confirm `CONFIG_LTO_CLANG_THIN=y`, `CONFIG_PREEMPT_RT=y`, `CONFIG_HZ_1000=y` and `CONFIG_HIGH_RES_TIMERS=y` in the final `.config` when testing that variant. The kernel image is `arch/x86/boot/bzImage`. Keep it matched with the Tiny initramfs and its firmware set.

## Releases

Latest bundle: [d630-kernel-6.18.56-run-41134237939](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-41134237939). Older bundles remain while workflows pin their exact tags; see the [release index](../docs/releases.md).

## Validation

Static profile validators inspect fragments and selected Kconfig requirements; they do not compile a kernel. For the Tiny no-module target, inspect the *resolved full* `.config`, not only the fragment:

```sh
grep -E '^(CONFIG_(BLOCK|PCI|NET|NETDEVICES|USB_SUPPORT|EXT4_FS|NTFS3_FS|USB_EHCI_HCD|USB_UHCI_HCD|USB_NET_RNDIS_HOST|DRM_I915|IWL3945|DELL_WMI|DELL_LAPTOP|SWAP|ZRAM|ZRAM_BACKEND_LZ4|ZRAM_DEF_COMP_LZ4))=y' .config
grep -E '^# CONFIG_(MODULES|USB_XHCI_HCD) is not set' .config
! grep -q '=m' .config
```

For every release, verify the kernel/initramfs/firmware manifest and checksums, then test QEMU boot. Confirm USB RNDIS tethering, Wi-Fi firmware loading, storage/filesystem mounts, console and input devices separately. QEMU checks do not establish that the real D630's i915, iwl3945, Alps touchpad, TrackPoint, Dell WMI, thermal and power-management paths work; physical D630 testing is required.

## Related documentation

- [Repository overview](../README.md)
- [Hardware inventory](../docs/hardware-inventory.md)
- [Known issues](../docs/known-issues.md)
- [Legacy notes](NOTES-legacy.md)
- [Release index](../docs/releases.md)
