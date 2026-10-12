# D630 daily-use Gentoo system and ISO design

The primary product is a small, persistent Gentoo system for everyday use on the D630. The legacy-BIOS ISO is a live test/installation/recovery environment, not the only deliverable. This is a project plan, not evidence that the system has already been built or boot-tested.

## References and the Handbook's scope

- [Gentoo x86 Handbook — Installation](https://wiki.gentoo.org/wiki/Handbook:X86/Full/Installation): explains official Gentoo installation media, stage3, kernel configuration, bootloader setup, networking and package installation. It is a system-installation handbook, not a complete recipe for building a custom live ISO.
- [Gentoo downloads and official installation media](https://www.gentoo.org/downloads/): use as a reference for official media and boot layouts.
- [Linux kernel.org](https://www.kernel.org/): kernel source and stable/LTS release status.

Do not assume the official Gentoo Handbook provides a ready-made custom-ISO command sequence. We need to own and test the ISO layout, bootloader configuration, root mount and writable runtime paths.

## Kernel baseline

Use a pinned **Linux 6.18.y LTS** stable point release for the first hardware build; keep 6.12.y LTS as a fallback if testing exposes a regression. The kernel.org page checked on 2026-10-11 listed 6.18.55 as longterm. This is a version recommendation, not a hardware test result.

Compile for Core 2 (-march=core2 -mtune=core2, kernel CONFIG_MCORE2=y). Build required D630 drivers into the kernel and install no .ko files in the final image. Include Intel 3945 firmware and the regulatory database in the ISO: built-in driver code does not itself contain firmware. Enable CONFIG_X86_MSR=y.

Required built-in functionality includes the selected boot-device path, block layer, SATA/AHCI and ATAPI, USB host controller and USB storage, ISO9660, devtmpfs, tmpfs, procfs, sysfs, ext4/VFAT/NTFS3/Btrfs, i915, the iwl3945 stack, HDA codec path, USB HID, and USB RNDIS host networking. Verify exact Kconfig symbols against the pinned source with scripts/config, olddefconfig, and a final .config audit.

## Boot and install architecture: minimal embedded initramfs plus persistent installed root

GRUB should load a **single kernel file**. Embed a small initramfs in that kernel, but do not copy the full main system into it. The initramfs is early userspace, not a second copy of the rescue distribution.

1. Build the full Gentoo runtime root in CI. Use `config/package.list` for a practical daily environment: Bash, GNU utilities, `less`, `file`, `lf`, graphical file manager, browser, editor/Git, audio and media tools, mount/filesystem tools, Wi-Fi/network manager and lightweight desktop.
2. Create a separate, minimal initramfs staging tree according to `config/initramfs-package.list`. Include an executable `/init`, a tiny shell/toolbox (prefer statically linked BusyBox), the mount/device setup needed before root handoff, and only tools needed before the full root is available.
3. Include `wrmsr` from the Gentoo msr-tools package in the initramfs if the early CPU-throttling workaround is retained. Ensure `CONFIG_X86_MSR=y`, device-node creation and any required libraries are available. Do not guess the MSR register, bit mask or value: put the verified D630-specific write in a separately documented/configurable hook and keep it disabled until validated. An incorrect MSR write can alter CPU/platform behavior or hang the machine.
4. Make `/init` mount devtmpfs, procfs and sysfs, wait only as needed for the MSR device and target CPU to be available, run the configured hook at the earliest safe point after kernel CPU initialization, then discover/mount the main root and switch to it. On failure, show the error and drop to a minimal emergency shell. Do not make root mounting depend on a separate initramfs file or module directory.
5. Keep full Bash/GNU/lf and their configurations in the main Gentoo root. The initramfs needs only its tiny emergency shell, not duplicate copies of the complete userland. A dynamically linked `wrmsr` also needs its loader/libraries; prefer a tested static build if available, otherwise include its exact runtime dependency closure.
6. Build storage and filesystem drivers into the kernel: ext4, Btrfs, NTFS3, FAT/VFAT, partition-table parsing, AHCI/ATA/ATAPI, SCSI disk and USB storage. No external `/lib/modules/<kernel-release>` directory should be needed.
7. Set `CONFIG_BLK_DEV_INITRD=y` and point `CONFIG_INITRAMFS_SOURCE` at the minimal tree or generated cpio archive. Verify the archive is embedded in the kernel and GRUB needs no `initrd` command.
8. Test in a VM and on the D630. Verify the early hook is not run unless configured, then test the exact validated MSR write on the physical D630 with a recovery path. Test mounting disposable ext4, Btrfs, NTFS3 and FAT volumes read-only first; test writes only on disposable volumes.

### Early MSR hook timing and safety

`wrmsr` is a userspace program; the kernel must first initialize the CPU and expose `/dev/cpu/<N>/msr` via `CONFIG_X86_MSR=y` and device-node setup. It can then run from early `/init`, before the main root is mounted. This is earlier than a normal system service, but it is not before the kernel initializes the CPU. The exact register and bit changes must come from a verified D630-specific procedure; do not hard-code a guessed value into the image. Log success/failure and continue safely if the hook is disabled or fails.

The embedded archive increases kernel size, but remains much smaller than duplicating the whole Gentoo userland. Ensure any dynamically linked early binaries have their loader and shared libraries inside the archive.

## Persistence and Super Grub2 Disk loopback

The live ISO must preserve changes by default. Use a compressed, immutable base and a writable overlay rather than trying to write into the ISO.

1. Build the daily-use Gentoo runtime root, then create `/LiveOS/rootfs.squashfs` in the ISO. SquashFS is read-only; this keeps the distribution base compact.
2. Embed the minimal `initramfs/init` into the Core 2 kernel (`CONFIG_INITRAMFS_SOURCE`); there is no separate initrd file.
3. Put `iso/boot/grub/loopback.cfg` into the ISO at exactly `/boot/grub/loopback.cfg`. Super Grub2 Disk expects this path and passes the exported `iso_path` variable. The config finds the backing filesystem UUID with GRUB's `search`/`probe` commands and passes `d630.iso_uuid` and `d630.iso_path` to the kernel.
4. Store a sparse ext4 file named `gentoo-data.img` in the **same host directory** as the ISO. Create it on the user’s existing writable disk with `scripts/create-persistence-image.sh /path/to/ISOs/gentoo-data.img 4G`. The filesystem inside the image stores `upper/` and `work/`; OverlayFS uses those directories to keep changed/new files, deletions, user settings and package changes between boots.
5. If the image is missing or cannot mount, persistent mode must stop with an explicit error. A separate “temporary RAM-only” menu entry uses tmpfs so tests never overwrite the persistent profile. The debug entry adds `d630.debug=1 loglevel=7 ignore_loglevel`.
6. The embedded `/init` needs the BusyBox `blkid`, `mount` (loop option), `switch_root` and shell applets; mount support for the host filesystem (ext4, Btrfs, NTFS3 or VFAT as built), ISO9660, SquashFS/loop and OverlayFS must be built into the kernel.
7. The persistence image is user data, not a backup. Back it up before changing the base ISO or performing upgrades. Because root changes are layered over a read-only package base, a major base-image refresh can conflict with persistent package files. For long-term daily use, also publish an installable writable ext4/Btrfs root so standard Gentoo upgrades can be performed without a live overlay.

Super Grub2 Disk documentation confirms the loopback config path and exported ISO path convention: https://www.supergrubdisk.org/wiki/Loopback.cfg. Alpine's `apkovl` is good for small configuration backups, but it does not by itself provide full root filesystem persistence; a whole-root OverlayFS image better matches the desired “boot and keep using the same desktop” behavior. See https://wiki.alpinelinux.org/wiki/Alpine_local_backup and https://wiki.alpinelinux.org/wiki/Alpine_Diskless_Mode.

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
