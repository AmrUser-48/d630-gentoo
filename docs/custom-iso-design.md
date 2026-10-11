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

## Chosen first image: minimal kernel-embedded initramfs

GRUB should load a **single kernel file**. Embed a small initramfs in that kernel, but do not copy the full main system into it. The initramfs is early userspace, not a second copy of the rescue distribution.

1. Build the full Gentoo runtime root in CI. Install Bash, its maintained startup configuration, GNU coreutils/findutils/grep/sed/gawk, `less`, `file`, `lf`, mount tools, filesystem utilities, network tools and the desktop into that root.
2. Create a separate, minimal initramfs staging tree. Include an executable `/init`, a tiny shell/toolbox (prefer statically linked BusyBox), the mount/device setup needed before root handoff, and only other tools needed before the full root is available.
3. Include `wrmsr` from the Gentoo msr-tools package in the initramfs if the early CPU-throttling workaround is retained. Ensure `CONFIG_X86_MSR=y`, device-node creation and any required libraries are available. Do not guess the MSR register, bit mask or value: put the verified D630-specific write in a separately documented/configurable hook and keep it disabled until validated. An incorrect MSR write can alter CPU/platform behavior or hang the machine.
4. Make `/init` mount devtmpfs, procfs and sysfs, wait only as needed for the MSR device and target CPU to be available, run the configured hook at the earliest safe point after kernel CPU initialization, then discover/mount the main root and switch to it. On failure, show the error and drop to a minimal emergency shell. Do not make root mounting depend on a separate initramfs file or module directory.
5. Keep full Bash/GNU/lf and their configurations in the main Gentoo root. The initramfs needs only its tiny emergency shell, not duplicate copies of the complete userland. A dynamically linked `wrmsr` also needs its loader/libraries; prefer a tested static build if available, otherwise include its exact runtime dependency closure.
6. Build storage and filesystem drivers into the kernel: ext4, Btrfs, NTFS3, FAT/VFAT, partition-table parsing, AHCI/ATA/ATAPI, SCSI disk and USB storage. No external `/lib/modules/<kernel-release>` directory should be needed.
7. Set `CONFIG_BLK_DEV_INITRD=y` and point `CONFIG_INITRAMFS_SOURCE` at the minimal tree or generated cpio archive. Verify the archive is embedded in the kernel and GRUB needs no `initrd` command.
8. Test in a VM and on the D630. Verify the early hook is not run unless configured, then test the exact validated MSR write on the physical D630 with a recovery path. Test mounting disposable ext4, Btrfs, NTFS3 and FAT volumes read-only first; test writes only on disposable volumes.

### Early MSR hook timing and safety

`wrmsr` is a userspace program; the kernel must first initialize the CPU and expose `/dev/cpu/<N>/msr` via `CONFIG_X86_MSR=y` and device-node setup. It can then run from early `/init`, before the main root is mounted. This is earlier than a normal system service, but it is not before the kernel initializes the CPU. The exact register and bit changes must come from a verified D630-specific procedure; do not hard-code a guessed value into the image. Log success/failure and continue safely if the hook is disabled or fails.

The embedded archive increases kernel size, but remains much smaller than duplicating the whole Gentoo userland. Ensure any dynamically linked early binaries have their loader and shared libraries inside the archive.

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
