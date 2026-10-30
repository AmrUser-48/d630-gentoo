# D630 Tiny agent rules

Follow the repository-root [AGENTS.md](../AGENTS.md).

## Scope

This directory implements the standalone Tiny operating system: BusyBox shell, external initramfs, firmware and text-mode utilities. It is not the Gentoo live OS and must not gain a Gentoo SquashFS root or Portage dependency.

## Runtime invariants

- Tiny is an initramfs-only environment with RAM-only changes.
- Keep Tiny boot files and GRUB entry separate from `/d630-gentoo/`.
- The current release reuses a pinned kernel bundle; profile 30 is prepared but has no dedicated kernel release yet.
- QEMU's emulated USB Ethernet does not validate the physical Intel 3945ABG Wi-Fi adapter.

## Releases and tests

Use matching `kernel`, `initramfs` and `SHA256SUMS` assets from a verified Tiny release. Do not infer physical-hardware support from QEMU. Keep the detailed boot procedure in [docs/USER-GUIDE.md](docs/USER-GUIDE.md).
