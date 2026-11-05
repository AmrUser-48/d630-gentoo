D630 Tiny two-file initramfs agent rules
=========================================

Purpose and scope
-----------------

These rules apply only to d630-tiny/: the standalone, RAM-only D630 Tiny
system booted by a Linux kernel and one external initramfs. This is not the
Gentoo/OpenRC SquashFS system.

Read the repository-root AGENTS.md, d630-tiny/AGENTS.md, this file,
d630-tiny/README.md, d630-tiny/build-initramfs.sh, the network/setup staging
scripts, the active Tiny workflow, the matching kernel configuration and the
QEMU tests before changing the image.

Two-file boot invariant
-----------------------

* The installed boot payload is exactly two files:
  /d630-tiny/kernel and /d630-tiny/initramfs.
* tiny.cfg is a small GRUB menu/configuration script stored beside the
  payload. It tells GRUB how to load the two files; it is not a third kernel
  or initramfs payload.
* The initramfs is the complete root filesystem. It contains PID 1 (/init),
  BusyBox and selected userspace programs. The root is volatile RAM; changes
  disappear on reboot unless a new initramfs is saved.
* Keep the current matching kernel + initramfs pair together. Do not combine
  a kernel, early-microcode archive, firmware bundle, modules or initramfs
  from different releases.
* Preserve the existing early Intel microcode CPIO archive unchanged and
  prepend it to the compressed main CPIO archive. Keep the main archive in
  newc CPIO + Zstandard level 3 unless a tested compatibility reason requires
  a change.
* Do not add a Gentoo root, SquashFS, OverlayFS, Portage, OpenRC, systemd,
  desktop stack or ISO root to Tiny. Do not copy the Gentoo build root into
  the initramfs.

Build from the runner's existing packages
-----------------------------------------

The interactive Gentoo runner may already have a restored build root and
compiled package cache. Inspect it before using the standalone Tiny workflow.

1. Locate and verify the actual restored Gentoo root, installed package
   records, binpkg cache and any previously built Tiny/AGY/aichat artifacts.
   Paths such as /opt/gentoo are only candidates; inspect the runner.
2. Reuse installed binaries and compatible binpkgs from that root. Do not
   download a fresh Stage 3, rebuild already available dependencies, or
   launch a parallel package build solely because the checked-in Tiny
   workflow currently bootstraps its own root.
3. Build missing software in the runner, not inside the final initramfs.
   Use the repository's Core 2 target policy. Rust applications such as
   aichat must use RUSTFLAGS="-C target-cpu=core2"; C/C++ userspace uses
   -march=core2 -mtune=core2. Never use -march=native or runner CPU
   autodetection for the D630 target.
4. Preserve the restored Gentoo build root, Portage state and binpkg cache.
   Do not run depclean or destructive pruning against that source root.
   Stage the initramfs in a separate disposable directory.
5. Reuse build-network-tools.sh and build-setup-tools.sh as extraction
   references, but improve their inputs/dependency handling where needed.
   Copy only selected executable files, their verified runtime dependencies
   and the data/configuration they need. Never copy the entire Gentoo root.
6. Avoid duplicate full-root copies and check disk space before extracting
   archives. Keep failed build diagnostics and useful staging data for
   recovery.

Userspace priorities
--------------------

Tiny remains a small text-mode rescue/work environment. Keep BusyBox static
as the early boot/PID 1 foundation and use it for ordinary shell utilities
where its applets are adequate. Add external programs only when they provide
a real capability that BusyBox lacks or the user explicitly requested.

Priority 1 — requested AI command-line tools:

* Include aichat and the actual AGY command-line agent used in the current
  runner. Preserve the real executable/entry-point names and the required
  scripts, templates and runtime data. Do not invent an AGY repository URL or
  substitute a similarly named project: use the exact source checkout or
  built artifact already present/identified by the user.
* Prefer one Core 2-compatible release binary per tool. Inspect ELF
  architecture, interpreter and every shared-library dependency; do not
  assume a binary is static because it is written in Rust or Go.
