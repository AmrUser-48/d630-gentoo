# D630 Gentoo agent rules

Follow the repository-root [AGENTS.md](../AGENTS.md).

## Scope

This directory implements the Gentoo/OpenRC live OS: runtime package sets, external early userspace, SquashFS builders, GRUB entries and optional ISO packaging.

## Runtime invariants

- The preferred tested path is direct GRUB loading of `/d630-gentoo/kernel`, `initramfs` and `squashfs` from an ordinary partition.
- SquashFS is read-only; the current OverlayFS upper layer is volatile RAM.
- Preserve restored build roots and binary-package caches. Runtime pruning must operate on a staging copy.
- ISO is an active optional packaging/distribution target, not obsolete. ISO-specific `d630.iso_*` early userspace and end-to-end boot/persistence testing remain incomplete.
- Writable `gentoo-data.img` belongs beside the ISO on writable host storage, never inside the ISO.

## Build and validation

Read the workflow and builder before modifying behavior. Verify the actual SquashFS, manifest and checksums, then test QEMU startup. Do not equate console boot with Xorg/Openbox or physical D630 testing.
