# Kernel requirements and confirmed D630 hardware notes

This is a focused design checklist, not a finished `.config`. Hardware IDs below come from the user's Debian 12 `lspci -nnk`, `lsusb`, ALSA and `glxinfo -B` output. See `docs/hardware-inventory.md` for the full inventory.

## Kernel version recommendation

**Start with Linux 6.18.y LTS**, currently the newest long-term-support line in the kernel.org listing checked on 2026-10-11. Pin a specific stable point release in CI rather than building a moving branch. Keep **6.12.y LTS as a fallback comparison** if a regression appears. Do not choose 7.2 just because it is newer: the target needs stable legacy Intel graphics, iwl3945, HDA, USB, and storage support more than newest features. The current Debian kernel already proves that the core hardware works; run the same device tests against the chosen 6.18 point release before declaring it good.

Sources:
- Kernel.org release status: https://www.kernel.org/
- Kernel release tarball directory: https://cdn.kernel.org/pub/linux/kernel/v6.x/

This is a reasoned starting choice, not a claim that 6.18 has been tested on this laptop yet.

## Confirmed CPU and board

- Dell Latitude D630, board `0KU184`, Dell BIOS A19.
- Intel Core 2 Duo T7250, x86_64, 2 cores; current tested kernel reports `CONFIG_MCORE2=y`.
- Host bridge Intel PM965/GM965/GL960 `8086:2a00`; ICH8M LPC `8086:2815`.
- Compile for Core 2 (`-march=core2 -mtune=core2`); never `-march=native` in CI.

## Boot architecture: minimal embedded initramfs, no external initramfs file

GRUB must load only the kernel image; the kernel embeds a small initramfs to run early userspace. Do **not** duplicate the full Gentoo shell environment in the embedded archive.

- Set `CONFIG_BLK_DEV_INITRD=y` and `CONFIG_INITRAMFS_SOURCE` to the generated minimal cpio archive or staging tree. Verify the archive is embedded; the GRUB entry must not need an `initrd` command.
- Include an executable `/init` and a tiny shell/toolbox, preferably statically linked BusyBox. It mounts devtmpfs, procfs and sysfs, initializes the console, runs configured early tasks, locates/mounts the main root, and hands off with `switch_root` or equivalent. If root handoff fails, show the error and provide an emergency shell.
- The **main Gentoo root** (package candidates in `config/package.list`) contains Bash and its startup files, GNU coreutils/findutils/grep/sed/gawk, `less`, `file`, `lf` and its configuration, mount tools and filesystem-specific utilities. The separate `config/initramfs-package.list` contains only early-boot packages; do not duplicate the full userland there.
- Include `wrmsr` from msr-tools in the initramfs only if needed for the early CPU-throttling workaround. Ensure `CONFIG_X86_MSR=y`, device-node setup, and the binary's runtime dependencies (or a tested static build).
- Make the early MSR hook explicit and configurable. It can run after kernel CPU initialization and after `/dev/cpu/<N>/msr` becomes accessible, before main-root handoff. Do not guess the MSR number, mask or value; a wrong write may destabilize or hang the laptop. Keep it disabled by default until the exact D630-specific operation has been verified and tested with a recovery path.
- Build all needed storage/filesystem drivers into the kernel: block layer, SATA/AHCI, IDE/ATAPI, SCSI disk, USB host and mass storage, partition parsing, ext4, Btrfs, NTFS3 and FAT/VFAT.
- No `/lib/modules/<kernel-release>` tree is needed for the boot and mount path. Firmware needed before the main root is mounted must be embedded in the initramfs or otherwise made available to the built-in driver; Wi-Fi firmware is separate from driver code.
- Test GRUB loading only the kernel, without external initramfs or a preexisting root partition argument. Verify the early init executes, the main root handoff succeeds, and the emergency shell works when the main root is intentionally unavailable.
- Test reads from disposable ext4, Btrfs, NTFS3 and FAT volumes before testing writes.

## Confirmed devices and driver priorities

All required hardware drivers should be built into the kernel (`=y`) for the intended final configuration, not shipped as loadable modules. Firmware files are separate from kernel modules and may still need to live under `/lib/firmware`.

