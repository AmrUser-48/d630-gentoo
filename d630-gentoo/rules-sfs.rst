D630 Gentoo SquashFS agent rules
===================================

Purpose and scope
-----------------

These rules apply only to the Gentoo/OpenRC runtime image at
/d630-gentoo/squashfs. They do not apply to D630 Tiny or to kernel-profile
design except where a matching kernel/modules/firmware bundle is needed.

Read the repository-root AGENTS.md, d630-gentoo/AGENTS.md, this file,
d630-gentoo/README.md, the active runtime workflow, and every builder it
calls before changing the build. Inspect current files and runner artifacts.
Old TODOs and archived instructions are not authoritative when contradicted
by current code or verified artifacts.

Image-size invariant
--------------------

* The final compressed SquashFS must be strictly below 400 MiB
  (419,430,400 bytes). This is a hard ceiling, not a size target.
* The last documented Openbox image was about 198.43 MiB. Use the actual
  checked-out release and runner artifacts as the baseline; do not assume
  that old size is the current output.
* Prefer the smallest image that retains the requested working runtime.
  Do not remove useful runtime features merely to chase a smaller number, and
  do not add packages just because space remains.
* Record exact bytes and MiB from the final squashfs file. Fail validation
  if it reaches or exceeds 400 MiB.

Use the restored runner first
-----------------------------

The interactive Gentoo runner may already contain the expensive, populated
Gentoo build root, Portage database, compiled packages and binpkg cache.

1. Inspect the actual runner before building: current directory and Git branch,
   environment variables, mounted filesystems, free disk, runner workspace,
   saved-state restore logs, candidate Gentoo roots, installed package database,
   and /var/cache/binpkgs. Paths such as /opt/gentoo are clues, not assumptions.
   Identify and verify the real root.
2. Prefer the already-restored, working Gentoo root and its existing binpkgs.
   Do not bootstrap a fresh Stage 3 or use the clean Stage-3 runtime workflow
   merely out of habit when the restored root is available.
3. Inspect the installed package set and compatible binpkgs before invoking
   Portage. Reuse packages already installed or cached. Resolve only genuinely
   missing runtime atoms and dependencies. Use compatible binary packages
   first; build from source only when no suitable binpkg exists and the package
   is actually required.
4. Do not rebuild the kernel, initramfs, browser, scrcpy, or other already
   available artifacts unless inspection proves that the required artifact is
   missing, incompatible, or broken.
5. Never delete, depclean, strip, mutate, or repurpose the original restored
   build root, its /var/db/pkg, /var/cache/binpkgs, distfiles, Portage state,
   or saved runner-state archive. Never run emerge --depclean against that
   original root.
6. Keep the source/build root and final runtime root separate. Create one
   disposable runtime copy with ownership, permissions, symlinks, hardlinks,
   ACLs and xattrs preserved (for example, rsync -aHAX --numeric-ids).
   Exclude pseudo-filesystems and build caches deliberately. Do not make
   multiple full-root copies when the existing in-place SquashFS builder can
   safely trim a disposable copy.
7. Check free space before copying or unpacking. Use runner scratch storage
   for temporary data. Do not fill the workspace or overwrite an existing
   release/output directory blindly. Keep failed-run diagnostics and the
   disposable staging tree when useful for recovery.

Do not blindly trust a stale target list
----------------------------------------

The checked-in build-state-squashfs.sh and other builders may contain an
older hard-coded package list. Compare that list with the current package-set
files, the user's current requirements, actual installed packages and the
existing runtime. Update the builder or its input list when they disagree;
do not silently omit applications because an old script predates them.

Use the current package sets as the package-selection source of truth:

* d630-gentoo/config/package-sets/gui-initram.list for the lean X11/Openbox
  runtime and its required desktop/audio services.
* d630-gentoo/config/package-sets/cli.list for the console tools.
* d630-gentoo/config/package-sets/multimedia.list for audio/media utilities
  and scrcpy support.
* Read any additional package-set files actually selected by the active
  profile. Do not include unrelated desktop/development sets.

Required runtime content
------------------------

Preserve and verify the features that are part of the current D630 runtime:

* Gentoo/OpenRC boot, first-boot account setup, local console login, D-Bus and
  elogind where required by the graphical session.
* Xorg, xinit, xterm, Openbox, Xresources and the curated Openbox configuration
  for the graphical profile.
* Python 3 and its working standard-library modules. Python is intentional;
  do not remove it as a generic size optimization.
* Neovim, lf version 28, fd, sd, ripgrep, grep/egrep, htop, tealdeer (tldr),
  zsh, mc, less, file and the requested MSR utilities. Verify executable paths
  and runtime dependencies.
* The existing Links browser builds/variants already produced for this
  project. Inspect their actual filenames, purpose and dependencies, then
  retain all three requested variants where present in runner artifacts.
  Do not replace them with an unrelated distro build or silently collapse
  them to one variant.
* The already-built scrcpy 5.x build with keyboard-gamepad support (-j).
  Keep its matching server binary and every library required by that exact
  client/server build. Verify actual version, build ID/commit and help output;
  do not substitute an older packaged scrcpy.
* ALSA userspace, SoX, LAME and Opus support. For the Openbox runtime, retain
  the configured PipeWire/WirePlumber desktop audio path if it is installed
  and selected by the current package set. Verify playback/recording tools
  and shared libraries.
* Keep D630 Wi-Fi support only when the complete runtime closure is available.
  Credentials remain outside SquashFS: use the external
  /d630-gentoo/wifi.nmconnection first-boot import path. Never bake a Wi-Fi
  password, API token, SSH key or other secret into the image or logs.
