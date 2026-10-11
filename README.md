# d630-gentoo

A small Gentoo-based live rescue and installation system, primarily designed for the Dell Latitude D630. The goal is a fast-booting, compact, legacy-BIOS-compatible live environment that can inspect disks, repair or install operating systems, connect to networks, and provide a lightweight X11 desktop.

**Current state:** source scaffold only. The repository is not yet a bootable image. The current GitHub Actions workflow validates files; it does not bootstrap Gentoo or build an ISO.

## Project goals

1. Produce a bootable x86_64 live ISO for old BIOS-based computers, with the D630 as the primary target.
2. Keep the final runtime small and practical for rescue work, without sacrificing support for the target laptop's hardware or common disk formats.
3. Build on GitHub Actions rather than on the D630, whose Core 2 Duo is too slow for large Gentoo builds.
4. Optimize compiled software for the Core 2 family, not for the remote build runner.
5. Keep the build system separate from the final live root. **Portage must not be present in the final runtime image.** Build tools, compilers, headers, source trees, temporary build files and package caches must also be excluded unless a specific runtime need is documented.
6. Prefer a reproducible, inspectable build pipeline and small incremental changes over a large untested one-shot build.
7. Establish a working minimal ISO first. Only then consider persistence, a raw disk image, more applications or further size reduction.

## Primary target hardware

- **Laptop:** Dell Latitude D630.
- **CPU:** Intel Core 2 Duo T7250, 2.00 GHz, 2 cores; current kernel reports `CONFIG_MCORE2=y`.
- **Graphics:** Intel GM965 / GMA X3100, PCI `8086:2a02` (secondary function `8086:2a03`). `i915` works and Mesa 22.3.6 reports accelerated `Mesa Intel(R) 965GM (CL)`, OpenGL 2.1.
- **Wi-Fi:** Intel PRO/Wireless 3945ABG, PCI `8086:4222`; firmware `iwlwifi-3945-2.ucode` version `15.32.2.9` loads successfully.
- **Audio:** Intel HDA `8086:284b` with IDT/SigmaTel STAC9205 codec `8384:76a0`; retain the matching HDA codec path, not every sound driver.
- **Storage and USB:** SATA AHCI `8086:2829`, IDE/ATAPI `8086:2850`, ICH8 UHCI/EHCI controllers; a SATA SSD and ATAPI CD-RW/DVD-ROM are detected.
- **Input and peripherals:** i8042 keyboard, AlpsPS/2 DualPoint touchpad/stick, USB mouse, O2 Micro USB CCID smart-card reader, and Huawei Android device currently in MTP mode.
- **Still unresolved:** no Ethernet PCI function appeared in the supplied inventory; Bluetooth is exposed by the Dell rfkill platform but was software-blocked and no Bluetooth adapter enumerated. Verify before choosing drivers.
- **Other requirements:** USB storage and joystick, Bluetooth, wired networking if available, Android ADB/fastboot and RNDIS, NTFS and Btrfs support.
- **Disks and filesystems:** partition-table tools, ext-family filesystems, VFAT, NTFS and Btrfs. The live environment must be able to access and repair common installed systems.
- **Boot:** legacy BIOS. Do not make UEFI or Secure Boot a prerequisite.

The first release should prioritize the D630. Broader hardware compatibility is welcome only when it does not materially increase image size or threaten reliability.

## Hardware inventory and graphics compatibility

The detailed hardware inventory, confirmed PCI/USB IDs, codec details, kernel-driver priorities, and outstanding questions live in [`docs/hardware-inventory.md`](docs/hardware-inventory.md). Treat it as the source of truth when pruning kernel modules or setting Gentoo package flags. The wired Ethernet function and Bluetooth adapter are still unconfirmed; do not guess their drivers.

**GMA X3100 / GM965 is Intel Gen4 graphics.** The existing Debian 12 baseline is known-good: `glxinfo -B` reports Mesa 22.3.6, renderer `Mesa Intel(R) 965GM (CL)`, accelerated rendering, and OpenGL 2.1. Keep this as the comparison point while validating Gentoo's `VIDEO_CARDS="intel"` and Mesa Crocus support. The Gentoo `video_cards_i915` USE flag is not the same as kernel `CONFIG_DRM_I915`; do not enable it just because the kernel module is named `i915`. Prefer Xorg modesetting initially. Do not assume Vulkan, modern Intel firmware, or hardware video acceleration is supported.

