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
| CPU | **Confirmed:** Intel Core 2 Duo T7250, family 6/model 15/stepping 13, 2 cores, x86_64; VT-x present | Generic x86-64 kernel ISA baseline; Linux x86-64 Kconfig has no CONFIG_MCORE2 processor-family selector. Use Core 2 userland flags and -mtune=core2 for kernel tuning; never use -march=native in CI. |
| Firmware boot | **Known:** legacy BIOS | BIOS boot path and GRUB PC target; no UEFI dependency. |
| Integrated GPU | **Confirmed:** PCI `8086:2a02` (primary VGA), secondary display function `8086:2a03`, Dell subsystem `1028:01f9`; `i915` is active | Running system has `CONFIG_DRM_I915=m`; `dmesg` shows `i915drmfb` framebuffer. Mesa 22.3.6 reports `Mesa Intel(R) 965GM (CL)`, accelerated=yes, OpenGL 2.1. Keep the tested classic Intel Gen4 path; validate Crocus separately rather than replacing a known-working driver blindly. |
| Wi-Fi | **Confirmed:** PCI `8086:4222`, subsystem `8086:1021`; `iwl3945` is active and firmware `iwlwifi-3945-2.ucode` version `15.32.2.9` loaded | Build `CONFIG_IWL3945` and its required wireless stack in (`=y`); include matching firmware and regulatory database in the runtime ISO. |
| Wired Ethernet | **Intentionally omitted by project scope** | Do not include wired Ethernet drivers. Required networking is Intel 3945ABG Wi-Fi and Android USB RNDIS tethering. |
| Audio | **Confirmed:** controller PCI `8086:284b`; SigmaTel/IDT STAC9205 codec vendor ID `8384:76a0`, subsystem `1028:01f9`; `snd_hda_intel` active | Keep HDA core and IDT/Sigmatel codec support (`snd-hda-codec-idt` family as configured by kernel). Test speaker, headphone, internal mic and digital output before pruning. |
| Bluetooth | Required; Dell rfkill platform exposes `dell-bluetooth`, but no Bluetooth device appeared in `lsusb` or `bluetoothctl list`; software-blocked, not hardware-blocked | Keep Bluetooth core and likely USB transport support, but identify the actual adapter with Bluetooth enabled and `lsusb` before selecting its device-specific driver. Do not assume a working adapter is currently enumerated. |
| USB | **Confirmed:** Intel ICH8 UHCI controllers `8086:2830`, `2831`, `2832`, `2834`, `2835`; EHCI controllers `8086:2836`, `283a` | Keep `uhci_hcd`, `ehci-pci`, USB core, HID and mass-storage support. No xHCI controller appears in this inventory. Keep USB networking/RNDIS and Android interfaces only as required by runtime use. |
| USB joystick | **Known requirement** | Keep input/joystick and USB HID support; no special userspace driver unless the device needs one. |
| Android | **Known requirement:** ADB, fastboot and USB RNDIS tethering | Include validated ADB/fastboot userspace tools. Build USB host, `usbnet`, RNDIS host and CDC Ethernet support in (`=y`) and test phone tethering separately from ADB mode. |
| Storage controller | **Confirmed:** SATA AHCI PCI `8086:2829`, driver `ahci`; IDE controller `8086:2850`, driver `ata_piix`; SATA SSD `HFS064G38MNB-2200A` (~59.6 GiB); ATAPI optical drive `TSSTcorpCD-RW/DVD-ROM TSL462C` | Keep AHCI/libata/SCSI disk and `ata_piix`/ATAPI support if retaining the optical drive. Preserve USB mass storage. Current root is ext4; disk also contains NTFS partitions. |
| Filesystems | **Known:** Btrfs and NTFS are required | Keep Btrfs support and NTFS read/write support suitable for the chosen kernel; retain FAT/VFAT and ISO9660 for boot media. Add ext filesystems commonly encountered on rescue jobs. |
| Optical drive | **Confirmed:** `TSSTcorpCD-RW/DVD-ROM TSL462C`, detected as `/dev/sr0` | Retain ATAPI/SATA optical-drive support if the live environment must boot/read optical media or access this drive. |
| Card reader | Exact controller and requirement **unknown** | Identify from `lspci -nnk`; enable only if the user intends to use SD/MMC cards. |
| PC Card / ExpressCard | Exact controller and requirement **unknown** | Identify from PCI inventory; include only if needed for rescue peripherals. |
| FireWire / modem / WWAN / webcam | **Not confirmed** | Do not include by default without inventory evidence or an explicit requirement. |
| Display, keyboard, touchpad, pointing stick | **Confirmed:** AT keyboard via i8042/serio; AlpsPS/2 ALPS DualPoint Stick and DualPoint TouchPad; external USB mouse `0000:3821` | Keep `i8042`, serio, `atkbd`, `psmouse`, evdev/libinput and USB HID. Keep ACPI video/hotkey input support. |
| Power management | ACPI laptop | Keep ACPI, battery, thermal and fan-related platform support; validate suspend/resume and thermal reporting on real hardware. |
| Memory compression | **Confirmed:** current kernel has `CONFIG_ZRAM=y`; system has `zram0` 1.5 GiB | Keep ZRAM built in; select one or a small set of supported fast compressors after checking the target kernel's config and runtime availability. |

