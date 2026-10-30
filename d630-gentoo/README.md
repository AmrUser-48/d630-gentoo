# D630 Gentoo live OS

This directory contains the Gentoo/OpenRC live operating system. It is separate from D630 Tiny, which is a BusyBox-only initramfs with no Gentoo root.

## Boot layout

Copy the matching three artifacts to one GRUB-readable partition:

    /d630-gentoo/
    ├── kernel
    ├── initramfs
    └── squashfs

Use the three-file GRUB entry in boot/grub/three-file.cfg. The kernel and external initramfs start early userspace; initramfs/init searches supported partitions for /d630-gentoo/squashfs, mounts the SquashFS read-only and creates a RAM-backed OverlayFS root before switching to Gentoo/OpenRC.

Persistence: the current direct-folder live mode uses a temporary RAM upper layer. System changes and home-directory changes disappear at reboot. The optional ISO design supports a separate writable ext4 persistence-image concept; its ISO-specific early userspace and end-to-end workflow still need implementation and testing.

## Runtime profiles

The runtime builder supports small console and larger graphical profiles, including Openbox. The current Openbox runtime uses Gentoo/OpenRC, Xorg, Mesa Crocus for GM965, Openbox and CLI tools. The compressed SquashFS target is at most 300 MiB.

## Current published image

Release: [d630-gentoo-openbox-2026.10.29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29).

The release notes report a 198.43 MiB SquashFS, below the 300 MiB target. The three-file root was boot-tested in QEMU through initramfs discovery, SquashFS mount, OverlayFS and OpenRC console startup. This does not establish that Xorg/Openbox starts correctly, that Crocus accelerates the virtual display, or that the image has booted successfully on the physical D630.

## Kernel

Use kernel profile 40, built-in D630 live/SFS. Its loop, SquashFS-Zstd, OverlayFS and host filesystem support must be built in because the external initramfs cannot load modules from the not-yet-mounted root partition. Profile 20 is for normal modular Gentoo; profile 30 is for D630 Tiny.

## Build and validate

From repository root, runtime package sets are in config/package-sets/, early userspace in initramfs/init, runtime builder in scripts/build-runtime-squashfs.sh, shared Portage configuration in ../config/portage/, and the boot recipe in boot/grub/three-file.cfg.

The builder produces files in repository-root output/. Keep the original build root and /var/cache/binpkgs intact; trimming must operate on a separate runtime staging root. ISO packaging notes and GRUB loopback assets are in iso/. Prefer direct GRUB boot from /d630-gentoo/ files; ISO is an optional container/distribution format. See iso/README.md, the root README and kernel profile guide.
