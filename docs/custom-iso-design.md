# Custom ISO build design

This document records the first ISO strategy for the D630. It is a project plan, not evidence that an ISO has already been built or boot-tested.

## References and the Handbook's scope

- [Gentoo x86 Handbook — Installation](https://wiki.gentoo.org/wiki/Handbook:X86/Full/Installation): explains official Gentoo installation media, stage3, kernel configuration, bootloader setup, networking and package installation. It is a system-installation handbook, not a complete recipe for building a custom live ISO.
- [Gentoo downloads and official installation media](https://www.gentoo.org/downloads/): use as a reference for official media and boot layouts.
- [Linux kernel.org](https://www.kernel.org/): kernel source and stable/LTS release status.

Do not assume the official Gentoo Handbook provides a ready-made custom-ISO command sequence. We need to own and test the ISO layout, bootloader configuration, root mount and writable runtime paths.

## Kernel baseline

Use a pinned **Linux 6.18.y LTS** stable point release for the first hardware build; keep 6.12.y LTS as a fallback if testing exposes a regression. The kernel.org page checked on 2026-10-11 listed 6.18.55 as longterm. This is a version recommendation, not a hardware test result.

Compile for Core 2 (-march=core2 -mtune=core2, kernel CONFIG_MCORE2=y). Build required D630 drivers into the kernel and install no .ko files in the final image. Include Intel 3945 firmware and the regulatory database in the ISO: built-in driver code does not itself contain firmware. Enable CONFIG_X86_MSR=y.

Required built-in functionality includes the selected boot-device path, block layer, SATA/AHCI and ATAPI, USB host controller and USB storage, ISO9660, devtmpfs, tmpfs, procfs, sysfs, ext4/VFAT/NTFS3/Btrfs, i915, the iwl3945 stack, HDA codec path, USB HID, and USB RNDIS host networking. Verify exact Kconfig symbols against the pinned source with scripts/config, olddefconfig, and a final .config audit.

## Chosen first image: kernel-embedded initramfs

The requirement is that GRUB can load a **single kernel image** and the machine reaches a practical rescue shell without needing a separate initramfs, root partition, or kernel-module directory. The correct design is to build an initramfs archive into the kernel itself. This is still an initramfs mechanism; it is simply embedded rather than supplied as a second GRUB-loaded file.

1. Build a dedicated initramfs staging tree in CI. Keep Portage, compilers, development headers, source trees and package caches outside it.
2. Include an executable `/init` as PID 1. It mounts devtmpfs, procfs and sysfs, initializes device discovery and console setup, prints a clear banner, and starts an interactive Bash rescue shell with a sensible PATH and usable terminal settings.
3. Include **Bash as the primary shell**, with maintained `/etc/profile`, the Gentoo-appropriate global Bash rc file, `/root/.bashrc`, `/root/.profile`, and `/etc/inputrc`. Configure a useful prompt, sane history behavior, completion if packaged, aliases, safe defaults and readable error handling. A bare BusyBox-only shell is not the target.
4. Include GNU coreutils, findutils, grep, sed and gawk, plus `lf` as a terminal file manager with a real configuration and sensible preview/opening behavior. Include `less`, `file`, `util-linux` mount tools and the filesystem utilities needed for rescue. BusyBox may supplement missing applets but must not replace the requested Bash/GNU environment.
5. Build storage and filesystem drivers into the kernel. Include ext4, Btrfs, NTFS3, FAT/VFAT, partition-table parsing, AHCI/ATA/ATAPI, SCSI disk and USB storage as built-in options. No `/lib/modules/<kernel-release>` directory is required for the boot/mount path.
6. Set `CONFIG_BLK_DEV_INITRD=y` and point `CONFIG_INITRAMFS_SOURCE` at the staged tree or generated cpio archive. Verify that the final kernel contains the expected `/init` and utilities; do not rely on a separate initrd file in GRUB.
7. Assemble a legacy-BIOS ISO with GRUB and the self-contained kernel. The embedded rescue shell must work independently of any additional files or full desktop root on the ISO.
8. Test in a VM and on the D630. From the embedded shell, identify partitions and mount disposable ext4, Btrfs, NTFS3 and FAT test volumes read-only first; test writes only on disposable volumes. Verify GRUB loads only the kernel, with no separate initramfs and no `root=` partition supplied.

This keeps the first rescue environment self-contained while leaving room for a richer ISO. The embedded initramfs increases the kernel file size; its dynamically linked programs need their loader and shared libraries inside the archive. Built-in Wi-Fi drivers still need firmware files, which must also be embedded if Wi-Fi should work before mounting an external filesystem.

### Why an embedded initramfs is required

Without an initramfs or an embedded initramfs, Linux does not automatically start a shell when root mounting fails; it normally panics. For the requested “load only the kernel file and get a shell” behavior, the embedded archive needs a working `/init`, its interpreter and libraries, and the rescue tools—not just shell binaries.

## Required network functions

- Wi-Fi: built-in Intel 3945ABG driver stack and firmware.
- Android USB tethering: built-in USB host, usbnet, RNDIS host and CDC Ethernet support as available in the pinned kernel.
- ADB/fastboot: userspace tools plus USB access and permissions; this is separate from RNDIS tethering.
- Wired Ethernet drivers are intentionally excluded.

## Incremental implementation plan

1. Pin the stage3 archive, Gentoo profile/repository snapshot, kernel point release and build tools.
2. Build a runtime root directory and verify package resolution without adding build tools to that root.
3. Build and audit the Core 2 kernel configuration; confirm all required drivers are built in and no module files are needed.
4. Assemble a direct-root ISO with GRUB BIOS boot support and a documented kernel command line.
5. Run static ISO checks and a VM boot smoke test; then boot on the physical D630 and test storage, graphics, Wi-Fi, RNDIS, MSR access, audio, Bluetooth if the adapter can be identified, and filesystem operations.
6. Only after a working baseline exists, remove further packages or kernel options and compare image size and boot logs.

## Build artifacts and claims

CI should publish the ISO, kernel config, build manifest, package list, checksums and logs. It should report the exact kernel version, profile/stage3 identifier, ISO size and test status. Never describe a VM test as a physical D630 test, or a successful compile as a successful boot.
