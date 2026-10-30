# Legacy ISO design note — not the current boot path

This file preserves the earlier proposal for a Super Grub2 Disk loopback ISO with a kernel-embedded initramfs and persistent gentoo-data.img.

This ISO design is not the current supported or validated product. The current design is the separate three-file Gentoo live boot documented in ../README.md: external kernel, external initramfs and SquashFS with volatile RAM OverlayFS. Do not use this document as a current build recipe, and do not assume persistent overlay or ISO assembly is implemented.

The old GRUB loopback template is retained under boot/iso/ for historical reference. A persistent installed Gentoo target and a bootable legacy-BIOS ISO remain separate future projects and require their own end-to-end validation.