* Retain matching kernel modules and D630 firmware needed by modular hardware
  drivers. Verify the module release exactly matches the kernel release and
  run/check depmod data when applicable.

Audio and hardware selection
----------------------------

The D630 audio device is Intel ICH8 HD Audio with a SigmaTel/IDT STAC9205
codec. Preserve the real HDA/ALSA path. Do not add SoC audio drivers or
unrelated platform audio stacks to this laptop image. Do not remove the HDA
codec/controller support or ALSA libraries/tools as generic pruning.

Prune only hardware-specific payloads demonstrably unrelated to the D630
inventory. Do not retain Cherry-vendor-specific keyboard support or unneeded
HID device drivers merely because they came from a broad profile. However,
preserve generic USB host, USB mass-storage, generic USB HID/input, PS/2/i8042,
Alps DualPoint, and USB networking support when needed by actual devices and
scrcpy/ADB use cases. Do not remove a generic subsystem based only on the name
of one unused peripheral.

Keep the runtime graphics path Intel GM965/GMA X3100 with the intended Mesa
Crocus configuration. Do not add Vulkan, OpenCL, a broad LLVM/Clang runtime,
Wayland, systemd, DVB, or unrelated GPU drivers. Keep only firmware needed by
identified D630 hardware and firmware explicitly required by the matching
kernel bundle. Preserve upstream license/attribution files for retained
firmware.

Runtime trimming policy
-----------------------

Apply all destructive pruning only to the disposable runtime staging tree,
never to the restored build root.

* Remove Portage executables/data, the ebuild repository checkout, package
  records, package caches, distfiles, build directories, compiler/toolchain
  executables, development headers, static archives, pkg-config/CMake
  metadata, debug-symbol payloads, tests and bytecode caches when they are
  not runtime dependencies.
* Remove GCC and binutils executables and development payload. Retain runtime
  libraries such as libgcc_s, libstdc++ and libatomic when a shipped executable
  needs them. Do not break scrcpy, Python or another binary by deleting a
  required shared library.
* Remove man pages, info pages, documentation trees and unneeded locale
  catalogs from the minimal Openbox image. Keep the selected English locale
  and required compiled locale data. Keep copyright/license notices,
  particularly firmware and font licenses.
* Keep Python runtime files and modules. Do not delete the Python standard
  library, certificates, fontconfig data, Xorg modules, Mesa DRI drivers,
  OpenRC service definitions, PAM files or other runtime data merely because
  they are large.
* Do not ship MPD, ncmpcpp or mpv. There is no requirement for an MPD server.
  Do not start a service unless the selected runtime actually needs it.
* Audit every symlink, executable, dynamic loader and shared-library
  dependency after pruning. Use ldd/ELF inspection in the matching root;
  no required executable may report a missing library.

Boot and session invariants
---------------------------

* Keep the established first-boot ordering: initialize the local live account
  and groups before the local login service starts.
* Exactly one local tty1 getty/autologin respawn entry is intended. Do not add
  duplicate gettys, tty7 gettys or a serial getty respawn entry. Do not
  reintroduce the previous rapid-respawn loop.
* Start X from the local logged-in session using the active VT and elogind.
  Keep the existing rootless Xorg configuration and active-VT xserverrc.
  Do not hard-code tty7 or switch to setuid Xorg as a shortcut.
* A serial-only QEMU session cannot validate X startup. Use a QEMU display
  with a real virtual terminal for graphical smoke tests.
* Keep the root SquashFS read-only and the OverlayFS writable upper layer in
  RAM. Changes are volatile and disappear at reboot. GRUB files remain
  outside the SquashFS. The preferred boot remains the matching kernel,
  external initramfs and squashfs files loaded directly from a normal
  partition.

Build and acceptance checks
---------------------------

Before the build, save a concise inventory of the chosen source root, its
installed package list, binpkg locations, available disk space and intended
runtime profile.

After building:

1. Confirm the output file is named exactly squashfs, is non-empty and is
   strictly below 419,430,400 bytes. Record bytes and MiB.
2. Run unsquashfs -s, inspect the filesystem/compressor and enumerate the
   final files. Verify no compiler, Portage, package database/cache,
   development headers, man/doc payload or unwanted firmware remains.
3. Verify required commands, Xorg/Openbox files, ALSA/audio tools, Python
   runtime, Links variants, scrcpy client/server and shared libraries.
   Check /etc/inittab and service links for exact tty1 behavior and inspect
   the active-VT xserverrc.
4. Verify ownership, modes, symlinks, dynamic dependencies, firmware
   allowlist and module/kernel release match. Check that no secrets are
   present.
5. Generate SHA-256 checksums and a concise manifest containing profile,
   source-state identity, package inventory, kernel release, output size and
   validation results.
6. Boot-test the exact resulting kernel + initramfs + SquashFS in QEMU.
   Verify discovery, read-only SquashFS mount, RAM OverlayFS, OpenRC,
   automatic tty1 login, sudo, core CLI tools and audio command availability.
   Test X/Openbox using a graphical virtual terminal; record QEMU adapter
   limitations separately.
7. Do not claim physical D630 validation from QEMU. Hardware audio, Intel
   graphics, Wi-Fi, suspend, thermals and peripherals require real-hardware
   testing.

Never remove old releases, saved runner states, binpkgs or known-good boot
files as incidental cleanup. Publish or replace a release only when the
active task explicitly requests it. Keep logs concise and retain actionable
failure diagnostics.
