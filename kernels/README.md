# D630 kernel configurations

## Overview

This directory defines three separate Linux kernel targets for the Dell Latitude D630. Each target has a different configuration strategy: Gentoo's maintained distribution kernel for a conventional installation, a no-module kernel for D630 Tiny, and a built-in-first kernel for the Gentoo SquashFS live system. The profiles are fragments or overlays, not interchangeable complete kernel configurations.

The design goal is hardware accuracy, not the smallest possible configuration at any cost. Keep the D630's confirmed devices and declared peripherals; remove unrelated hardware families; retain only deliberate expansion support. Kconfig's resolved output, not the text of a fragment, is the final authority.

## Status

| Profile | Target | Current state |
|---|---|---|
| [20-d630-base.config](profiles/20-d630-base.config) | Conventional installed Gentoo | Standard Gentoo distribution-kernel overlay; D630 device drivers are modular where Kconfig permits. A fresh build must still verify the resolved config. |
| [30-d630-live.config](profiles/30-d630-live.config) | D630 Tiny | Tinyconfig-derived no-module profile exists. The current Tiny release workflow does not yet build its kernel from this profile. |
| [40-d630-builtin.config](profiles/40-d630-builtin.config) | Gentoo live SquashFS | Used by the dedicated kernel workflow. It builds the kernel, matching module archive and external initramfs; physical D630 validation remains separate. |

**Profile 20 policy:** the standard installed kernel preserves Gentoo's broad distribution-kernel baseline, with two hardware-specific exclusions: NVMe support and the xHCI USB 3 host-controller stack are disabled because the D630 has neither. Ethernet, media/capture, AMD/NVIDIA, virtual-device and other generic driver families remain inherited from Gentoo's version-specific baseline. Confirmed D630 device drivers are modular wherever Kconfig permits.

Profile 40 explicitly disables xHCI and the media/DVB stack, but currently has no complete explicit NVMe exclusion. Its resolved config must be checked before claiming that the SFS kernel contains no NVMe support. Profile 30 starts from tinyconfig, but its final resolved config must still be checked for disabled NVMe and xHCI symbols.

## Layout

- [Profile 20 Debian reference inventory](profiles/20-d630-base/README.md) — text-only Debian hardware, module, configuration and firmware inventory used to refine the base overlay.

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

Use a generic x86-64 kernel ISA baseline. Kernel builds may use KCFLAGS=-mtune=core2; do not use -march=core2 or -march=native for the kernel, and do not add CONFIG_MCORE2. Userland compiler flags are a separate policy. CONFIG_X86_MSR=y and CONFIG_X86_CPUID=y are required and are present in all three current profile fragments. Keep CONFIG_PROC_FS=y, CONFIG_IKCONFIG=y and CONFIG_IKCONFIG_PROC=y enabled by default in nearly all kernels so the running kernel exposes its exact embedded configuration at /proc/config.gz. Disable IKCONFIG only for an intentionally minimal or size-constrained target with a documented reason; a reference distribution config omitting it is not a reason to omit it from D630 profiles.

## Use

### Keep the three targets separate

| Profile | Baseline | Modules | Root model |
|---|---|---|---|
| 20 — Gentoo installed | Version-specific Gentoo distribution-kernel config | Yes; D630 device drivers are modules where Kconfig permits; generic distro coverage is retained | Ordinary installed root; SATA/AHCI and ext4 root path built in |
| 30 — Tiny | Upstream make tinyconfig, expanded with required platform foundations and D630 hardware | No; CONFIG_MODULES=n and all required drivers built in | External initramfs only; no Gentoo root, SquashFS or loop device |
| 40 — Gentoo live | x86_64_defconfig plus the D630 fragment | Module support remains enabled; early boot and root-discovery drivers are built in | External initramfs discovers and mounts the Gentoo SquashFS root, then uses OverlayFS |

Never merge all three profiles. Gentoo's /etc/kernel/config.d directory is global, not per-kernel-version: only the intended Profile 20 overlay should be active there. Profiles 30 and 40 are for their own custom-kernel build paths, not additional config.d overlays on a Gentoo distribution-kernel build.

### Configuration strategy

