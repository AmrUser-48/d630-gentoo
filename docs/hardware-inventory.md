# Dell Latitude D630 hardware inventory

This file is the hardware source of truth for the `d630-gentoo` kernel configuration, firmware selection, and Gentoo package/USE-flag decisions. Separate confirmed target requirements from items that still need an on-device PCI/USB ID.

## Target and build constraints

| Item | Current target |
|---|---|
| Laptop | Dell Latitude D630 |
| Boot mode | Legacy BIOS; do not require UEFI |
| CPU | Intel Core 2 Duo T7250, 2 cores, 2.00 GHz |
| Architecture | x86_64 / amd64 |
| Compiler tuning | `-O2 -pipe -march=core2 -mtune=core2`; never `-march=native` in CI |
| Storage constraint | Small SSD and a small installed-system partition; minimize final image and module footprint |
| Build environment | GitHub Actions; the D630 is not the build host |
| Final runtime | No Portage tree, compiler toolchain, headers, source trees, or build caches |

## Hardware and support matrix

Status labels: **Known** means explicitly established for this target; **identify** means collect the exact device ID before making a final kernel/module decision.

| Component | Current knowledge | Kernel / userspace plan |
|---|---|---|
| CPU | **Known:** Intel Core 2 Duo T7250 (Merom), x86_64 | Build for `CONFIG_MCORE2` where available; use Core 2 compatible compiler flags. Do not assume the CI CPU matches the target. |
| Firmware boot | **Known:** legacy BIOS | BIOS boot path and GRUB PC target; no UEFI dependency. |
| Integrated GPU | **Known:** Intel GM965 / GMA X3100, Intel Gen4 | Keep `CONFIG_DRM`, `CONFIG_DRM_I915`, KMS, framebuffer console and Xorg modesetting support. Mesa must retain Intel Gen4 support; see the dedicated section below. |
| Wi-Fi | **Known:** Intel PRO/Wireless 3945ABG | Keep `CONFIG_IWL3945` and its dependencies; include the matching `iwl3945` firmware from `sys-kernel/linux-firmware`. Verify exact PCI ID and firmware load in logs. |
| Ethernet | **Identify exact controller** | Keep the module matching the actual PCI ID; do not guess between the Ethernet options offered across D630 configurations. |
| Audio | **Known:** Intel HD Audio platform; exact codec/controller IDs not yet recorded | Keep HDA controller and codec support; identify the codec with PCI/ALSA output before pruning codec modules. Do not retain every sound driver. |
| Bluetooth | **Required**; exact Bluetooth device/bus ID not recorded | Keep Bluetooth core and the transport driver that matches the detected adapter; check whether it is USB-attached. |
| USB | **Required** for storage, keyboard/mouse, joystick, and Android devices | Keep xHCI only if hardware/needs require it; preserve the actual EHCI/OHCI controllers, USB HID, USB storage, USB serial and RNDIS support as applicable. D630-era hardware normally uses USB 2.0 controllers; confirm IDs. |
| USB joystick | **Known requirement** | Keep input/joystick and USB HID support; no special userspace driver unless the device needs one. |
| Android | **Known requirement:** ADB, fastboot and USB RNDIS | Include `dev-util/android-tools` or the validated Gentoo package providing ADB/fastboot; retain USB networking/RNDIS kernel support when needed. |
| Storage controller | **Identify exact SATA/AHCI or compatibility mode** | Keep libata/AHCI and SCSI disk dependencies if exposed by the controller; preserve USB mass storage. Confirm BIOS SATA setting and PCI ID. |
| Filesystems | **Known:** Btrfs and NTFS are required | Keep Btrfs support and NTFS read/write support suitable for the chosen kernel; retain FAT/VFAT and ISO9660 for boot media. Add ext filesystems commonly encountered on rescue jobs. |
| Optical drive | D630 may have an internal optical drive; **confirm use** | SATA/ATAPI support if present; not a reason to keep unrelated drivers. |
| Card reader | Exact controller and requirement **unknown** | Identify from `lspci -nnk`; enable only if the user intends to use SD/MMC cards. |
| PC Card / ExpressCard | Exact controller and requirement **unknown** | Identify from PCI inventory; include only if needed for rescue peripherals. |
| FireWire / modem / WWAN / webcam | **Not confirmed** | Do not include by default without inventory evidence or an explicit requirement. |
| Display, keyboard, touchpad, pointing stick | Laptop internal devices; exact input bus IDs not recorded | Keep i8042/serio, AT keyboard, evdev/libinput and generic HID as required; verify touchpad/pointing-stick behavior. |
| Power management | ACPI laptop | Keep ACPI, battery, thermal and fan-related platform support; validate suspend/resume and thermal reporting on real hardware. |
| Memory compression | **Known preference:** built-in ZRAM | Keep ZRAM and select a compressor supported by the target kernel; test availability of LZO, LZ4, LZ4HC and Zstd before choosing the final set. |