* For AGY, inspect its actual launcher and runtime requirements. If it needs
  a language runtime, include only the runtime and modules needed to execute
  it, not the compiler, package manager, SDK, headers or development tree.
  If it can be packaged as a self-contained executable, prefer that.
* Include aichat's runtime certificates and any required TLS/HTTP libraries.
  Keep its configuration directory available and document expected provider
  configuration/environment variables.
* Never embed API keys, provider tokens, GitHub credentials, SSH keys,
  cookies, private prompts or runner environment files. Credentials must be
  supplied by the operator at runtime or from explicitly mounted persistent
  storage. Do not print them in logs or manifests.
* Do not start either AI tool automatically from /init. They are interactive
  commands launched by the user after boot and network setup.

Priority 2 — compact everyday tools:

* Keep the existing static BusyBox applets, Bash, lf, doas, file, curl,
  Wi-Fi utilities, DHCP script, zstd, cpio, tar, CA certificates, rdmsr and
  wrmsr where currently required.
* Add a compact, coherent command set for agent and shell work: coreutils,
  findutils, grep, sed, awk, less, git, jq, fd, ripgrep and sd. Reuse BusyBox
  applets instead of shipping redundant full implementations unless
  compatibility requires the full utility.
* Keep a usable editor and file manager. Preserve the configured lf setup;
  prefer the existing Neovim binary only when its runtime tree and
  dependencies fit cleanly. A smaller editor is acceptable only if it does
  not silently replace a specifically requested installed editor.
* Keep process/memory inspection tools such as ps, free, top or htop when
  their dependencies are modest and they work on the target.
* Include only useful terminfo entries, shell completions/configuration and
  font files. Do not copy whole locale, documentation, test or developer
  trees.

Priority 3 — D630 audio, not generic SoC audio:

The D630 has Intel ICH8 HD Audio with a SigmaTel/IDT STAC9205 codec. Keep
that real hardware path; do not add unrelated SoC audio drivers or large
audio services.

* Verify the matching kernel has the HDA controller, SigmaTel codec and
  ALSA PCM/timer support built in, or include the exact matching modules and
  dependency metadata if the kernel is modular. The current Tiny image
  cannot rely on modules that are not present in its initramfs.
* Include the small ALSA userspace closure: alsa-lib and alsa-utils with
  working aplay, arecord, amixer and speaker-test. alsamixer is useful when
  its terminal dependency is available.
* Include SoX with ALSA output/input and selected useful codecs
  (WAV/PCM, FLAC, Ogg/Vorbis, Opus and MP3 where matching libraries are
  available). Include LAME and Opus runtime/tools when they add a usable
  command-line function.
* Keep the audio path direct through ALSA. Do not add PulseAudio, PipeWire,
  WirePlumber, MPD, ncmpcpp, a desktop mixer applet or a sound server to this
  text-mode initramfs. Do not enable SoX's large FFmpeg backend merely for
  convenience.
* Verify with aplay -l, arecord -l, amixer, sox --help and lame --version
  in QEMU where virtual audio exists, then on the real D630. QEMU audio
  success does not prove that the laptop HDA codec works.

Hardware and firmware discipline
--------------------------------

Use the confirmed Dell Latitude D630 inventory, not a generic PC profile.

* Retain Intel PRO/Wireless 3945ABG support and the exact
  iwlwifi-3945-2.ucode firmware. Keep regulatory.db and regulatory.db.p7s
  for cfg80211. Keep early Intel microcode in the prepended microcode archive.
* The GM965/GMA X3100 does not require the modern i915 firmware blobs for
  newer Intel GPU generations. Remove the obsolete 36-file newer-i915
  firmware selection from firmware-files.list.
* Remove the four Broadcom Tigon firmware files unless the current physical
  PCI inventory proves a matching Ethernet controller is present and needed.
  Do not preserve an old 40-file firmware count/check merely to satisfy an
  obsolete test. Replace it with checks for the actual required firmware.
