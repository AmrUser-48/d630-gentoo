# D630 kernel agent rules

Follow the repository-root [AGENTS.md](../AGENTS.md).

## Profile boundaries

- Profile 20: modular overlay for conventional installed Gentoo.
- Profile 30: standalone Tiny kernel; dedicated build/release pending.
- Profile 40: built-in D630 Gentoo live/SquashFS kernel and current kernel workflow target.

These are configuration fragments, not complete kernel configurations. Do not combine profiles or apply all of them to one build.

## Profile 20 preservation rule

Profile 20 is the standard installed Gentoo kernel overlay, not a stripped kernel. Preserve Gentoo's version-specific distribution-kernel baseline for unrelated hardware families. The only deliberate generic-hardware exclusions are NVMe (no such storage/controller on this D630) and xHCI USB 3 (the D630 has ICH8 USB 2.0 UHCI/EHCI only). Do not disable Ethernet, media/capture, AMD/NVIDIA, virtualization or other generic driver families here. Set confirmed D630 device drivers to modules wherever Kconfig allows. Keep the ordinary SATA/AHCI root path, ext4 and essential Kconfig infrastructure built in. Some framework cores and boolean Kconfig options must remain built in for modular device drivers to work.

## Build policy

Use a generic x86-64 ISA baseline with `KCFLAGS=-mtune=core2`. Do not add `CONFIG_MCORE2` or compile kernel code with `-march=core2`. Keep built-in the dependencies needed before the live SquashFS root is mounted: loop, SquashFS-Zstd, OverlayFS, host filesystem and D630 boot-critical drivers.

Run profile/config validators, then compile and inspect the generated configuration and artifacts, verify matching modules/firmware, and test QEMU separately. Static fragment validation is not a kernel build or boot test.


## Embedded configuration policy

Keep `CONFIG_IKCONFIG=y` and `CONFIG_IKCONFIG_PROC=y` enabled in kernel profiles by default, together with `CONFIG_PROC_FS=y`. This allows the running kernel to expose its exact embedded configuration at `/proc/config.gz`. Treat this as the normal policy for general-purpose and diagnostic kernels. Disable it only for an intentionally minimal or size-constrained target, with an explicit documented reason. A Debian or upstream reference config that omits IKCONFIG is evidence about that build, not a reason to omit it from D630 profiles.
## Native ext4 filesystem invariant

All three profiles must keep `CONFIG_EXT4_FS=y`. Ext4 is a native in-tree Linux filesystem; never make it a module or disable it. Validate the resolved `.config` after `olddefconfig`/Portage Kconfig processing as well as the source fragment.

