# d630-gentoo

A small, lightweight Gentoo daily-driver system for the Dell Latitude D630, with an optional live ISO for testing, installation and recovery. The goal is a fast, responsive, legacy-BIOS-compatible desktop you can use every day for web browsing, file management, development, media, Wi-Fi, Android tools and ordinary computing; disk repair and rescue tools are included as secondary capabilities.

**Current state:** the repository now defines the standalone three-file boot contract and has an initramfs discovery script plus a GRUB2 menu-entry example. It does not yet produce a finished kernel/initramfs/SquashFS payload automatically; the image-build workflow remains to be implemented.

## Preferred boot: three files, root filesystem may be on another partition

Use these paths for the kernel, external initramfs archive, and SquashFS root. The kernel and initramfs can be found by GRUB on any GRUB-readable partition; the SquashFS root may be on a different partition:

```text
/d630-gentoo/
├── kernel
├── initramfs
└── squashfs
```

This can be a Windows NTFS partition or another filesystem supported by GRUB. The sample entry in [grub2/d630-gentoo.cfg](grub2/d630-gentoo.cfg) searches separately for `kernel` and `initramfs`, then passes no `d630.boot_uuid`. Consequently, the initramfs searches all partitions whose filesystems are built into the kernel for `/d630-gentoo/squashfs`. The initial supported set is NTFS3, VFAT/FAT, exFAT, ext2/3/4, and Btrfs; encrypted, LVM, RAID, or other unsupported storage layers are not automatically searched. Build these filesystem drivers into the kernel (`=y`), because initramfs cannot load a module from a root filesystem it has not mounted yet. If identical copies of `kernel` or `initramfs` exist on several partitions, GRUB will use its first match.

The initial three-file mode uses a temporary writable OverlayFS layer in RAM. **Changes made during the session are lost at reboot.** A persistent upper layer needs a separate suitable writable filesystem/image; NTFS itself is not used as the OverlayFS upper directory.

The older ISO boot path remains available for testing/recovery, but it is not required for this direct-folder boot method. The files listed above must still be generated and packaged by a kernel/initramfs/SquashFS build workflow; source validation alone does not create them.

## Project goals

1. Produce an installable x86_64 Gentoo daily-use system for old BIOS-based computers, with the D630 as the primary target; provide a bootable legacy-BIOS ISO for live testing, installation and recovery.
2. Keep the final runtime small and practical for rescue work, without sacrificing support for the target laptop's hardware or common disk formats.
3. Build on GitHub Actions rather than on the D630, whose Core 2 Duo is too slow for large Gentoo builds.
4. Optimize compiled software for the Core 2 family, not for the remote build runner.
5. Keep the build system separate from the final live root. Keep the compiler toolchain, development headers, source trees and build caches out of the base runtime image. Since this is a daily-use Gentoo system, Portage should remain available for package management; prefer CI-built binary packages on the slow D630, and keep the ebuild repository/distfiles out of the base image until needed.
6. Prefer a reproducible, inspectable build pipeline and small incremental changes over a large untested one-shot build.
7. Deliver a genuinely usable daily system, not a disposable rescue shell: persistent installed system files and user data are core requirements. Keep the live ISO as a testing/installation entry point, then produce and verify the disk-install target.

## Interactive Gentoo build runner

The workflow [Gentoo — Interactive Build Runner](.github/workflows/gentoo-interactive-build.yml) starts an ephemeral Ubuntu 24.04 GitHub-hosted runner, downloads the current official **amd64 glibc/OpenRC Stage 3**, installs the Portage configuration from this repository, syncs the Gentoo ebuild tree, and opens a private SSH session that drops directly into the Gentoo rootfs at `/opt/gentoo`. This is a chroot sharing the GitHub runner's Ubuntu kernel, not a virtual machine or a security-isolated Docker container; the runner is destroyed when the job ends.

### Portage target settings

