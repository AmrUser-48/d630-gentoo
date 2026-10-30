# Historical ISO proposal — archived

This file preserves an early ISO/loopback proposal from the initial project layout. It is not a current build recipe.

The active ISO packaging target is documented in [the current ISO guide](../../d630-gentoo/iso/README.md). The ISO remains an optional distribution/container format; the preferred boot method is still GRUB loading ordinary kernel, initramfs and SquashFS files from a normal partition.

Old paths, embedded-initramfs assumptions and persistence statements below this point are historical. Do not use them to modify the working direct-folder initramfs. ISO-specific early userspace and end-to-end persistence testing remain unfinished.
