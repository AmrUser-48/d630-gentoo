# D630 Gentoo ISO packaging

The ISO remains a supported **distribution and packaging target**. The project preference is simply to boot from ordinary files on a GRUB-readable partition rather than selecting an ISO as the boot medium.

## Two ways to use the same Gentoo runtime

1. **Preferred: direct GRUB boot.** Copy `kernel`, `initramfs` and `squashfs` to `/d630-gentoo/` on an existing partition. Use `../boot/grub/three-file.cfg`. This is the current implemented and QEMU-tested path.
2. **Optional: ISO container.** Package the kernel/early-userspace payload and the same Gentoo SquashFS into a legacy-BIOS ISO. Keep the GRUB loopback menu at `boot/grub/loopback.cfg` inside the ISO. The ISO can be stored or mounted as a container; it does not have to be selected as the machine's boot device. The same payload can also be extracted to an ordinary partition and booted there.

The intended ISO layout is:

    /boot/vmlinuz-d630-gentoo
    /boot/grub/loopback.cfg
    /LiveOS/rootfs.squashfs

The loopback menu supports persistent and volatile modes. The writable ext4 `gentoo-data.img` is kept **beside the ISO on a writable host filesystem**, not inside the read-only ISO. The helper in `scripts/create-persistence-image.sh` creates that sparse image and refuses to overwrite an existing one.

## Implementation status

The ISO-specific GRUB menu and persistence-image helper are kept here as active design assets. The current external-initramfs `d630-gentoo` boot path does not yet implement the separate `d630.iso_*` command-line contract expected by this menu, and the repository does not yet contain a complete ISO assembly + end-to-end boot/persistence test workflow. Do not confuse the ISO design assets with a verified ISO release.

The next ISO implementation step is to add and test an ISO-specific early userspace that handles `d630.iso_uuid`, `d630.iso_path`, `d630.persistence`, `d630.datafile` and `d630.rootfs`, then assemble and test the ISO and persistence image. This must remain separate from the working direct-folder initramfs so neither boot method regresses.
