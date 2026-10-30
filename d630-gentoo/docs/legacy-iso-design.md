# Legacy ISO design note — not the current boot path

This file preserves the earlier proposal for a Super Grub2 Disk loopback ISO with a kernel-embedded initramfs and persistent gentoo-data.img.

This ISO design is not the current supported or validated product. The current design is the separate three-file Gentoo live boot documented in ../README.md: external kernel, external initramfs and SquashFS with volatile RAM OverlayFS. Do not use this document as a current build recipe, and do not assume persistent overlay or ISO assembly is implemented.

The old GRUB loopback template and create-persistence-image.sh helper are retained under boot/iso/ for historical reference. The helper creates a sparse ext4 gentoo-data.img for that obsolete ISO design; it does not add persistence to the current three-file SFS live boot. A persistent installed Gentoo target and a bootable legacy-BIOS ISO remain separate future projects and require their own end-to-end validation.