## Confirmed platform details

- DMI identifies `Dell Inc. Latitude D630`, motherboard `0KU184`, BIOS Dell A19.
- Host bridge is Intel Mobile PM965/GM965/GL960 `8086:2a00`; ICH8M LPC interface `8086:2815`; SMBus controller `8086:283e` with `i2c_i801`.
- O2 Micro smart-card reader hub is present over USB: `0b97:7761` hub and `0b97:7772` CCID reader. Keep CCID/PCSC userspace only if smart-card access is desired; retain USB support regardless.
- Current attached Android phone is Huawei `12d1:107d` (MTP). This identifies the current peripheral, not a permanent laptop component. ADB/fastboot/RNDIS need separate mode-specific verification.
- Current block layout: 59.6 GiB SATA disk, two NTFS partitions (579 MiB and 54.3 GiB), 4.7 GiB ext4 system partition, and 1.5 GiB zram. These sizes can change and should not be treated as fixed hardware requirements.
- The supplied `dmesg` confirms `iwlwifi-3945-2.ucode` and regulatory database load. It also records an `i915` CPU pipe B FIFO underrun at startup; graphics nevertheless initializes, framebuffer becomes primary, and Mesa reports accelerated rendering. Treat the underrun as a test observation, not proof of a fatal GPU fault.

## Intel GM965 / GMA X3100 graphics: kernel, Mesa and Xorg

GMA X3100 is the Gen4 graphics core used by the GM965 family. Treat this as legacy Intel graphics, not as a modern Intel Xe GPU.

### Kernel requirements

- Enable DRM and Intel `i915` built in (`CONFIG_DRM=y`, `CONFIG_DRM_I915=y`) for the target image. The current working kernel has it modular (`CONFIG_DRM_I915=m`) and initializes graphics successfully; the project requirement is now to avoid runtime modules from disk, so the custom kernel must build it in.
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

## Still to identify

- Wired Ethernet is out of scope for the custom image. Do not add a wired NIC driver; test Wi-Fi and Android USB RNDIS instead.
- Bluetooth: the Dell platform rfkill switch exists but Bluetooth is software-blocked and no adapter appears in `lsusb`/`bluetoothctl`. Unblock it (`rfkill unblock bluetooth`) and inspect `lsusb`, `dmesg` and `bluetoothctl list` before concluding which transport/device driver is needed.
- Card reader: the O2 Micro device shown is a USB CCID smart-card reader, not evidence of an SD/MMC reader. No SD/MMC controller was shown.
- GPU Mesa alternative: `glxinfo -B` on Debian 12 reports `Mesa Intel(R) 965GM (CL)`, OpenGL 2.1, `Accelerated: yes`, Mesa 22.3.6. Preserve this as a known-good baseline when testing the current Gentoo Mesa/Crocus configuration.

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
