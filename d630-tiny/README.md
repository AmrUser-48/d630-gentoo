# D630 Tiny two-file boot

## Overview

D630 Tiny is a standalone, text-mode Linux environment for the Dell Latitude D630. Its boot payload consists of exactly two files: a Linux kernel image named **kernel** and one external initramfs named **initramfs**. GRUB loads those two files directly from a normal GRUB-readable partition.

The GRUB menu script is a small separate configuration file named **tiny.cfg**. It locates and loads the two payload files; it is not a third kernel or filesystem image. Tiny does not boot a Gentoo root, SquashFS, OpenRC or systemd, and it does not include Portage. The running system is held in RAM.

## Status

The documented release [d630-tiny-shell-40818375822](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822) passed the project's QEMU boot and setup checks. Physical D630 validation, especially the Intel 3945ABG Wi-Fi, GMA X3100 framebuffer, audio and laptop-specific devices, remains separate and must not be inferred from QEMU.

**Kernel-profile limitation:** the current Tiny initramfs workflow reuses a pinned kernel bundle; it does not yet compile the dedicated no-module [Profile 30](../kernels/profiles/30-d630-live.config). The two-file boot design is in use, but that fact alone does not prove the current release kernel was built from tinyconfig or with CONFIG_MODULES=n. The dedicated Tiny kernel build must replace the pinned kernel input before that claim can be made.

## Layout

- **kernel** — standalone Linux x86-64 bzImage copied from the matching kernel release.
- **initramfs** — external initramfs containing early CPU microcode followed by the compressed Tiny userspace archive.
- **tiny.cfg** — GRUB script copied from [boot/grub.cfg](boot/grub.cfg); locates and boots the two payload files.
- [init](init) — PID 1 for the RAM-only BusyBox environment; mounts devtmpfs, proc, sysfs and tmpfs, initializes ZRAM and starts the console shell.
- [build-initramfs.sh](build-initramfs.sh) — assembles and validates the external initramfs.
- [firmware-files.list](firmware-files.list) — optional setup-mode firmware additions; not the minimum firmware requirement for D630 boot.
- [run-qemu.sh](run-qemu.sh) — downloads or selects a matched release pair, verifies checksums and starts QEMU.
- [docs/USER-GUIDE.md](docs/USER-GUIDE.md) — installation, GRUB, update, recovery, QEMU, networking, shell and persistence instructions.

## Requirements

Target hardware is an x86-64 Dell Latitude D630 with legacy BIOS and a partition readable by GRUB. The installed boot directory is:

~~~text
/d630-tiny/
├── kernel
├── initramfs
└── tiny.cfg
~~~

The kernel must support an external initramfs (CONFIG_BLK_DEV_INITRD=y with an empty CONFIG_INITRAMFS_SOURCE), and all drivers needed before the Tiny userspace starts must be built into the kernel. A genuinely module-free Tiny kernel uses CONFIG_MODULES=n and has no /lib/modules dependency.

The D630 hardware set includes Intel AHCI/ATA PIIX storage, ICH8 UHCI/EHCI USB 2.0, GM965 / GMA X3100 graphics, Intel 3945ABG Wi-Fi, HDA/SigmaTel audio, PS/2 ALPS DualPoint input, ACPI and Dell laptop support. The intended dedicated kernel configuration is [Profile 30](../kernels/profiles/30-d630-live.config).

For QEMU tests, install qemu-system-x86 and sha256sum. The repository launcher uses curl for downloads; automatic release selection uses GitHub CLI when enabled by the launcher.

## Use

Download **kernel**, **initramfs** and **SHA256SUMS** from the same [Tiny release](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822). Verify the pair before installation. Do not mix a kernel from one release with an initramfs from another: the early microcode, firmware, kernel ABI and required built-in drivers are a matched set.

Place the two payload files and the GRUB script on the same GRUB-readable partition:

~~~text
/d630-tiny/kernel
/d630-tiny/initramfs
/d630-tiny/tiny.cfg
~~~

The menu entry in /etc/grub.d/40_custom loads tiny.cfg with GRUB's configfile command. That script searches for /d630-tiny/kernel and /d630-tiny/initramfs, then runs linux and initrd. Regenerate the GRUB menu after adding the entry. The complete safe installation and update procedure is in the [Tiny user guide](docs/USER-GUIDE.md).

Keep the separate /d630-gentoo/ kernel, initramfs and SquashFS files untouched. Tiny changes are volatile: files created or modified in the running RAM root disappear after reboot. Use the included rebuild-initramfs helper to save a new initramfs to persistent storage when appropriate; retain a known-good backup.

## Build

The canonical initramfs workflow is [Build D630 Tiny standalone initramfs](../.github/workflows/build-d630-tiny-initramfs.yml). It assembles the BusyBox environment, optional network/setup tools, firmware, early microcode and the final external initramfs. The workflow currently consumes a pinned kernel bundle rather than building a kernel from Profile 30.

The kernel and initramfs have separate roles:

- The kernel provides architecture support, built-in device drivers, filesystems, networking and the kernel's external-initramfs loader.
- The initramfs provides PID 1, BusyBox, shell utilities, optional network/setup tools, firmware and the RAM-only userspace.
- Early Intel CPU microcode is stored as an uncompressed CPIO archive prepended to the main compressed CPIO archive. It is part of the single initramfs file, not a third boot file.

The physical Wi-Fi driver needs iwlwifi-3945-2.ucode. The network-enabled initramfs also carries regulatory.db and regulatory.db.p7s so cfg80211 can obtain its regulatory rules before the real root filesystem exists. The D630's GM965 / GMA X3100 does not require the modern i915 firmware blobs for newer Intel GPU generations.

**Known firmware excess:** the current optional setup-mode manifest lists 36 newer-generation i915 blobs and four Broadcom tigon blobs. Those entries do not match the currently enumerated GM965 graphics or the supplied D630 PCI inventory. The setup builder currently validates and includes this 40-file list; do not interpret it as a list of firmware required for this laptop's normal boot. It remains a cleanup item.

## Releases

Use kernel and initramfs from one matching **d630-tiny-shell-*** release, together with its SHA256SUMS file. The release contains additional diagnostic files and build inputs; only kernel and initramfs are the two boot payloads. The GRUB script is available in the repository as [boot/grub.cfg](boot/grub.cfg) and is installed as tiny.cfg.

See the [repository release index](../docs/releases.md) for the published OS and kernel bundles. Do not substitute the Gentoo SFS kernel bundle for a Tiny-specific kernel unless the matching Tiny release explicitly identifies that source and configuration.

## Validation

The source validator checks the Tiny scripts and profile fragments:

~~~bash
./scripts/validate-sources.sh
bash scripts/validate-kernel-profiles.sh
~~~

The Tiny workflow verifies required initramfs members, archive integrity and release checksums, then boots the exact kernel/initramfs pair in QEMU. Its emulated USB Ethernet can test basic networking; it does not test the physical Intel 3945ABG radio.

For a release pair, check SHA256SUMS before installation and inspect the initramfs contents when diagnosing missing firmware or tools. Physical validation is still required for Wi-Fi, i915 framebuffer behavior, audio, Alps touchpad/TrackPoint, suspend/resume, thermals and power management. QEMU success is not proof of those hardware paths.

## Related documentation

- [Tiny user guide](docs/USER-GUIDE.md)
- [Kernel configuration profiles](../kernels/README.md)
- [D630 hardware inventory](../docs/hardware-inventory.md)
- [Gentoo live OS](../d630-gentoo/README.md)
- [Known issues](../docs/known-issues.md)
- [Release index](../docs/releases.md)
- [Linux kernel Kconfig documentation](https://docs.kernel.org/kbuild/kconfig.html)