- `CFLAGS/CXXFLAGS: -O2 -pipe -march=core2 -mtune=core2`; never use `-march=native` because the build host is newer than the D630.
- `config/portage/package.use/00-core2-cpu` enables only MMX/SSE/SSE2/SSE3/SSSE3 flags supported by the Core 2 Duo T7250. Do **not** run `cpuid2cpuflags` on the GitHub host and blindly copy those results into the target configuration.
- OpenRC profile is inherited from the official OpenRC Stage 3. The workflow copies the D630-specific USE flags in `config/portage/package.use/`.
- Portage defaults to `emerge --ask --verbose` through `EMERGE_DEFAULT_OPTS`, with one concurrent emerge job, `--load-average=4`, parallel fetch, and `FEATURES=buildpkg`. Each interactive package plan is visible before it is applied. Built packages are retained in `/var/cache/binpkgs`, exported in persistent `binpkgs-<RUN_ID>` Releases, and also included in a short-lived Actions artifact for recovery.
- The build environment installs Portage helpers and shell tools, including Git, rsync, nano, tmux, Midnight Commander, htop, Gentoolkit, eix, portage-utils and ufed. If an optional helper package fails, SSH remains available and the log is saved.

### D630 USE flags and Mesa/LLVM troubleshooting

This section records decisions and failure modes from the interactive Gentoo session. Use the checked-in configuration as the source of truth; a running GitHub Actions chroot does **not** receive repository changes automatically. Restart the workflow to get the new configuration, or edit the current chroot manually.

#### Baseline and CPU flags

`config/portage/make.conf` is deliberately small:

- `ACCEPT_KEYWORDS="amd64"`: stable amd64 ebuilds only. Do not add `~amd64` globally or add per-package testing keywords as a shortcut around a build problem.
- `CFLAGS/CXXFLAGS/FCFLAGS/FFLAGS="-O2 -pipe -march=core2 -mtune=core2"`; Rust uses `RUSTFLAGS="-C target-cpu=core2"`. Never use `-march=native` on the GitHub runner.
- `USE="X alsa dbus udev -systemd -wayland"`: an OpenRC/X11 target, not a global systemd/Wayland desktop.
- `MAKEOPTS="-j4"`, one concurrent Portage job, `FEATURES="parallel-fetch buildpkg"`, and binpkgs under `/var/cache/binpkgs`.

`config/portage/package.use/00-core2-cpu` is intentionally not generated from the remote runner's CPUID:

```text
*/* CPU_FLAGS_X86: mmx sse sse2 sse3 ssse3
```

The T7250 is Core 2/Merom. Do not enable SSE4, AES, AVX, or other instructions the CPU does not support. `CPU_FLAGS_X86` describes optional package code paths; it is not a replacement for `-march=core2`.

#### Put VIDEO_CARDS in package.use, not make.conf

Gentoo treats `VIDEO_CARDS` as a USE_EXPAND setting. The current Handbook recommends the per-package `/etc/portage/package.use` method; a global `VIDEO_CARDS="i915 intel"` in `make.conf` applies choices too broadly and makes package-specific selection harder. Do not try to use negative card names in that global variable as a filtering mechanism. In `package.use`, the `-*` reset and positive values are the intended syntax.

The intended D630 settings are in `config/portage/package.use/10-d630-hardware`:

```text
# Mesa for Intel GM965 / GMA X3100 (Gen 4): Crocus.
media-libs/mesa -llvm -vulkan VIDEO_CARDS: -* intel

# Xorg modesetting plus the optional legacy Intel DDX.
x11-base/xorg-drivers VIDEO_CARDS: -* intel i915

# Input support; Synaptics is preferred for the D630 touchpad by Xorg config.
x11-base/xorg-drivers INPUT_DEVICES: -* evdev libinput synaptics
x11-base/xorg-server -minimal

# Legacy BIOS only.
sys-boot/grub GRUB_PLATFORMS: pc
```

Important distinctions:

- For the GM965/GMA X3100, `intel` is the Mesa video-card option for the Intel Gen4 hardware driver (Crocus).
- `i915` under `x11-base/xorg-drivers` selects the legacy `xf86-video-intel` Xorg driver as an alternative to the Xorg server's built-in modesetting driver. It is **not** the kernel `i915` DRM driver and is not the same as Mesa's `video_cards_i915` Gallium driver.
- Do not enable Mesa's `video_cards_i915` just because the kernel module is named `i915`; for this hardware the target is `VIDEO_CARDS: -* intel`.
- Avoid global AMD, Radeon, NVIDIA, Asahi, Panfrost, VirGL and other unrelated GPU options. They are not part of the D630 target. In a verbose emerge plan, a card shown with a leading minus is disabled; a card shown in parentheses is profile-forced and needs separate investigation.