- **CPU/MSR:** `CONFIG_MCORE2=y`; enable `CONFIG_X86_MSR=y` for `/dev/cpu/*/msr`. Ensure `msr` userspace tooling is included only if needed.
- **GPU:** Intel GM965/GMA X3100, primary PCI `8086:2a02`, secondary display function `8086:2a03`, Dell subsystem `1028:01f9`. Set `CONFIG_DRM=y`, `CONFIG_DRM_I915=y`, and required DRM/GEM/TTM/framebuffer/console dependencies built in. Debian's current `i915` module works and dmesg confirms `i915drmfb`; Mesa 22.3.6 reports `Mesa Intel(R) 965GM (CL)`, accelerated=yes, OpenGL 2.1. No required GuC/HuC/DMC firmware is known for this X3100.
- **Wi-Fi:** Intel PRO/Wireless 3945ABG `8086:4222`, subsystem `8086:1021`. Build `iwl3945`, `iwlwifi`, `mac80211`, `cfg80211` and required RF-kill support in. Firmware `iwlwifi-3945-2.ucode` version `15.32.2.9` was confirmed to load. Include that firmware and the regulatory database in the runtime ISO; built-in driver code does not embed the firmware automatically.
- **USB Android RNDIS tethering:** build USB host support plus `CONFIG_USB_USBNET=y`, `CONFIG_USB_NET_RNDIS_HOST=y`, and `CONFIG_USB_NET_CDCETHER=y` where offered by the selected kernel version. Include USB networking dependencies and test with the actual Android phone in tethering mode. This is **USB host/RNDIS networking**, not USB gadget mode.
- **Android ADB/fastboot:** kernel USB support alone is insufficient; include and test the userspace ADB/fastboot tools and udev/device permissions. The supplied Huawei device was observed in MTP mode (`12d1:107d`), so verify its actual ADB and tethering modes separately.
- **Audio:** HDA controller `8086:284b`, IDT/SigmaTel STAC9205 codec `8384:76a0`, subsystem `1028:01f9`. Build HDA core and the IDT/Sigmatel codec path in; do not enable every sound driver.
- **USB controllers:** ICH8 UHCI `8086:2830`, `2831`, `2832`, `2834`, `2835`; EHCI `8086:2836`, `283a`. Build `uhci_hcd`, `ehci-pci`, USB core, USB HID, USB storage and required USB networking in.
- **Storage:** SATA AHCI `8086:2829` (`ahci`); IDE/ATAPI `8086:2850` (`ata_piix`). Build AHCI/libata/SCSI disk and ATAPI support in; preserve USB mass storage.
- **Input:** i8042/serio AT keyboard, AlpsPS/2 DualPoint stick and touchpad; USB mouse ID `0000:3821`. Build `i8042`, `atkbd`, `psmouse`, evdev/libinput and USB HID support in.
- **Filesystem support:** ext4 for the current system; NTFS and Btrfs are explicit rescue requirements; also retain VFAT and ISO9660. `CONFIG_BTRFS_FS=y` and `CONFIG_NTFS3_FS=y` are present in the current kernel. Include `ntfs3` kernel support; `ntfs3g` userspace is optional for the kernel NTFS3 path.
- **ZRAM:** current kernel has `CONFIG_ZRAM=y` and the running system has a 1.5 GiB `zram0`. Choose supported compressors based on the final kernel config; don't assume every algorithm is built in.
- **ACPI/power:** keep ACPI, thermal, battery, laptop hotkeys and fan/platform support. Validate temperature reporting and suspend/resume.
- **Wired Ethernet:** intentionally **omit wired Ethernet drivers** from the target config. Wi-Fi and Android USB RNDIS are required. Do not spend space on a wired Ethernet driver unless the scope changes.
- **Bluetooth:** retain core support only if still required, but the actual adapter/transport remains unconfirmed: Dell rfkill platform exists, Bluetooth was software-blocked, and no adapter appeared in the supplied `lsusb` output. Keep the core requirement; defer adapter-specific pruning until identified.
- **Smart card:** O2 Micro USB hub `0b97:7761` and CCID reader `0b97:7772`; USB support is required; CCID userspace is optional.

## Kernel build strategy

- Start from a known-good x86_64 configuration and run `make olddefconfig` against the exact pinned kernel source version.
- Set Core 2 CPU tuning and `CONFIG_X86_MSR=y`.
- Build all required hardware drivers into the kernel and install no runtime `.ko` files. Start with `CONFIG_MODULES=y` for diagnostics; consider disabling module support only after successful end-to-end testing.
- Prefer built-in support for the complete boot/root path: storage, USB host controller, ISO9660, devtmpfs, and any other option needed before userspace can run.
- Keep `i915`, `iwl3945`, HDA, USB, AHCI, NTFS, Btrfs and other confirmed features until end-to-end tests prove the image can safely omit them.
- Avoid unrelated DVB, AMD and NVIDIA driver families. **Do not add Ethernet drivers.**
- Inspect the final `.config`, `vmlinux`/kernel size, firmware requests and boot logs. Test the ISO before each further pruning pass.

## Firmware and graphics tests

- Required Wi-Fi firmware confirmed by dmesg: `iwlwifi-3945-2.ucode`; include regulatory database files.
- Keep the known-good graphics comparison: Debian Mesa 22.3.6 reports `Mesa Intel(R) 965GM (CL)`, accelerated rendering, OpenGL 2.1. Validate Gentoo Mesa on the actual D630 and compare `glxinfo -B`.
- Run `lspci -nnk`, `dmesg`, `glxinfo -B`, Wi-Fi connection tests, Android USB RNDIS tethering, ADB/fastboot tests, sound playback/capture, USB storage tests, and read/write tests for the supported filesystems.

## Image-size and reliability rules

- No Portage, compiler, headers, source trees or build cache in the final runtime root.
- No external initramfs file in the target design; embed the cpio initramfs in the kernel and test that GRUB can load the kernel alone.
- No runtime kernel modules installed in the final image. Firmware is still included where hardware requires it.
- Strip unrelated drivers only after checking dependencies and the resulting kernel config.
- Document measured kernel and ISO sizes; do not guess or promise size targets before a build.
