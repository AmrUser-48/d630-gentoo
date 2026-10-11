# Kernel requirements and confirmed D630 hardware notes

This is a focused design checklist, not a finished `.config`. Hardware IDs below come from the user's Debian 12 `lspci -nnk`, `lsusb`, ALSA and `glxinfo -B` output. Use `docs/hardware-inventory.md` as the full inventory.

## Confirmed CPU and board

- Dell Latitude D630, board `0KU184`, Dell BIOS A19.
- Intel Core 2 Duo T7250, x86_64, 2 cores; current tested kernel reports `CONFIG_MCORE2=y`.
- Host bridge Intel PM965/GM965/GL960 `8086:2a00`; ICH8M LPC `8086:2815`.
- Compile for Core 2 (`-march=core2 -mtune=core2`); never `-march=native` in CI.

## Live boot: design before stripping

The first target is a legacy-BIOS live ISO with SquashFS plus a RAM-backed OverlayFS writable layer. That boot design normally needs an early userspace stage to locate the live medium, load modules if necessary, mount SquashFS and OverlayFS, and switch to the final root.

- Keep initramfs support in the kernel and start with a small, auditable initramfs. A separate initramfs file can be avoided only if the live-root discovery/mounting logic is built into the kernel (for example, a built-in initramfs via `CONFIG_INITRAMFS_SOURCE`) or the boot design is changed to a directly mountable block root. That is not the same as removing early userspace from the current ISO/SquashFS/OverlayFS plan.
- Do not optimize away initramfs until the exact ISO boot flow works. An initramfs is usually the simplest reliable solution for a live ISO; its size should be minimized after functionality is proven.
- Kernel must support `devtmpfs`, procfs, sysfs, tmpfs, loop devices, SquashFS and OverlayFS.
- Build boot-critical storage and root filesystem support in (`=y`) where possible, or ensure the needed modules and dependencies are inside the initramfs. A module stored only inside the not-yet-mounted SquashFS root cannot load itself to mount that root.
- Legacy BIOS boot only; no UEFI-only dependencies.

## Confirmed devices and driver priorities

- **GPU:** Intel GM965/GMA X3100, primary PCI `8086:2a02`, secondary display function `8086:2a03`, Dell subsystem `1028:01f9`. `i915` currently works as a module (`CONFIG_DRM_I915=m`); dmesg confirms `i915drmfb` framebuffer. Debian Mesa 22.3.6 gives `Mesa Intel(R) 965GM (CL)`, accelerated=yes, OpenGL 2.1. Do not force i915 built-in just for its own sake; include it in initramfs only if early display is needed. Retain DRM/KMS and a framebuffer console.
- **Wi-Fi:** Intel PRO/Wireless 3945ABG `8086:4222`, subsystem `8086:1021`; `iwl3945` module works and firmware `iwlwifi-3945-2.ucode` version `15.32.2.9` loads. Include matching firmware and regulatory database.
- **Audio:** HDA controller `8086:284b`, IDT/SigmaTel STAC9205 codec `8384:76a0`, subsystem `1028:01f9`. Keep HDA core and the IDT/Sigmatel codec path, not all sound drivers.
- **USB:** ICH8 UHCI `8086:2830`, `2831`, `2832`, `2834`, `2835`; EHCI `8086:2836`, `283a`. Keep `uhci_hcd`, `ehci-pci`, USB core, USB HID, USB storage and required USB networking.
- **Storage:** SATA AHCI `8086:2829` (`ahci`); IDE/ATAPI `8086:2850` (`ata_piix`). Keep AHCI/libata/SCSI disk and ATAPI support for the optical drive; preserve USB mass storage.
- **Input:** i8042/serio AT keyboard, AlpsPS/2 DualPoint stick and touchpad; USB mouse ID `0000:3821`. Keep `i8042`, `atkbd`, `psmouse`, evdev/libinput and USB HID.
- **Smart card:** O2 Micro USB hub `0b97:7761` and CCID reader `0b97:7772`; smart-card userspace is optional, USB support is not.
- **Android:** current Huawei phone `12d1:107d` appears in MTP mode. ADB/fastboot and RNDIS need their respective userspace tools/kernel options and separate verification.
- **Bluetooth:** Dell rfkill platform exposes `dell-bluetooth`, but Bluetooth was software-blocked and no adapter appeared in `lsusb` or `bluetoothctl`. Keep core support as a requirement, but identify the actual adapter/transport before choosing device-specific drivers.
- **Wired Ethernet:** no Ethernet PCI function appeared in the supplied `lspci -nnk` output. Investigate BIOS configuration or collect a fresh complete listing before selecting a driver.
- **Filesystem support:** ext4 for the current system; NTFS and Btrfs are explicit rescue requirements; also retain VFAT and ISO9660. `CONFIG_BTRFS_FS=y` and `CONFIG_NTFS3_FS=y` are present in the current kernel.
- **ZRAM:** current kernel has `CONFIG_ZRAM=y` and the running system has a 1.5 GiB `zram0`. Select compressors supported by the final kernel config; don't assume all algorithms are built in.
- **ACPI/power:** keep ACPI, thermal, battery, laptop hotkeys and fan/platform support. Validate temperature reporting and suspend/resume.

## Kernel build strategy

- Start from a known-good x86_64 configuration and run `make olddefconfig` against the exact kernel source version.
- Use `CONFIG_MCORE2=y` / Core 2 CPU tuning where the selected kernel exposes it.
- Prefer built-in (`=y`) for boot-critical storage, root filesystem, devtmpfs and the minimal required boot path. Use modules for optional runtime hardware when their `.ko` files and dependencies are guaranteed to be present before use.
- For the first ISO, don't optimize solely for the smallest kernel binary. Keep only needed drivers but ensure the initramfs contains every module needed before the SquashFS root mounts.
- Keep `i915`, `iwl3945`, HDA, USB, AHCI, NTFS, Btrfs and other confirmed features until end-to-end tests prove the image can safely omit them.
- Avoid unrelated DVB, AMD and NVIDIA driver families unless future hardware inventory justifies them.
- Inspect `.config`, the module dependency tree, firmware requests and boot logs. Test the ISO before each further pruning pass.

## Firmware and graphics tests

- Required Wi-Fi firmware confirmed by dmesg: `iwlwifi-3945-2.ucode`; regulatory database files also load.
- No evidence of a required modern Intel GuC/HuC/DMC firmware on the X3100.
- For Mesa, preserve a known-good baseline: Debian Mesa 22.3.6 reports `Mesa Intel(R) 965GM (CL)`, `Accelerated: yes`, OpenGL 2.1. Validate Gentoo Mesa/Crocus on hardware and compare `glxinfo -B`; don't replace the classic driver until the alternative passes.
- Run `lspci -nnk`, `dmesg`, `glxinfo -B`, Wi-Fi connection tests, sound playback/capture, USB storage tests, and mount/read tests for the supported filesystems.

## Image-size and reliability rules

- No Portage, compiler, headers, source trees or build cache in the final runtime root.
- Strip unrelated modules only after checking dependencies and the resulting kernel config.
- Keep firmware only when needed for selected devices and verify redistribution terms.
- Document measured kernel/module/initramfs/rootfs sizes; do not guess or promise size targets before a build.