#### LLVM target pruning: why the dependency still appears

There are two different goals: disable LLVM-based **runtime rendering** that is not needed by this laptop, and reduce LLVM/Clang **build-time targets**. They are related but not interchangeable.

The current package USE choices are intended to disable Mesa's LLVM/llvmpipe software renderer and Vulkan/lavapipe runtime path. However, the current Gentoo Mesa ebuild can still pull in `dev-util/mesa_clc`, `llvm-core/clang`, `llvm-core/llvm` and `llvm-runtimes/libclc` as **build dependencies** for the Intel/SPIR-V helper path. Seeing LLVM in the dependency tree therefore does not, by itself, mean the final graphics setup will use llvmpipe or a Vulkan software renderer. Do not claim LLVM is absent just because `media-libs/mesa -llvm` is set.

The relevant checked-in settings are:

```text
media-libs/mesa -llvm -vulkan VIDEO_CARDS: -* intel
llvm-core/llvm LLVM_TARGETS: -* X86 SPIRV
llvm-core/clang LLVM_TARGETS: -* X86 SPIRV
dev-util/mesa_clc LLVM_SLOT: -* 22
dev-util/mesa_clc VIDEO_CARDS: -*
llvm-runtimes/libclc VIDEO_CARDS: -*
```

Notes and risks:

- Gentoo's base profile force-enables many `LLVM_TARGETS` flags because arbitrarily disabling LLVM backends can break reverse dependencies, including Clang, LLD and Rust. Forced flags often appear in parentheses in `emerge -pv` output and cannot be removed by an ordinary `package.use` line alone.
- `config/portage/profile/package.use.force` deliberately unforces unrelated LLVM targets for this size-constrained x86_64 builder. This is an opt-in deviation from Gentoo's defensive defaults, not a universally safe recommendation. Keep the native `X86` and the required `SPIRV` support; review this override after every repository sync because Gentoo may add new LLVM target names.
- Validate the actual target list in the emerge plan rather than assuming the profile override worked. If new targets remain forced, inspect the current `/var/db/repos/gentoo/profiles/base/package.use.force` and update the local override with the current target names. Be prepared to rebuild affected LLVM consumers, particularly Clang/LLD/Rust, if their target configuration changes.
- Keep the `LLVM_SLOT` selection for `dev-util/mesa_clc`. Setting the whole package to `dev-util/mesa_clc -*` is wrong: it removes the required slot choice and can produce a `REQUIRED_USE` error such as `exactly-one-of ( llvm_slot_18 ... llvm_slot_22 )`. The intended current setting is `LLVM_SLOT: -* 22`; re-check the available slot if the Gentoo tree has moved to a newer Mesa/LLVM generation.
- `llvm-runtimes/libclc` may still show `USE="spirv"`. That is not evidence that AMD or NVIDIA drivers are enabled; the important check is that its `VIDEO_CARDS` list does not enable `radeonsi`, `r600`, `nvidia`, or other unwanted targets.
- A local `VIDEO_CARDS: -* intel` setting selects requested options; it does not guarantee that every build dependency is absent. Ebuild `DEPEND`/`BDEPEND` declarations still determine what Portage must build.

#### Past mistakes: do not repeat

1. **Do not mask `>=media-libs/mesa-24.0.0` to get the desired driver.** That masks Mesa 24.0.0 and newer, including later stable releases; it can leave Portage with no acceptable Mesa candidate. Remove that mask unless the deliberate intent is to block every version in that range.
2. **Do not set `dev-util/mesa_clc -*`.** Keep its exactly-one-of LLVM slot requirement satisfied with `LLVM_SLOT: -* 22` (or the slot required by the current ebuild).
3. **Do not assume `-llvm` means no LLVM packages are installed or built.** It controls the Mesa USE-dependent path; build-time helpers can still depend on LLVM/Clang.
4. **Do not copy the CI CPU's `cpuid2cpuflags` output.** It describes the newer runner, not the T7250.
5. **Do not treat a successful source-validation workflow as a successful Gentoo emerge.** Validation checks repository inputs; only a real Portage pretend/build proves that the current ebuild graph and USE choices resolve.

