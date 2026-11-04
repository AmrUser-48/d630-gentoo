# D630 kernel agent rules

Follow the repository-root [AGENTS.md](../AGENTS.md).

## Profile boundaries

- Profile 20: modular overlay for conventional installed Gentoo.
- Profile 30: standalone Tiny kernel; dedicated build/release pending.
- Profile 40: built-in D630 Gentoo live/SquashFS kernel and current kernel workflow target.

These are configuration fragments, not complete kernel configurations. Do not combine profiles or apply all of them to one build.

## Profile 20 preservation rule

Profile 20 is the standard installed Gentoo kernel overlay, not a stripped kernel. Preserve Gentoo's version-specific distribution-kernel baseline for unrelated hardware families; do not disable NVMe, xHCI, Ethernet, media/capture, AMD/NVIDIA, virtualization or other generic driver families in this profile. Set confirmed D630 device drivers to modules wherever Kconfig allows. Keep only the ordinary SATA/AHCI root path, ext4 and essential kernel infrastructure built in. Some Kconfig menu/subsystem options are boolean and cannot be modules; keep those enabled as required by their modular drivers.

## Build policy

Use a generic x86-64 ISA baseline with `KCFLAGS=-mtune=core2`. Do not add `CONFIG_MCORE2` or compile kernel code with `-march=core2`. Keep built-in the dependencies needed before the live SquashFS root is mounted: loop, SquashFS-Zstd, OverlayFS, host filesystem and D630 boot-critical drivers.

Run profile/config validators, then compile and inspect the generated configuration and artifacts, verify matching modules/firmware, and test QEMU separately. Static fragment validation is not a kernel build or boot test.
