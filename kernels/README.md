# D630 kernel configurations

## Overview

This directory defines three separate Linux kernel targets for the Dell Latitude D630. Each target has a different configuration strategy: Gentoo's maintained distribution kernel for a conventional installation, a no-module kernel for D630 Tiny, and a built-in-first kernel for the Gentoo SquashFS live system. The profiles are fragments or overlays, not interchangeable complete kernel configurations.

The design goal is hardware accuracy, not the smallest possible configuration at any cost. Keep the D630's confirmed devices and declared peripherals; remove unrelated hardware families; retain only deliberate expansion support. Kconfig's resolved output, not the text of a fragment, is the final authority.

## Status

| Profile | Target | Current state |
|---|---|---|
| [20-d630-base.config](profiles/20-d630-base.config) | Conventional installed Gentoo | Gentoo distribution-kernel overlay exists. Its effective configuration still needs a verified rebuild; see the NVMe note below. |
| [30-d630-live.config](profiles/30-d630-live.config) | D630 Tiny | Tinyconfig-derived no-module profile exists. The current Tiny release workflow does not yet build its kernel from this profile. |
| [40-d630-builtin.config](profiles/40-d630-builtin.config) | Gentoo live SquashFS | Used by the dedicated kernel workflow. It builds the kernel, matching module archive and external initramfs; physical D630 validation remains separate. |

**Known configuration gap:** the inspected installed file /boot/config-6.18.57-d630-gentoo contained CONFIG_NVME_CORE=y and CONFIG_BLK_DEV_NVME=y, although Profile 20 requests both disabled. That config proves what the installed kernel contains; it does not prove whether that build consumed the current overlay. Do not describe Profile 20 as successfully stripped until a fresh build made after installing the fragment has been inspected.

Profile 40 explicitly disables xHCI and the media/DVB stack, but currently has no complete explicit NVMe exclusion. Its resolved config must be checked before claiming that the SFS kernel contains no NVMe support. Profile 30 starts from tinyconfig, but its final resolved config must still be checked for disabled NVMe and xHCI symbols.

## Layout

- [profiles/20-d630-base.config](profiles/20-d630-base.config) — modular overlay for Gentoo's distribution-kernel build.
- [profiles/30-d630-live.config](profiles/30-d630-live.config) — hardware and feature fragment for the standalone Tiny kernel.
- [profiles/40-d630-builtin.config](profiles/40-d630-builtin.config) — D630 hardware and early-root fragment for the Gentoo live SquashFS kernel.
- [../docs/hardware-inventory.md](../docs/hardware-inventory.md) — detailed device inventory and driver decisions.
- [../scripts/validate-kernel-profiles.sh](../scripts/validate-kernel-profiles.sh) and [../scripts/validate-kernel-config.sh](../scripts/validate-kernel-config.sh) — static source-profile checks.
- [NOTES-legacy.md](NOTES-legacy.md) — historical notes; current policy lives in the hardware inventory and this README.

## Requirements

The target is a Dell Latitude D630 with:

- Intel Core 2 Duo T7250 (Merom), two cores, x86-64.
- Legacy BIOS boot; no UEFI or EFI-stub requirement.
- Intel GM965 / GMA X3100 graphics, PCI IDs 8086:2a02 and 8086:2a03.
- Intel PRO/Wireless 3945ABG, PCI ID 8086:4222.
- Intel ICH8M AHCI SATA controller and ATA PIIX IDE/ATAPI controller.
- Intel ICH8 UHCI/EHCI USB 2.0 controllers.
- Intel HDA audio controller with SigmaTel/IDT STAC9205 codec.
- i8042 keyboard and Alps DualPoint touchpad/TrackPoint.
- ACPI laptop battery, thermal, fan and Dell platform support.

Use a generic x86-64 kernel ISA baseline. Kernel builds may use KCFLAGS=-mtune=core2; do not use -march=core2 or -march=native for the kernel, and do not add CONFIG_MCORE2. Userland compiler flags are a separate policy. CONFIG_X86_MSR=y and CONFIG_X86_CPUID=y are required and are present in all three current profile fragments.

## Use

### Keep the three targets separate

| Profile | Baseline | Modules | Root model |
|---|---|---|---|
| 20 — Gentoo installed | Version-specific Gentoo distribution-kernel config | Yes; device drivers modular where practical | Ordinary installed root; ext4 boot/root path built in |
| 30 — Tiny | Upstream make tinyconfig, expanded with required platform foundations and D630 hardware | No; CONFIG_MODULES=n and all required drivers built in | External initramfs only; no Gentoo root, SquashFS or loop device |
| 40 — Gentoo live | x86_64_defconfig plus the D630 fragment | Module support remains enabled; early boot and root-discovery drivers are built in | External initramfs discovers and mounts the Gentoo SquashFS root, then uses OverlayFS |

Never merge all three profiles. Gentoo's /etc/kernel/config.d directory is global, not per-kernel-version: only the intended Profile 20 overlay should be active there. Profiles 30 and 40 are for their own custom-kernel build paths, not additional config.d overlays on a Gentoo distribution-kernel build.