#### Kernel source selection

For the current kernel-source plan, request the specific Gentoo source slot/version interactively. The configured `EMERGE_DEFAULT_OPTS` adds `--verbose` automatically:

```bash
emerge --ask sys-kernel/gentoo-sources:6.18.54
```

This is the requested kernel source atom, not a compiled/installed kernel by itself. Read the Portage plan before answering yes, and check the available ebuild if Portage reports that this exact version is unavailable or masked. Do not silently substitute a different version; verify the desired 6.18.y source first. After installing the sources, kernel configuration, compilation, installation and boot-loader setup remain separate steps.

#### Verification commands for a resumed session

Run these inside the Gentoo chroot before starting a long build:

```bash
# Inspect local choices and profile overrides.
grep -R -nE 'VIDEO_CARDS|LLVM_TARGETS|LLVM_SLOT|CPU_FLAGS_X86|media-libs/mesa|mesa_clc|libclc' \
  /etc/portage/make.conf /etc/portage/package.use /etc/portage/profile 2>/dev/null

# Check the effective Mesa flags and dependency tree; this does not build anything.
emerge --ask --pretend --verbose --tree --oneshot media-libs/mesa

# Inspect LLVM/Clang targets and the helper packages if the plan is unexpectedly large.
emerge --ask --pretend --verbose --tree llvm-core/llvm llvm-core/clang \
  dev-util/mesa_clc llvm-runtimes/libclc

# Review the complete rebuild impact before committing to changed USE flags.
emerge --ask --pretend --changed-use --deep @world
```

Do not launch the final `@world` rebuild merely to diagnose one package: its dependency closure may be large. First check the Mesa pretend output and the exact forced-target list. Interactive shells inherit `--ask --verbose` from `EMERGE_DEFAULT_OPTS` and reinforce those options through the Bash alias. The `gentoo-build-set` script uses `--ignore-default-opts --ask=n --verbose` when it has no TTY, and the workflow ignores defaults for its non-interactive repository sync, so automation cannot hang on the global `--ask`.