## Intel GM965 / GMA X3100 graphics: kernel, Mesa and Xorg

GMA X3100 is the Gen4 graphics core used by the GM965 family. Treat this as legacy Intel graphics, not as a modern Intel Xe GPU.

### Kernel requirements

- Enable DRM and Intel `i915` (`CONFIG_DRM_I915`), preferably as built-in for reliable early graphics on this live image.
- Keep kernel mode setting (KMS), framebuffer emulation and framebuffer console so boot output does not depend on a proprietary driver.
- Keep AGP support if required by the selected kernel configuration and platform dependencies.
- Do not add AMD or NVIDIA DRM drivers without hardware evidence.
- Do not assume that modern Intel DMC/GuC/HuC firmware is required: those firmware needs apply to much newer generations. Check `dmesg` for actual firmware requests on this hardware.

### Gentoo / Mesa starting point

- The current Gentoo Intel graphics guidance maps **Gen4 and newer** to `VIDEO_CARDS="intel"`. This is the initial setting to validate against the selected Gentoo profile and current ebuilds.
- Mesa's **Crocus** Gallium driver is the relevant modern Mesa path to investigate for Intel Gen4 through Gen7.5. Confirm the selected Mesa ebuild actually builds/enables it and test the renderer on the finished image.
- Do **not** blindly set `VIDEO_CARDS="i915"` just because the Linux kernel driver is named `i915`. Gentoo's `video_cards_i915` flag refers to the older Intel driver family and is not equivalent to `CONFIG_DRM_I915`.
- `media-libs/mesa-amber` is a legacy Mesa package for classic drivers. Do not add it automatically; only consider it if Crocus fails on the actual X3100 and a controlled comparison shows a benefit.
- Start with the Xorg **modesetting** DDX supplied by `x11-base/xorg-server`. The separate `x11-drivers/xf86-video-intel` DDX is older and should only be added if real-hardware testing shows a specific reason.
- Do not enable Vulkan or modern Intel media firmware on the assumption that this GPU supports them. The Gentoo Intel graphics table lists Gen4 OpenGL support up to 2.1 and no Vulkan support. Hardware video acceleration capabilities are limited and differ between GM965 and later G45/GM45 chipsets; do not assume VA-API works on X3100.

### Graphics acceptance tests

On the live system, collect and review:

```sh
lspci -nnk | grep -A4 -Ei 'VGA|3D|Display'
lsmod | grep -E 'i915|drm'
dmesg | grep -Ei 'i915|drm|firmware|gpu'
glxinfo -B
```

Expected results: the PCI device binds to `i915`; Xorg uses modesetting or a deliberately tested Intel DDX; OpenGL reports a hardware Intel/Mesa renderer rather than `llvmpipe`. If `glxinfo` is unavailable in the image, temporarily include the package that provides it in a test image, not necessarily the final runtime.

## Collect the exact hardware IDs

Run these on the actual D630 under Linux and add the output (with serial numbers, MAC addresses, and other personal identifiers removed) to this file. PCI IDs matter more than marketing names when selecting kernel drivers.

```sh
# PCI devices, vendor/device IDs, and currently bound kernel drivers
lspci -nnk

# USB device IDs (useful for Bluetooth, card readers, and peripherals)
lsusb

# Audio cards and detected codecs
cat /proc/asound/cards 2>/dev/null
grep -H . /proc/asound/card*/codec#* 2>/dev/null

# Block devices and filesystems; do not include UUIDs if sharing publicly
lsblk -o NAME,TYPE,SIZE,FSTYPE,TRAN,MODEL

# Radio devices and block state
rfkill list 2>/dev/null

# Firmware errors and detected drivers from the current boot
dmesg | grep -Ei 'firmware|iwl3945|i915|drm|bluetooth|hda|r8169|tg3|e1000|b44|ahci|ata[0-9]'
```

If a command is unavailable, skip it rather than installing a large diagnostic suite solely for inventory. Review output before publishing it; do not include serial numbers, MAC addresses, Wi-Fi credentials, or other secrets.

## How inventory changes should drive the build

1. Match each PCI/USB ID to its kernel driver and required firmware.
2. Record whether the driver should be built-in or modular based on boot-criticality and hotplug needs.
3. Map each runtime feature to the smallest justified Gentoo package set and USE flags.
4. Validate package atoms and USE flags against the selected Gentoo profile and repository state; do not assume a flag exists because a similarly named flag exists elsewhere.
5. Build a test image, inspect `lspci -nnk`, `dmesg`, graphics renderer and network/audio behavior, then remove only demonstrably unnecessary components.
6. Keep unknown devices marked as unknown until the target hardware provides evidence. Never substitute a guess for an observed device ID.

## Reference

- Gentoo Wiki, Intel Graphics: https://wiki.gentoo.org/wiki/Intel_Graphics
- Gentoo package USE flag, `video_cards_i915`: https://packages.gentoo.org/useflags/video_cards_i915