### Configuration strategy

**Profile 20 — use Gentoo's baseline, not tinyconfig.** The Gentoo distribution-kernel ebuild selects a version-specific upstream distribution configuration and Gentoo's common configuration. Its kernel-build integration then merges user snippets from /etc/kernel/config.d/*.config in lexical order, after the distribution config and any savedconfig input. A config.d fragment is an overlay, not a replacement full .config. Avoid USE=savedconfig for this design unless deliberately replacing the distribution baseline with a saved full configuration.

**Profile 30 — start with make tinyconfig.** A bare tinyconfig is not a usable laptop kernel: it also disables parent infrastructure such as PCI, the block layer, USB, networking and input. Enable the required subsystem foundations, merge the D630 hardware fragment, run olddefconfig, then inspect the complete resolved .config. Every driver required by Tiny must resolve to =y. With CONFIG_MODULES=n there must be no =m entries and no /lib/modules dependency.

**Profile 40 — start with x86_64_defconfig.** Merge the live/SquashFS fragment and resolve dependencies. The block layer, storage controller, filesystems needed to locate the SquashFS, loop, SquashFS-Zstd, OverlayFS, USB, Wi-Fi and graphics paths required before or during early userspace must be built in. Do not assume a fragment assignment survived Kconfig.

### Hardware policy

| Subsystem | D630 policy |
|---|---|
| CPU, MSR, CPUID, ACPI, Dell platform, thermal and CPU frequency | Keep |
| AHCI, ATA PIIX, SCSI disk and required root filesystem | Built in for the relevant root path |
| NTFS3, Btrfs, exFAT, VFAT, optical media and rescue filesystems | Modules for installed Gentoo; built in only where the live boot path requires them |
| GM965 / GMA X3100 | i915; no modern Intel DMC/GuC/HuC firmware blobs are required for this Gen4 GPU |
| Intel 3945ABG | iwlegacy / iwl3945 plus cfg80211 and mac80211 |
| SigmaTel HDA audio | Keep HDA and the matching codec driver |
| ICH8 UHCI/EHCI | Keep USB 2.0 host support |
| USB storage, HID and Android RNDIS/CDC networking | Keep as deliberate removable-device and tethering support |
| PS/2 ALPS DualPoint and TrackPoint | Keep |
| DVB, TV tuners, V4L2 capture and CEC | Disable; not part of the target |
| xHCI / USB 3 host controller | Disable; no xHCI controller appears in the supplied D630 inventory |
| PCI NVMe and NVMe-over-Fabrics/target support | Disable for this hardware profile; verify the entire resolved NVMe family |
| AMD/NVIDIA, virtual display, unrelated hypervisor and server hardware | Disable unless a concrete use case is approved |
| Bluetooth | Provisional expansion support; identify the internal adapter before claiming hardware validation |
| uinput, smart-card access and other optional facilities | Enable only when a defined userspace or peripheral requirement needs them |

The current PCI inventory showed AHCI, ATA PIIX, Intel graphics, Intel Wi-Fi, HDA, ICH8 USB and SMBus. The USB inventory showed a Huawei MTP device, O2 Micro CCID reader and USB mouse. It did not show an Ethernet controller, xHCI controller or Bluetooth adapter. Do not add drivers based solely on a laptop model's possible factory options; update [the hardware inventory](../docs/hardware-inventory.md) when a device is actually identified.

A module set to =m is not loaded into memory merely because it exists on disk. Modules are appropriate for optional USB devices, audio and removable filesystems in the installed Gentoo profile. Tiny is different: with module support disabled, every needed driver must be built in.

### Pruning and firmware rules

Use hardware discovery to form the candidate driver set, not as the only source of truth. lspci -nnk and lsusb identify enumerated hardware; lsmod and module-use history show what has been loaded during observed use. localmodconfig can help reduce a starting config, but one lsmod snapshot misses disconnected devices and features used only occasionally. Preserve an explicit allowlist for declared peripherals such as USB storage, USB HID and Android RNDIS.

Use the kernel's merge_config.sh to apply fragments and review its override/dependency warnings. After make olddefconfig, inspect the resolved .config. Use scripts/diffconfig -m to generate a maintainable fragment from a known baseline and a validated final config. A requested CONFIG_FOO=n line in a fragment is not proof that the final kernel has disabled it.

For this machine, check at least the following forbidden families in every final config intended to be stripped:

- NVMe: CONFIG_BLK_DEV_NVME, CONFIG_NVME_CORE, NVMe fabrics/transports and CONFIG_NVME_TARGET.
- USB 3: CONFIG_USB_XHCI_HCD and its dependent host/controller options.
- TV/capture: CONFIG_MEDIA_SUPPORT, CONFIG_DVB_CORE and CONFIG_VIDEO_DEV.
- Unused GPU families: AMD, NVIDIA and virtual display drivers.
- Unused wired network drivers and peripheral buses.

Do not confuse NVMEM with NVMe. CONFIG_NVMEM and CONFIG_RTC_NVMEM are non-volatile-memory infrastructure symbols and are unrelated to PCI NVMe disk support.

Firmware is separate from kernel configuration:

- Intel 3945ABG requires iwlwifi-3945-2.ucode.
- The wireless regulatory database consists of regulatory.db and regulatory.db.p7s. If cfg80211 is built in and Wi-Fi must work from the external initramfs before the real root is mounted, include both files in that initramfs. Kernel embedding is not required when the boot initramfs already supplies them.
- The D630's GM965 / GMA X3100 does not require the modern i915 firmware blobs for newer Intel GPU generations.
- Intel CPU microcode is a separate early-microcode payload; keep it matched to the CPU and kernel bundle.

## Build

### Profile 20 — Gentoo distribution kernel

From a checkout of this repository on the Gentoo build system, install only the Profile 20 overlay:

~~~bash
install -D -m 0644 kernels/profiles/20-d630-base.config /etc/kernel/config.d/20-d630-base.config
ls -l /etc/kernel/config.d/
emerge --ask --verbose --buildpkgonly --reinstall-atoms =sys-kernel/gentoo-kernel-6.18.57 =sys-kernel/gentoo-kernel-6.18.57
~~~

Before building, check that no stale D630 or experimental fragments are also active in /etc/kernel/config.d/. After the build, inspect the effective config saved with the built kernel under /usr/src/linux-<kernel-release>/.config and the Portage work directory. Check the merge output and verify that the intended exclusions resolved to disabled symbols. Do not infer success from the source fragment or package installation alone.

### Profile 30 — Tiny kernel

The Tiny kernel requires its own dedicated build path: initialize an upstream tinyconfig baseline, enable required platform foundations, merge Profile 30, resolve dependencies, and reject the result if CONFIG_MODULES is enabled, any =m setting remains, or a required D630 driver did not resolve to =y. Compile the kernel image only; there is no modules_install stage. The current Tiny initramfs workflow does not yet perform this kernel build.

### Profile 40 — Gentoo live SquashFS kernel

Use [Build D630 Gentoo SFS built-in kernel and initramfs](../.github/workflows/build-d630-kernel.yml). It starts from x86_64_defconfig, merges Profile 40, resolves the config, builds bzImage and modules, constructs the external initramfs, and publishes a matching kernel bundle. The workflow's resulting .config and release manifest are the evidence for that specific build.

For all kernel builds, retain the generic x86-64 ISA baseline and use KCFLAGS=-mtune=core2 when specified by the build path. Do not copy userland -march=core2 into kernel compilation. Build duration and image size are not substitutes for target runtime measurements.

## Releases

Kernel images, module archives, external initramfs images, firmware bundles, configs, manifests and checksums are version-coupled. Use the kernel, module and firmware assets from the same release bundle. The [release index](../docs/releases.md) lists published bundles; do not combine assets from different run tags or assume that a release for Profile 40 is a Profile 30 Tiny kernel.

## Validation

Run the source-level checks from the repository root:

~~~bash
bash scripts/validate-kernel-profiles.sh
bash scripts/validate-kernel-config.sh
~~~

These scripts validate fragments and selected policy assertions. They do not prove that a Portage build consumed an overlay, that a driver survived Kconfig, or that a kernel booted.

For a completed Gentoo build, inspect the full generated .config and check the actual policy symbols. For example:

~~~bash
grep -E '^(CONFIG_(X86_MSR|X86_CPUID|BLK_DEV_NVME|NVME_CORE|NVME_FABRICS|NVME_TARGET|USB_XHCI_HCD|MEDIA_SUPPORT|DVB_CORE|IWL3945|DRM_I915)=|# CONFIG_(BLK_DEV_NVME|NVME_CORE|NVME_FABRICS|NVME_TARGET|USB_XHCI_HCD|MEDIA_SUPPORT|DVB_CORE) is not set)' /usr/src/linux-*/.config
~~~

For Profile 30, verify the resolved config has CONFIG_MODULES disabled, no =m entries, and every required D630 driver built in. For all profiles, verify the matching module tree and firmware files when modules are enabled, then test QEMU and physical hardware separately. QEMU does not validate the physical 3945ABG radio, X3100 acceleration, SigmaTel audio, Alps input, Dell platform controls, thermal behavior or suspend/resume.

## Related documentation

- [D630 Tiny two-file boot](../d630-tiny/README.md)
- [Gentoo live OS](../d630-gentoo/README.md)
- [Hardware inventory](../docs/hardware-inventory.md)
- [Known issues](../docs/known-issues.md)
- [Release index](../docs/releases.md)
- [Gentoo kernel-build.eclass](https://devmanual.gentoo.org/eclass-reference/kernel-build.eclass/)
- [Gentoo Distribution Kernel guide](https://wiki.gentoo.org/wiki/Distribution_Kernel)
- [Linux kernel Kconfig documentation](https://docs.kernel.org/kbuild/kconfig.html)
- [Linux kernel merge_config.sh](https://github.com/torvalds/linux/blob/master/scripts/kconfig/merge_config.sh)