References: [Gentoo Handbook — base installation and VIDEO_CARDS](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Base#VIDEO_CARDS), [Gentoo profile semantics](https://wiki.gentoo.org/wiki/Profile_(Portage)), and [Gentoo discussion of LLVM target unforcing](https://forums.gentoo.org/viewtopic-p-8694335.html).

### Start an interactive session

1. Ensure repository Actions secrets `TAILSCALE_AUTHKEY` and `SSH_PUBLIC_KEY` exist. `SSH_PUBLIC_KEY` is the single-line public key from a client key such as `~/.ssh/id_ed25519_macos_runner.pub`; never upload the private key.
2. Open **Actions → Gentoo — Interactive Build Runner → Run workflow**.
3. Select the session duration (up to 300 minutes). Leave package set as `none` for an interactive-only session, or choose a package set and enable **Build the selected package set automatically** to start that build in the background while SSH stays open.
4. Copy the SSH command from the run summary. It looks like:

   ```bash
   ssh -tt -i ~/.ssh/id_ed25519_macos_runner \
     -o IdentitiesOnly=yes \
     -o PreferredAuthentications=publickey \
     -o PasswordAuthentication=no \
     gentoo@TAILSCALE_IP
   ```

The login enters the Gentoo chroot as root, so you can run `emerge --sync`, `emerge -av category/package`, inspect `/etc/portage/make.conf`, and use `gentoo-build-set cli`, `gentoo-build-set development`, `gentoo-build-set desktop`, `gentoo-build-set multimedia`, or `gentoo-build-set daily-driver`. For a custom startup set, select `custom` and enter space- or comma-separated atoms such as `dev-vcs/git net-misc/curl`. Custom atoms are validated as package atoms; complex USE-dependency expressions should be added to Portage configuration explicitly.

If a build was started automatically, watch it inside Gentoo with `tail -f /var/log/gentoo-build-set.log`; Portage's main log is `/var/log/emerge.log`. The runner can build for up to six hours total, including preparation and package compilation. Large sets such as `daily-driver` (Firefox, Xorg, Mesa and FFmpeg) can exceed that limit; start with smaller sets when you need to keep the interactive session available.

Download the `gentoo-build-output-...` artifact before it expires (retention is one day). It contains generated binary packages, logs, and the effective Portage configuration. Binary packages are amd64 packages compiled with Core 2 flags for packages built from source; Stage 3's preinstalled base packages are not automatically rebuilt.

### Persistent binary packages for the D630

The interactive runner now publishes packages that were built during its session to a persistent GitHub Release. This avoids putting large binary files into Git history and avoids relying on the one-day Actions artifact retention.

- Each runner run with at least one built Gentoo binary package creates a prerelease tagged `binpkgs-<RUN_ID>`.
- Release assets include `binpkgs-part-NNN.tar.zst` shards, `PACKAGE-LIST.txt`, `BUILD-MANIFEST.txt`, and `SHA256SUMS`. Each shard is kept below 2 GB and preserves the category/package paths from Portage's `PKGDIR`.
- Only packages actually built on that runner are included. The untouched stage3 base packages are not magically rebuilt. A release is a durable package export, not a complete installable Gentoo root and not yet an always-online Portage binhost.
- After extraction, the importer runs `emaint binhost --fix` to rebuild the local `Packages` index, then you can use normal Portage dependency resolution with `--usepkgonly`.

#### Save the currently running session's packages

The current runner session was started before automatic release publishing was added. To preserve its packages:

1. Let the Gentoo runner finish so its `gentoo-build-output-<RUN_ID>` Actions artifact is uploaded. Copy the numeric run ID from the Actions run page.
2. Open **Actions → Publish existing Gentoo binpkgs artifact → Run workflow**, enter that run ID as `source_run_id`, and start it. The workflow downloads the temporary artifact and publishes the persistent `binpkgs-<RUN_ID>` Release.
3. Do this before that source artifact expires (one day). The publishing workflow cannot rescue an artifact that GitHub has already deleted.

For future sessions, the interactive runner publishes the release automatically at the end whenever it has binpkgs.

#### Import released packages into a Gentoo installation

Check that the effective Portage `PKGDIR` has enough free space first. If needed, change `PKGDIR` in `/etc/portage/make.conf` to a directory on a larger filesystem before importing.

Download the importer from the repository and run it as root, passing the source runner's numeric run ID (or the full `binpkgs-<RUN_ID>` tag):

```bash
curl -fL https://raw.githubusercontent.com/AmrUser-48/d630-gentoo/main/scripts/install-binpkgs-release.sh \
  -o /usr/local/sbin/install-d630-binpkgs
chmod 0755 /usr/local/sbin/install-d630-binpkgs
/usr/local/sbin/install-d630-binpkgs <RUN_ID>
```

The importer downloads one shard at a time, checks it against `SHA256SUMS`, extracts it into the configured `PKGDIR`, and deletes each downloaded shard to limit temporary disk use. Run it as root; it does not install packages by itself.

Preview and install only from matching local binary packages:

```bash
emerge --ask --verbose --usepkgonly --pretend app-misc/mc sys-apps/ripgrep
emerge --ask --verbose --usepkgonly app-misc/mc sys-apps/ripgrep
```

`--usepkgonly` prevents falling back to compiling missing packages. If Portage reports a missing binary, its dependency was not built/published in that release, or its USE/profile/ABI settings do not match the target. Use a package set that builds the required dependency closure, or compile only the missing pieces deliberately.

### SquashFS naming is separate from persistence

The live ISO's read-only base is named `/LiveOS/rootfs.squashfs` and keeps its `.squashfs` extension. The separate writable persistence layer is `gentoo-data.img`, an ext4 filesystem image next to the ISO. These are different formats with different jobs; the Gentoo build-runner workflow does not rename a SquashFS file to `.img`.

## Primary target hardware

- **Laptop:** Dell Latitude D630.
- **CPU:** Intel Core 2 Duo T7250, 2.00 GHz, 2 cores; current kernel reports `CONFIG_MCORE2=y`.
- **Graphics:** Intel GM965 / GMA X3100, PCI `8086:2a02` (secondary function `8086:2a03`). `i915` works and Mesa 22.3.6 reports accelerated `Mesa Intel(R) 965GM (CL)`, OpenGL 2.1.
- **Wi-Fi:** Intel PRO/Wireless 3945ABG, PCI `8086:4222`; firmware `iwlwifi-3945-2.ucode` version `15.32.2.9` loads successfully.
- **Audio:** Intel HDA `8086:284b` with IDT/SigmaTel STAC9205 codec `8384:76a0`; retain the matching HDA codec path, not every sound driver.
- **Storage and USB:** SATA AHCI `8086:2829`, IDE/ATAPI `8086:2850`, ICH8 UHCI/EHCI controllers; a SATA SSD and ATAPI CD-RW/DVD-ROM are detected.
- **Input and peripherals:** i8042 keyboard, AlpsPS/2 DualPoint touchpad/stick, USB mouse, O2 Micro USB CCID smart-card reader, and Huawei Android device currently in MTP mode.
- **Networking:** Wi-Fi and Android USB RNDIS tethering are required. Wired Ethernet drivers are intentionally omitted. ADB/fastboot are separate userspace tools and must be tested with the phone in the appropriate USB mode.
- **Other requirements:** USB storage and joystick, Bluetooth core support pending adapter identification, MSR access (`CONFIG_X86_MSR=y`), NTFS and Btrfs support.
- **Disks and filesystems:** partition-table tools, ext-family filesystems, VFAT, NTFS and Btrfs. The live environment must be able to access and repair common installed systems.
- **Boot:** legacy BIOS. Do not make UEFI or Secure Boot a prerequisite.

The first release should prioritize the D630. Broader hardware compatibility is welcome only when it does not materially increase image size or threaten reliability.

## Hardware inventory and graphics compatibility

The detailed hardware inventory and confirmed PCI/USB IDs live in [`docs/hardware-inventory.md`](docs/hardware-inventory.md). Wired Ethernet drivers are out of scope. The Bluetooth adapter/transport remains unconfirmed.

**GMA X3100 / GM965 is Intel Gen4 graphics.** The existing Debian 12 baseline is known-good: `glxinfo -B` reports Mesa 22.3.6, renderer `Mesa Intel(R) 965GM (CL)`, accelerated rendering, and OpenGL 2.1. Keep this as the comparison point while validating Gentoo's `VIDEO_CARDS="intel"` and Mesa Crocus support. The Gentoo `video_cards_i915` USE flag is not the same as kernel `CONFIG_DRM_I915`; do not enable it just because the kernel module is named `i915`. Prefer Xorg modesetting initially. Do not assume Vulkan, modern Intel firmware, or hardware video acceleration is supported.

## Daily-use desktop and utilities

This is intended to be the system you actually use, not merely a rescue CD. The first usable desktop should provide a browser, graphical file manager, terminal, editor, audio playback, Wi-Fi controls, development tools and the existing rescue utilities. Keep optional applications modular so the installed base stays small.

The intended graphical stack is Xorg with lightweight window managers:

- Openbox
- dwm
- herbstluftwm

Include xterm as the small, dependable terminal fallback. Alacritty is desired but should be checked against the chosen Gentoo profile and its graphics/runtime dependencies before being treated as mandatory. Keep the environment useful without a display manager if that reduces complexity.

Everyday utilities should cover web browsing, file management, archiving, terminal work, editing, Git and media playback. Keep rescue utilities for storage inspection, mounting, partitioning, file transfer and filesystem repair. Avoid large desktop suites and redundant tools without a clear use case.

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

## Planned daily-use system and boot-image architecture

The installed root filesystem is the main product; the ISO is a way to test, install and recover it. The first deliverables should be a usable installable root filesystem plus a legacy-BIOS ISO, not an ISO-only rescue environment. The intended architecture is:

1. A pinned Linux 6.18.y LTS kernel baseline (with 6.12.y LTS as a fallback test), compiled for Core 2.
2. Required D630 drivers built into the kernel; no runtime kernel modules installed in the final image.
3. A legacy-BIOS bootable ISO, with a **kernel-embedded initramfs** and Super Grub2 Disk-compatible `/boot/grub/loopback.cfg` so GRUB needs to load only the kernel file.
4. A **minimal embedded initramfs** that exists only to initialize early userspace, run the configured early MSR hook, discover storage, and hand off to the full Gentoo root. Do not duplicate Bash, GNU utilities or `lf` in the initramfs when the main root already supplies them.
5. Filesystem and storage drivers built into the kernel so the embedded shell can discover and mount ext4, Btrfs, NTFS3 and FAT volumes without external modules.
6. A legacy-BIOS GRUB bootloader and a straightforward boot menu.
7. Persistent system configuration and user data on the installed disk. A live session may use a temporary overlay, but must not be presented as the daily-use installation.
8. A documented installation procedure that lays out a target disk, installs the root filesystem and kernel, and configures GRUB for legacy BIOS.

The live ISO uses an Alpine/Arch-style writable overlay: a read-only SquashFS base plus `gentoo-data.img`, an ext4 persistence image stored beside the ISO. The repo contains the Super Grub2 Disk loopback config, kernel-command-line contract, initial embedded `/init` and image-creation helper; the build pipeline must still assemble them into a bootable ISO and test that persistence works.

## Kernel and firmware priorities

Keep the kernel features needed for live boot, disk access and the target laptop:

- embedded initramfs support (`CONFIG_BLK_DEV_INITRD=y` and a configured `CONFIG_INITRAMFS_SOURCE`); the archive is built into the kernel image, so GRUB loads one kernel file
- a small executable `/init` that mounts devtmpfs, procfs and sysfs, runs a deliberately configured early-boot hook, and then mounts/hands off to the main Gentoo root (or opens a minimal emergency shell only if handoff fails)
- only the initramfs utilities needed for early boot: a tiny shell/toolbox (prefer statically linked BusyBox), device/mount support, and `wrmsr` from msr-tools if its required runtime dependencies are packaged
- full Bash and its startup files, GNU coreutils/findutils/grep/sed/gawk, `lf`, and normal rescue utilities belong in the main Gentoo root, not duplicated in the embedded archive
- SATA/AHCI, libata, ATAPI, SCSI disk and USB mass storage
- ext4, VFAT, NTFS3 and Btrfs rescue filesystem support
- built-in Intel i915 graphics for GM965/GMA X3100, with framebuffer console support
- built-in Intel 3945ABG Wi-Fi driver stack and matching firmware
- built-in Intel HDA audio codec path and USB input
- built-in USB RNDIS host networking for Android tethering; **no wired Ethernet drivers**
- `CONFIG_X86_MSR=y`, plus ADB/fastboot userspace tools

Prune unrelated drivers only after checking dependencies and the resulting configuration. In particular, do not blindly strip filesystem, storage, graphics or firmware support that the boot process or rescue use cases require. DVB, unrelated AMD and NVIDIA drivers are not priorities for this D630-focused image.

Firmware has licensing and redistribution implications. Verify the applicable terms and include only firmware required for the selected hardware and kernel.

## Repository map

- `README.md`: project requirements, contributor/AI instructions and implementation plan.
- `config/package.list`: main Gentoo root package candidates.
- `config/initramfs-package.list`: separate minimal early-boot package candidates.
- `initramfs/init`: embedded early userspace for loopback ISO discovery and persistent/volatile OverlayFS.
- `iso/boot/grub/loopback.cfg`: Super Grub2 Disk loopback menu.
- `config/kernel-cmdline.txt`: documented `d630.*` kernel command-line parameters.
- `scripts/create-persistence-image.sh`: create a sparse ext4 overlay image beside the ISO.
- `config/make.conf`: starting compiler settings and USE flags; must be validated against the selected Gentoo profile.
- `config/kernel-notes.md`: confirmed kernel/device requirements and built-in driver priorities.
- `docs/custom-iso-design.md`: Gentoo Handbook references, kernel baseline, direct ISO9660-root strategy and initramfs trade-offs.
- `docs/hardware-inventory.md`: PCI/USB IDs, codec details, Mesa baseline, outstanding device identification and hardware collection notes.
- `scripts/validate-sources.sh`: source/configuration checks.
- `scripts/package-binpkgs-release.sh`: shard built packages into persistent GitHub Release assets.
- `scripts/install-binpkgs-release.sh`: verify and import a package release into the target's configured Portage `PKGDIR`.
- `.github/workflows/publish-gentoo-binpkgs.yml`: publish packages from an existing, still-retained runner artifact.
- `.github/workflows/validate.yml`: source validation only, not a Gentoo build.

## Instructions for AI coding agents

Treat this README as the project's source of truth. Read it and inspect the current repository state before proposing or changing files.

1. **Do the requested task directly when repository tools permit it.** Do not merely provide a plan when a safe, concrete repository change was requested. After changes, report the exact files changed, commit or workflow status, and any remaining blockers.
2. **Be explicit about state.** Distinguish between source validation, package resolution, successful compilation, ISO generation, VM boot testing and testing on real D630 hardware. Never describe a scaffold or an untested artifact as a working live system.
3. **Protect the main branch.** Make small, coherent commits. Avoid destructive resets, force-pushes, deleting releases or overwriting unrelated work. Inspect existing content before replacing it.
4. **Do not fabricate results.** Never claim a workflow ran, a package built, an ISO booted or a file was tested unless the corresponding tool output or log confirms it.
5. **Build for Core 2, not the runner.** Use `-march=core2 -mtune=core2`; do not use `-march=native` in distributable binaries.
6. **Keep the daily-use system maintainable.** Include Portage for package management but avoid shipping compilers, development headers, source trees, ebuild trees and package caches in the base root. Prefer CI-built binary packages on the D630.
7. **Do not over-strip.** Preserve D630 graphics, Wi-Fi, audio, USB/RNDIS, Bluetooth core support, boot-critical storage, rescue filesystems and required firmware. Wired Ethernet is explicitly out of scope. Confirm each proposed removal against dependencies and the actual kernel config.
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
- Pin Linux 6.18.y LTS and keep 6.12.y LTS as a fallback.
- Build and audit the Core 2 kernel with required drivers built in, including i915, iwl3945, USB RNDIS host, HDA and MSR.
- Define the minimal embedded initramfs tree and `/init`; add a configurable early MSR hook and verify its timing, prerequisites and exact MSR values before enabling it by default.
- Keep Bash/GNU/`lf` configuration in the main Gentoo root, with only a minimal emergency shell and the early `wrmsr` hook in the initramfs.
- Add checks for missing files, invalid package entries and required target settings.

### Stage 2 — Build the compact daily-use runtime root
- Bootstrap Gentoo in GitHub Actions.
- Include a practical browser, file manager, terminal/editor, audio playback, Wi-Fi management, development tools and rescue utilities.
- Install only the selected runtime packages into a separate staging root.
- Resolve and inspect runtime dependencies.
- Remove build-only content from the staging root and report the resulting size.

### Stage 3 — Make the installable system and live ISO
- Build the kernel with required drivers built in and install no runtime kernel modules.
- Package the minimal early-boot userspace as a cpio initramfs and compile it into the kernel via `CONFIG_INITRAMFS_SOURCE`; do not publish or require a separate initramfs file.
- Publish a compressed installable root filesystem and a legacy-BIOS GRUB ISO for testing/installation. The installed system must retain changes, preferences and user files across reboots.
- Ensure the kernel can boot directly to `/init`, establish device nodes, run the early MSR hook only when explicitly configured and validated, and mount/handoff to the main Gentoo root with no external initramfs file.
- Verify Bash, GNU utilities and `lf` are provided by the main root rather than duplicated in the embedded archive; keep a small emergency shell in initramfs for root-mount failures.
- From the main root or emergency shell, test mounting ext4, Btrfs, NTFS3 and FAT volumes using the built-in kernel drivers and available userspace tools.
- Assemble a legacy-BIOS ISO with GRUB and the self-contained kernel; publish only after integrity checks and boot tests pass.

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

The repository currently contains the initial source scaffold and a workflow that validates those source files. It does not yet resolve the Gentoo package set, build a daily-use runtime, compile the kernel, assemble an ISO, prepare a persistent install target or run boot tests. Those are the next engineering tasks; the README does not claim they are already implemented.
