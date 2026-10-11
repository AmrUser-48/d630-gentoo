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

## Chosen first image: no external initramfs

The current preference is to avoid both an external initramfs and runtime kernel modules from disk. The most direct design to test is:

1. Build a complete, minimal Gentoo runtime root tree in CI. Keep Portage, compilers, development headers, source trees and caches outside the runtime tree.
2. Install only runtime packages and required firmware into the runtime tree. Do not install a /lib/modules/<kernel-release>/ tree for the first image; ensure every needed driver is built in.
3. Place the complete runtime tree directly on an ISO9660 filesystem. Do not put it inside a separate SquashFS file for this no-initramfs variant.
4. Build a legacy-BIOS El Torito ISO with GRUB and the kernel. The GRUB menu must pass the correct root device and rootfstype=iso9660 options; prove the exact device path for optical boot and for the intended hybrid-USB boot method.
5. Use a read-only ISO9660 root. Mount /run and /tmp as tmpfs through normal init/service setup; identify and handle other runtime paths that need writes. A read-only root is a deliberate initial limitation, not a persistent writable desktop.
6. Validate the image in a VM, inspect the ISO with xorriso/isoinfo, and boot it on the D630 from optical media and USB before further pruning.

The kernel can mount ISO9660 as root without an initramfs only if it can already access the root device: the required storage controller, block/ATAPI/USB path and ISO9660 support must be built in. A hybrid ISO written to USB may expose a different device layout than an optical disc, so test it rather than assuming.

### Important incompatibility

A conventional **SquashFS + RAM-backed OverlayFS live root requires early userspace** to locate the SquashFS image and assemble the overlay. That early userspace is normally provided by an initramfs. Embedding an initramfs in the kernel still uses the initramfs mechanism; it only removes the separate initramfs file.

Therefore, do not combine all three requirements—no initramfs, SquashFS root, and RAM OverlayFS—without implementing and testing an alternative early-root mechanism. For the first build, prioritize the no-external-initramfs requirement and use a direct ISO9660 root. If compression and OverlayFS later become more important than eliminating early userspace, change the design deliberately.

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