## Desktop and utilities

The intended graphical stack is Xorg with lightweight window managers:

- Openbox
- dwm
- herbstluftwm

Include xterm as the small, dependable terminal fallback. Alacritty is desired but should be checked against the chosen Gentoo profile and its graphics/runtime dependencies before being treated as mandatory. Keep the environment useful without a display manager if that reduces complexity.

Rescue utilities should focus on storage inspection, mounting, partitioning, file transfer, network troubleshooting and text editing. Avoid pulling in large desktop suites or redundant tools without a clear use case.

## Build and optimization rules

- Initial compiler target: `-O2 -march=core2 -mtune=core2`.
- **Never use `-march=native` for release builds.** GitHub Actions runners may use newer CPUs such as EPYC; the generated binaries must run on the Core 2 Duo T7250.
- Start without global LTO or experimental optimization flags. Prioritize reliable builds and test results before trying further optimization.
- Keep build parallelism appropriate to the available GitHub Actions runner memory. Do not copy the D630's CPU count blindly to the remote runner.
- Use a known, explicit Gentoo profile and pin or record the relevant stage3, repository snapshot, kernel source and tool versions so builds can be reproduced.
- Validate package atoms, USE flags, masks and profile compatibility against the actual Gentoo tree. `config/package.list` is a starting candidate list, **not** a resolved dependency closure.
- Separate the build environment from the runtime staging root. Do not remove files from the build environment just to shrink the final image; prune only the runtime root.
- Inspect dependency closure and package contents before stripping. Do not delete libraries or files merely because they look large or unused.
- Keep logs and publish build artifacts only after the workflow has checked that the expected files exist and are non-empty.

## Planned live-image architecture

The intended first image design is:

1. A custom or carefully selected Linux kernel suitable for the D630.
2. A small initramfs that initializes devices, locates the live medium, loads the compressed root and starts the live system. Do not remove it until the ISO boot flow works; a separate initramfs can be avoided only by building equivalent early-root logic into the kernel or changing the root-image design.
3. A SquashFS-compressed, read-only runtime root.
4. A RAM-backed OverlayFS writable layer so the base image remains unchanged during a session.
5. A legacy-BIOS bootloader and a straightforward boot menu.

Persistence is a later feature, not a prerequisite for the first working ISO. A raw `.img` target may be added after the ISO boots reliably. Do not claim the system is bootable until the image has been generated and tested.

## Kernel and firmware priorities

Keep the kernel features needed for live boot, disk access and the target laptop:

- initramfs support, devtmpfs, procfs, sysfs and tmpfs
- SquashFS, OverlayFS and loop devices
- SATA/AHCI, libata, SCSI disk and USB mass storage
- ISO9660 and support for ext2/3/4, VFAT, NTFS and Btrfs as required by the selected kernel configuration
- Intel i915 graphics for GM965/GMA X3100, plus a fallback framebuffer
- Intel 3945ABG Wi-Fi driver and matching firmware
- Intel HDA audio and required sound components
- Ethernet, USB input and Bluetooth support
- ADB/fastboot and RNDIS support if included in the first runtime

Prune unrelated drivers only after checking dependencies and the resulting configuration. In particular, do not blindly strip filesystem, storage, graphics or firmware support that the boot process or rescue use cases require. DVB, unrelated AMD and NVIDIA drivers are not priorities for this D630-focused image.

Firmware has licensing and redistribution implications. Verify the applicable terms and include only firmware required for the selected hardware and kernel.

## Repository map

- `README.md`: project requirements, contributor/AI instructions and implementation plan.
- `config/package.list`: initial runtime package candidates.
- `config/make.conf`: starting compiler settings and USE flags; must be validated against the selected Gentoo profile.
- `config/kernel-notes.md`: confirmed kernel/device requirements and live-boot strategy.
- `docs/hardware-inventory.md`: PCI/USB IDs, codec details, Mesa baseline, outstanding device identification and hardware collection notes.
- `scripts/validate-sources.sh`: basic scaffold checks.
- `.github/workflows/validate.yml`: source validation only, not a Gentoo build.

