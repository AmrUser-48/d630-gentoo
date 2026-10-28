# D630 Tiny Linux — standalone initramfs prototype

This is a separate experiment using the already-published D630 Linux 6.18.56 kernel. It does not rebuild the kernel and does not modify the existing /d630-gentoo/ boot files.

## What is inside

- The exact existing kernel binary from release d630-kernel-6.18.56-run-39509781896.
- An external initramfs containing statically linked BusyBox, a tiny /init, minimal /dev, /proc, /sys, /run and /tmp setup, Intel 3945ABG Wi-Fi firmware and firmware license notices.
- The existing early Intel microcode CPIO archive, prepended unchanged.
- The main filesystem archive is Zstandard-compressed at level 3. The kernel itself keeps its already-built compression format; rebuilding the kernel is intentionally out of scope.

The first milestone is a real interactive shell booting with only the kernel and initramfs. This prototype does not yet contain Xorg/Openbox or a package manager. It is a foundation for the graphical version, not the finished cute desktop.

## Build and verification

GitHub Actions downloads the pinned kernel/firmware release, checks asset SHA-256 values and required kernel options, builds the initramfs, validates its CPIO contents and symlinks, then boots the actual kernel plus the actual generated initramfs in QEMU. The build release is published only after the QEMU serial-console test reaches a shell and successfully executes a command.

## Install without replacing Gentoo

1. Download kernel, initramfs, and d630-tiny.cfg from the build release.
2. Copy the two binary assets into a new /d630-tiny/ directory on a GRUB-readable partition. Leave /d630-gentoo/ untouched.
3. Add the contents of d630-tiny.cfg to /etc/grub.d/40_custom, then regenerate GRUB's config.
4. Boot D630 Tiny Linux (standalone shell). It is volatile: edits disappear on reboot.

The current Gentoo initramfs and kernel remain available as the fallback. Successful QEMU boot does not by itself prove boot on the physical D630.