**Profile 20 — use Gentoo's baseline, not tinyconfig.** The Gentoo distribution-kernel ebuild selects a version-specific upstream distribution configuration and Gentoo's common configuration. Its kernel-build integration then merges user snippets from /etc/kernel/config.d/*.config in lexical order, after the distribution config and any savedconfig input. A config.d fragment is an overlay, not a replacement full .config. Avoid USE=savedconfig for this design unless deliberately replacing the distribution baseline with a saved full configuration.

**Profile 30 — start with make tinyconfig.** A bare tinyconfig is not a usable laptop kernel: it also disables parent infrastructure such as PCI, the block layer, USB, networking and input. Kconfig does not automatically enable a symbol's unmet depends-on prerequisites just because the leaf driver is requested; merge_config.sh is a fragment merger, not a dependency-closure solver. Use the fragment only while developing the first working config: enable subsystem foundations first, resolve with olddefconfig, then enable the dependent D630 drivers in a second pass. Use menuconfig's / search on any symbol that refuses to resolve to inspect its direct and recursive dependencies. Once the complete config is correct, save it with make savedefconfig as a dedicated d630-tiny_defconfig and use that defconfig as the reproducible build input. This avoids re-solving the same dependency chain on every build. On kernel upgrades, carry the previous resolved config forward with olddefconfig, inspect scripts/diffconfig output and re-run the required-symbol checks. Every driver required by Tiny must resolve to =y. With CONFIG_MODULES=n there must be no =m entries and no /lib/modules dependency. The current repository profile is still a tinyconfig-derived fragment; the dedicated Tiny kernel build workflow/defconfig has not yet been added.

**Profile 40 — start with x86_64_defconfig.** Merge the live/SquashFS fragment and resolve dependencies. The block layer, storage controller, filesystems needed to locate the SquashFS, loop, SquashFS-Zstd, OverlayFS, USB, Wi-Fi and graphics paths required before or during early userspace must be built in. Do not assume a fragment assignment survived Kconfig.

### Hardware policy

| Subsystem | Profile 20 policy |
|---|---|
| CPU, MSR, CPUID, ACPI and CPU frequency | Keep the required architecture/core infrastructure built in; ACPI device functions and the ACPI cpufreq driver are modules. |
| Root storage | AHCI, SCSI disk support and ext4 remain built in so the ordinary root filesystem does not depend on loading a storage module first. |
| IDE/ATAPI optical drive | ATA PIIX and optical-device support are modules. |
| Btrfs, NTFS3, exFAT, VFAT, ISO9660, UDF, FUSE and SquashFS | Modules. |
| GM965 / GMA X3100 | DRM core and i915 are modules; AGP and framebuffer/console foundations remain built in; Intel AGP driver is modular where supported. |
| Intel 3945ABG | cfg80211, mac80211, iwlegacy and iwl3945 are modules; the matching firmware is supplied separately. |
| ICH8 USB 2.0 | USB core, UHCI/EHCI host drivers, storage, HID and USB networking are modules. |\n| USB 3 / xHCI | Disabled; the D630 has only USB 2.0 UHCI/EHCI controllers. |\n| NVMe | Host, fabrics and target support disabled; the D630 has SATA/AHCI and ATA storage only. |
| Android tethering | CDC Ethernet and RNDIS host drivers are modules. |
| Keyboard, touchpad, TrackPoint and joystick | Input core, AT keyboard and serio/i8042 foundations remain built in; evdev, PS/2 mouse, HID, generic HID, joystick and uinput drivers are modules. Boolean PS/2 protocol options remain enabled. |
| SigmaTel HDA audio and Bluetooth | Sound/ALSA frameworks remain built in; HDA controller/codec and Bluetooth USB transport are modules. |
| Dell platform, battery, fan and sensors | ACPI and Dell platform selector remain built in; ACPI/WMI, SMBIOS/DCDBAS and Dell device drivers are modules where Kconfig permits. Thermal, hwmon and I2C frameworks remain built in; sensor and SMBus-controller drivers are modules. |
| ZRAM | Built in with LZ4 selected as the default compressor; the compressor/backend Kconfig choices require this built-in exception. |
| Other hardware families | Leave Gentoo's standard distribution-kernel defaults intact. Profile 20 does not prune hardware unrelated to the D630. |

The current inventory confirms AHCI, ATA PIIX, Intel graphics, Intel Wi-Fi, HDA, ICH8 USB and SMBus. It does not currently identify an Ethernet controller, xHCI controller or Bluetooth adapter. Profile 20 still leaves generic support for those device families to Gentoo's distribution baseline; absence from this laptop's inventory is not a reason to disable them in the standard kernel. Update [the hardware inventory](../docs/hardware-inventory.md) when a device is identified.

A module set to =m is not loaded into memory merely because it exists on disk. Modules are appropriate for optional USB devices, audio and removable filesystems in the installed Gentoo profile. Tiny is different: with module support disabled, every needed driver must be built in.

### Pruning and firmware rules

Use hardware discovery to form the candidate driver set, not as the only source of truth. lspci -nnk and lsusb identify enumerated hardware; lsmod and module-use history show what has been loaded during observed use. localmodconfig can help reduce a starting config, but one lsmod snapshot misses disconnected devices and features used only occasionally. Preserve an explicit allowlist for declared peripherals such as USB storage, USB HID and Android RNDIS.

Use the kernel's merge_config.sh to apply fragments and review its override/dependency warnings. After make olddefconfig, inspect the resolved .config. Use scripts/diffconfig -m to generate a maintainable fragment from a known baseline and a validated final config. A requested CONFIG_FOO=n line in a fragment is not proof that the final kernel has disabled it.

Apply this broad pruning policy only to profiles that intentionally strip hardware support (Profiles 30 and 40). Profile 20 preserves Gentoo's standard hardware coverage except for its two explicit D630 hardware exclusions: NVMe and xHCI USB 3.

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
emerge --ask --verbose --buildpkgonly sys-kernel/gentoo-kernel
~~~

Before building, check that no stale D630 or experimental fragments are also active in /etc/kernel/config.d/. After the build, inspect the effective config saved with the built kernel under /usr/src/linux-<kernel-release>/.config and the Portage work directory. Verify that the D630 device drivers resolve to modules where Kconfig permits, that the AHCI/ext4 root path remains built in, and that Gentoo's unrelated driver coverage remains inherited. Do not infer success from the source fragment or package installation alone.

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

For a completed Gentoo build, inspect the full generated .config and check the actual policy symbols. On the running kernel, use `zcat /proc/config.gz` to verify the config embedded in that exact image; this distinguishes the active kernel from a stale build artifact or an unrelated `/boot/config-*` file. For example:

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