* Do not add SoC audio, DVB, unrelated GPU, Cherry-vendor-specific keyboard,
  Bluetooth or other unsupported device payloads without evidence. Keep
  generic PS/2/i8042, Alps DualPoint, USB host and any generic USB HID
  support required for ordinary external keyboards/ADB. Do not remove a
  generic input class based only on one unused vendor-specific device.
* Do not ship all firmware from linux-firmware. Use a short explicit allowlist
  and retain upstream license/WHENCE notices for files actually shipped.

Runtime and security rules
--------------------------

* Keep /init small, POSIX-sh compatible and resilient. It must mount
  devtmpfs, proc, sysfs, devpts and tmpfs, initialize the existing ZRAM
  policy, set a useful PATH/HOME/TERM, and start the local interactive shell.
* Preserve all existing ZRAM capabilities and fallback behavior, including
  LZO on the low-RAM path and Zstandard level 3/recompression support when
  the running kernel exposes those interfaces. Do not simplify or disable
  ZRAM to save negligible bytes.
* Continue to boot without networking. Wi-Fi and DHCP setup are explicit
  user commands; do not block PID 1 waiting for a radio, access point or DHCP.
* Keep WPA configuration and credentials in RAM with restrictive permissions.
  Never bake Wi-Fi credentials into the initramfs.
* Keep doas permissions and file modes correct. Do not make ordinary
  commands setuid or run untrusted downloads as root.
* Retain the external rebuild helper. It must write to a separate persistent
  filesystem, never overwrite the live RAM root, preserve the original early
  microcode archive and atomically install the completed initramfs.
* No background services or daemons at boot unless essential for an
  explicitly requested feature. AI tools and audio programs are user-started.

Validation and release checks
-----------------------------

1. Inspect the exact kernel configuration and built-in/module status for
   storage, USB, Wi-Fi, HDA/SigmaTel audio, ZRAM, firmware loading and external
   initramfs support. A missing module in the root is not fixed by copying
   only its .ko file; include dependencies/metadata or build it in.
2. Verify all staged executables are x86-64 and Core 2-compatible. Check
   readelf -l, readelf --version-info, ldd inside a matching root, the dynamic
   loader, all shared libraries, NSS modules and CA certificates. No
   executable may have an unresolved dependency.
3. Verify required members in the actual CPIO archive: /init, BusyBox,
   both AI tools, their runtime files, network commands, ALSA utilities,
   SoX/LAME/Opus commands, editor/file manager, certificates, only required
   firmware and the early microcode prefix.
4. Check archive symlinks and modes, including /bin/sh, /bin/bash, doas,
   /etc/doas.conf, user home files and helper scripts. Do not assume a
   successful CPIO command means that the archive is usable.
5. Run the source validator, shell syntax checks, archive listing and Zstandard
   integrity test. Record compressed and uncompressed sizes and compare with
   the previous Tiny release.
6. QEMU-boot the exact kernel + initramfs pair. Test shell/login, ZRAM,
   aichat --version, AGY help/version, basic tools, TLS download, DHCP,
   Wi-Fi diagnostic path, ALSA command availability and the external rebuild
   helper. Mock API endpoints/configuration; never place real credentials in
   CI. Test interactive provider access only with a safe temporary secret
   injected at runtime and never log it.
7. Clearly separate QEMU results from physical D630 tests. The physical
   laptop is required to validate 3945ABG Wi-Fi, HDA audio, i915 framebuffer,
   Alps input, thermals, suspend/resume and power management.
8. Update the Tiny README, user guide, workflow checks and release manifest
   when the delivered command set changes. Publish kernel and initramfs as
   one matching release pair with checksums. Keep tiny.cfg beside them.

Do not delete old releases, saved runner states, kernel bundles or known-good
Tiny boot files as incidental cleanup. Keep a rollback pair. Report actual
artifacts, exact sizes, tested commands and any dependency that was omitted.