## Instructions for AI coding agents

Treat this README as the project's source of truth. Read it and inspect the current repository state before proposing or changing files.

1. **Do the requested task directly when repository tools permit it.** Do not merely provide a plan when a safe, concrete repository change was requested. After changes, report the exact files changed, commit or workflow status, and any remaining blockers.
2. **Be explicit about state.** Distinguish between source validation, package resolution, successful compilation, ISO generation, VM boot testing and testing on real D630 hardware. Never describe a scaffold or an untested artifact as a working live system.
3. **Protect the main branch.** Make small, coherent commits. Avoid destructive resets, force-pushes, deleting releases or overwriting unrelated work. Inspect existing content before replacing it.
4. **Do not fabricate results.** Never claim a workflow ran, a package built, an ISO booted or a file was tested unless the corresponding tool output or log confirms it.
5. **Build for Core 2, not the runner.** Use `-march=core2 -mtune=core2`; do not use `-march=native` in distributable binaries.
6. **Keep Portage out of the final image.** Portage is allowed in the isolated build environment only. Also exclude compilers, development headers, source trees, temporary files and package caches from the runtime root unless justified.
7. **Do not over-strip.** Preserve D630 graphics, Wi-Fi, audio, Ethernet, USB, Bluetooth, boot-critical storage, rescue filesystems and required firmware. Confirm each proposed removal against dependencies and the actual kernel config.
8. **Validate Gentoo details.** Check package atom names, USE flags, ebuild availability, profiles and dependency changes against the selected Gentoo repository snapshot. Do not assume Debian package names or USE flags apply to Gentoo.
9. **Keep CI stages honest and incremental.** First validate source files; next validate package metadata and build inputs; then build the runtime root; then assemble the ISO; finally run automated boot checks. A green source-validation job does not prove that Gentoo builds or that the ISO boots.
10. **Make failures actionable.** Preserve concise logs, identify the first real error, fix the cause rather than masking it, and rerun the smallest relevant job before restarting expensive stages.
11. **Control scope and size.** Prefer a compact, functional rescue environment. Do not add a package merely because it is familiar; state why it is needed and account for its runtime dependencies.
12. **Keep secrets out of Git.** Never commit credentials, access tokens, personal session files or machine-specific secrets. Use GitHub Actions secrets only when a workflow truly requires them.
13. **Document important decisions.** If changing architecture, package selection, kernel configuration or image format, update the relevant configuration or notes in the same change.
14. **Do not imply unavailable access.** If a required remote operation, runner permission or hardware test is unavailable, say so and provide the exact limitation.

## Implementation plan

### Stage 1 — Establish the inputs
- Select and record the Gentoo stage3 and profile.
- Validate the initial package list, USE flags and firmware requirements.
- Decide which kernel source/configuration will be used.
- Add checks for missing files, invalid package entries and required target settings.

### Stage 2 — Build a minimal runtime root
- Bootstrap Gentoo in GitHub Actions.
- Install only the selected runtime packages into a separate staging root.
- Resolve and inspect runtime dependencies.
- Remove build-only content from the staging root and report the resulting size.

### Stage 3 — Make the live image
- Build the kernel and initramfs.
- Implement SquashFS discovery and RAM-backed OverlayFS startup.
- Assemble a legacy-BIOS bootable ISO.
- Publish the ISO as an artifact only after file-integrity checks pass.

### Stage 4 — Test and reduce
- Test boot in an automated VM where available.
- Inspect boot logs and verify networking, graphics, storage and filesystem tools.
- Test on the physical D630 when possible.
- Remove unnecessary packages or modules one category at a time, repeating relevant tests after each change.

### Stage 5 — Optional follow-up work
- Add persistence only if it can be kept optional.
- Consider a raw disk image.
- Add extra utilities only when their value justifies their dependencies and size.

## Current limitations

The repository currently contains the initial source scaffold and a workflow that validates those source files. It does not yet resolve the Gentoo package set, build a Gentoo runtime, compile the kernel, assemble an ISO or run boot tests. Those are the next engineering tasks; the README does not claim they are already implemented.
