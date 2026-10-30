# D630 kernel agent rules

Follow the repository-root [AGENTS.md](../AGENTS.md).

## Profile boundaries

- Profile 20: modular overlay for conventional installed Gentoo.
- Profile 30: standalone Tiny kernel; dedicated build/release pending.
- Profile 40: built-in D630 Gentoo live/SquashFS kernel and current kernel workflow target.

These are configuration fragments, not complete kernel configurations. Do not combine profiles or apply all of them to one build.

## Build policy

Use a generic x86-64 ISA baseline with `KCFLAGS=-mtune=core2`. Do not add `CONFIG_MCORE2` or compile kernel code with `-march=core2`. Keep built-in the dependencies needed before the live SquashFS root is mounted: loop, SquashFS-Zstd, OverlayFS, host filesystem and D630 boot-critical drivers.

Run profile/config validators, then compile and inspect the generated configuration and artifacts, verify matching modules/firmware, and test QEMU separately. Static fragment validation is not a kernel build or boot test.
