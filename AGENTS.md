# AGENTS.md — D630 Linux repository rules

Canonical instructions for AI coding agents working in this repository. Read this file before editing. Component-level AGENTS.md files may add local constraints, but this file owns shared policy and hardware/build facts.

## 1. Read order and authority

Before changing files:

1. Read this file, the root README.md, llms.txt, and the nearest component README.md and AGENTS.md.
2. Read docs/known-issues.md and the relevant technical guide. For graphics work, include d630-gentoo/gma-readme.md and docs/hardware-inventory.md.
3. Inspect the exact workflow, script, manifest, package list, kernel profile, or configuration that will be changed.
4. Before release/tag/asset/state operations, read docs/releases.md and the cleanup script.

Use this precedence: explicit user request; this root policy; component-specific agent rules; implementation details in workflows/scripts; human-facing documentation. Never silently change an invariant to make a build pass. Update the relevant documentation when a verified project fact changes.

.github/copilot-instructions.md is only an AI-tool entry point to this file. Do not create a second set of Copilot-only engineering rules.

## 2. Repository architecture — do not merge these targets

There are two separate operating systems:

- d630-tiny/: standalone BusyBox shell and external initramfs. No Gentoo root or Portage; runtime changes are RAM-only.
- d630-gentoo/: Gentoo/OpenRC live OS. Read-only SquashFS root with a volatile RAM OverlayFS upper layer.

There are three mutually exclusive kernel configuration fragments:

- kernels/profiles/20-d630-base.config: modular overlay for conventional installed Gentoo.
- kernels/profiles/30-d630-live.config: standalone Tiny kernel.
- kernels/profiles/40-d630-builtin.config: built-in Gentoo live/SquashFS kernel and current kernel-workflow target.

These are fragments/overlays, not interchangeable full .config files. Never merge all profiles or imply that profiles 20/30 have dedicated tested releases until their build and boot workflows exist.

Preferred Gentoo boot is direct GRUB loading of the matching kernel, external initramfs and SquashFS from a normal GRUB-readable partition. ISO packaging remains optional; ISO-specific early userspace and persistent boot are not yet proven end to end. Keep writable gentoo-data.img beside the ISO on writable host storage, never inside the read-only ISO.

Preserve the original Gentoo build root and /var/cache/binpkgs. Runtime image trimming must operate on a separate staging root, never the restored build root.

## 3. Physical target and hardware facts

Primary target: Dell Latitude D630, legacy BIOS, Intel Core 2 Duo T7250 (Merom), 64-bit x86.

| Device | Confirmed hardware | Linux driver / policy |
|---|---|---|
| CPU | Core 2 Duo T7250, family 6/model 15, two cores | Core2 userland tuning; generic x86-64 kernel ISA |
| GPU | GM965 / GMA X3100, VGA 8086:2a02, secondary function 8086:2a03, Dell subsystem 1028:01f9 | Kernel i915; Mesa Crocus is the current Gen4+ Gallium path; legacy Intel DDX is optional A/B only |
| Wi-Fi | Intel PRO/Wireless 3945ABG, 8086:4222 | iwl3945; include matching firmware |
| Audio | HDA controller 8086:284b, SigmaTel/IDT STAC9205 codec | HDA and SigmaTel codec support |
| SATA | AHCI 8086:2829; IDE/ATAPI 8086:2850 | ahci, ata_piix, optical-drive support when required |
| USB | ICH8 UHCI/EHCI; USB 2.0 | UHCI/EHCI, HID, mass storage, USB networking |
| Android tethering | ADB/fastboot and USB RNDIS are required project use cases | Keep USB host, usbnet and RNDIS host support |
| Input | i8042 keyboard, Alps DualPoint touchpad/TrackPoint, USB HID | evdev/libinput and optional Synaptics profile |

Do not invent device IDs, firmware requirements, peripherals, or physical test results. Use lspci -nnk, lsusb, dmesg and the hardware inventory to resolve unknown devices. Treat the hardware inventory and component-specific technical guides as the detailed record.

### Graphics policy

Keep graphics layers distinct:

- Kernel i915 = DRM/KMS kernel driver.
- Xorg modesetting or legacy intel = DDX.
- Mesa crocus or classic i965 = OpenGL DRI driver.
- DRI2/DRI3 = X server/client buffer-sharing protocols, not codec drivers.
- i965_dri.so = classic Mesa OpenGL driver; i965_drv_video.so = Intel VA-API driver.

Gentoo default: Xorg built-in modesetting DDX with Mesa Crocus. The xf86-video-intel DDX with SNA/UXA is a separate A/B test; never enable both DDX Device sections at once. Existing Xorg profiles are under d630-gentoo/config/xorg/; keep the active Synaptics input configuration separate from optional graphics profiles.

GM965 is Gen4, not GM45/Gen4.5. Do not claim H.264 fixed-function decoding or working VA-API on this GPU. The Intel legacy VA-API driver's documented platform list does not include GM965. Software H.264 decoding can coexist with hardware OpenGL compositing/rasterization. XvMC is a legacy MPEG-1/2-era interface; its initialization does not prove browser video acceleration.

For full DRI/Mesa/VA-API/XvMC history and diagnostics, use d630-gentoo/gma-readme.md; do not duplicate its technical history in general README files.

## 4. Compiler and CPU tuning policy

### Objective

Compiler optimization is for **runtime execution speed on the Dell Latitude D630 (Core 2 Duo T7250 / Merom)**. It is not for faster compilation, shorter CI jobs, or smaller executables.

Priority order:

1. Maximize measured application execution performance on the target CPU while preserving correctness and the required feature set.
2. When runtime performance is equivalent, prefer the smaller executable/package.
3. Ignore compiler/build duration when choosing code-generation options. A slower build is acceptable when it produces measurably faster code.

Never trade a measured runtime regression for a smaller binary. Do not select `-Os`, `-Oz`, Rust `opt-level="s"` or `opt-level="z"` as defaults. Size-oriented options may be evaluated only when they do not reduce target runtime performance. Packaging compression and removal of debug metadata are separate distribution steps, not runtime compiler optimizations.

Do not use build-pipeline options as execution optimizations. In particular, omit `-pipe`: it changes how compiler output is passed between processes and does not make the generated program run faster. Build parallelism settings such as MAKEOPTS/NINJAOPTS also control build throughput, not executable performance.

### Target CPU and benchmark discipline

The CI runner CPU is not the target CPU. Never derive target flags from `-march=native`, runner `lscpu`, or runner `cpuid2cpuflags`. Compile for the known Merom/Core 2 target explicitly.

Judge optimization changes using correctness tests and representative runtime benchmarks on the physical D630 whenever possible. A GitHub runner can verify compilation and correctness, but its runtime benchmark is not evidence of performance on Merom. Keep benchmark inputs, output, software versions and test conditions comparable. Report runtime results first; report executable/package size as a secondary result. Do not use build duration as a reason to reject a faster runtime build.

### Gentoo C, C++, and Fortran defaults

The shared GCC/Clang-compatible baseline is:

~~~bash
COMMON_FLAGS="-O2 -march=core2 -mtune=core2"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
~~~

Use `-O2` as the global baseline for correctness and broad package coverage. Use `-O3` only for package-scoped builds where representative runtime benchmarks show a benefit; `-O3` is not automatically faster for every workload. The current package-scoped profile is `config/portage/env/custom-opt.conf`, mapped by `config/portage/package.env` to MC, SoX and LAME. Validate the benefit for each package independently; the mapping itself is not proof of a runtime-speed gain:

~~~bash
CFLAGS="-O3 -march=core2 -mtune=core2 -fomit-frame-pointer"
CXXFLAGS="${CFLAGS}"
FFLAGS="${CFLAGS}"
FCFLAGS="${CFLAGS}"
~~~

Preserve that package scope. Do not promote `-O3` or `-fomit-frame-pointer` globally without target-runtime evidence and correctness checks. Do not use `-Ofast`, `-ffast-math`, `-fno-stack-protector`, or other semantics/security-changing flags as generic speed switches; require a package-specific technical justification and tests.

### Rust and Cargo

Rust must target Merom explicitly:

~~~bash
RUSTFLAGS="-C target-cpu=core2"
~~~

For release builds, use `opt-level=3` as the speed-oriented optimization level. Thin LTO and one codegen unit are runtime-performance candidates; retain them when target-runtime benchmarks justify them. Their longer compile/link time is irrelevant to this decision. Do not switch to `opt-level="s"` or `"z"` merely to shrink the executable.

For a project-controlled manifest, use this as a performance-build candidate and compare its runtime against the same application built without LTO and with the normal codegen-unit count:

~~~toml
[profile.release]
opt-level = 3
debug = 0
strip = "debuginfo"
lto = "thin"
codegen-units = 1
incremental = false
~~~

Treat `lto = "thin"` and `codegen-units = 1` as performance candidates to validate on the target, not guaranteed wins for every application. `debug = 0` and `strip = "debuginfo"` reduce release artifact size; they are distribution choices and must not be described as execution-speed optimizations. Do not set `panic = "abort"` globally because it changes panic/unwind behavior.

If the upstream manifest cannot be changed, apply profile settings through Cargo's environment overrides without rewriting upstream files:

~~~bash
RUSTFLAGS="-C target-cpu=core2" \
CARGO_PROFILE_RELEASE_OPT_LEVEL=3 \
CARGO_PROFILE_RELEASE_DEBUG=0 \
CARGO_PROFILE_RELEASE_STRIP=debuginfo \
CARGO_PROFILE_RELEASE_LTO=thin \
CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
cargo build --release --target x86_64-unknown-linux-gnu
~~~

Use `--locked` when the project commits a Cargo.lock. The target CPU and target libc ABI are separate constraints. For binaries intended to run on Debian 12, build in a Bookworm environment/sysroot (glibc 2.36) rather than linking against a newer Ubuntu runner's glibc. `--target x86_64-unknown-linux-gnu` and `target-cpu=core2` do not pin the glibc baseline. Inspect ELF version requirements with `readelf -W --version-info` and test on the oldest supported runtime. Distinguish weak from strong symbol-version requirements; do not treat every weak-version warning as a fatal dependency without testing execution.

### Linux kernel compiler policy

For 64-bit Linux kernels, retain the generic x86-64 ISA baseline and use `KCFLAGS=-mtune=core2` when the workflow calls for tuning. Do not use `-march=core2` as the kernel ISA baseline and do not add `CONFIG_MCORE2`; there is no such x86-64 kernel processor selector.

The userspace `-march=core2` policy must not be copied into kernel builds. Keep this policy consistent in kernel workflows, profile documentation and diagnostics. Distinguish compiler optimization from Kconfig architecture selection.

## 5. Portage configuration — canonical paths and responsibilities

The configuration tree under config/portage/ is the source used by the active Gentoo chroot/build workflows. The builders copy these files into the build root's /etc/portage/; inspect the workflow before assuming a file is installed.

| Path | Responsibility |
|---|---|
| config/portage/make.conf | Canonical Gentoo Portage defaults: stable amd64, Core2 C/C++/Fortran flags, Rust target, jobs defaults, binpkg/log directories, global USE and VIDEO_CARDS=intel |
| config/portage/package.use/00-core2-cpu | Explicit Merom-safe CPU_FLAGS_X86 values |
| config/portage/package.use/10-d630-hardware | Mesa/Xorg/GPU, input, OpenRC/audio and D630-specific USE policy |
| config/portage/package.use/20-repositories | Overlay/repository integration flags |
| config/portage/package.accept_keywords/20-guru | Narrow per-package ~amd64 exceptions; base remains stable-only |
| config/portage/package.env + env/custom-opt.conf | Per-package compiler override mapping |
| config/portage/binrepos.conf/gentoobinhost.conf | Signed official Gentoo binary repository |
| config/portage/profile/package.use.force | Deliberate LLVM target-force override; keep only after validating LLVM/Mesa build requirements |

Important current settings:

- ACCEPT_KEYWORDS="amd64"; do not switch the entire tree to ~amd64. Add narrowly scoped exceptions only when required and documented.
- Global USE is OpenRC/X11-oriented and excludes systemd/Wayland. Per-package files narrow Mesa to Intel/Crocus and exclude Vulkan/LLVM USE for Mesa while retaining only the LLVM helper targets required by the current Mesa build.
- LLVM/Clang build targets are restricted to X86 and SPIRV by package-specific configuration. Do not broaden the target list without a dependency/build reason.
- FEATURES includes `buildpkg` and `getbinpkg` to keep reusable binary packages. The canonical config explicitly enables `binpkg-dostrip` and `binpkg-docompress`, and disables `splitdebug` for compact release binpkgs. `binpkg-dostrip` strips executables before package creation; `binpkg-docompress` compresses controllable documentation before packaging. These features reduce shipped package size without changing the target CPU ABI.
- Binary package compression is explicitly Zstandard with level 9 (`BINPKG_COMPRESS="zstd"`, `BINPKG_COMPRESS_FLAGS="-9"`). This trades additional build/packaging CPU time for smaller binpkgs. Benchmark package size and packaging time before increasing the level further. Do not change BINPKG_FORMAT without checking the effective value in the build root and compatibility of every binhost consumer. Keep the producer and consumers on a compatible format.
- PKGDIR=/var/cache/binpkgs and the signed binhost settings are intentional. Preserve reusable binary packages. Do not disable stripping or enable splitdebug for ordinary release packages; when debug symbols are required, preserve them as separate diagnostic artifacts instead of adding them to every binpkg.
- Do not confuse stripping DWARF/symbol data with Gentoo USE=`debug`, which can enable additional assertions, logging or debug code paths. Keep debug USE disabled by default; add package-specific exceptions only when required.
- EMERGE_DEFAULT_OPTS is interactive by default (--ask). Non-interactive scripts/workflows must explicitly use --ask=n or --ignore-default-opts where appropriate.
- Base MAKEOPTS/NINJAOPTS are defaults. CI workflows may recalculate them from available CPU/RAM and append runtime values; do not hard-code a runner-specific job count into shared build scripts.
- The current Mesa/runtime workflows enforce an x86_64-only ABI in their build-root setup when required. Do not change ABI policy globally without checking all consumers.

config/make.conf is a separate compatibility/validation file retained by the repository. Active Gentoo chroot builders install config/portage/make.conf. Do not assume the root-level file is the effective chroot configuration; preserve the overlap explicitly checked by scripts/validate-sources.sh and inspect actual workflow references before editing either file.

Before changing Portage settings:

1. Read the relevant configuration file and all package-specific overrides that can affect it.
2. Check workflow install/copy logic and environment overrides.
3. Inspect effective values with portageq envvar inside the actual Gentoo root.
4. Resolve changes with emerge --pretend --verbose --tree before building.
5. Keep package USE, keyword, env and profile-force overrides scoped to the smallest necessary package set.

Do not assume a USE flag exists. Verify the selected ebuild's metadata and the actual Portage version. Never solve a dependency conflict by deleting the Portage cache or replacing the restored build root.

## 6. README and human documentation style

README files are human-facing orientation and navigation documents, not forms to fill in. The validator `scripts/validate-readmes.py` checks structural quality without requiring every README to repeat a fixed set of sections.

Recommended section names and order are defined in `docs/README-TEMPLATE.md`. Use only sections that add useful information; omit inapplicable sections rather than writing "Not applicable". Purpose-specific headings are allowed. When multiple recommended sections are used, preserve their relative order.

Style and quality rules:

- Use exactly one descriptive H1 title. Avoid duplicate H2 sections and headings with no content. Repeated H3+ labels are allowed when they belong to separate subsections.
- Keep fenced code blocks balanced and use language tags for commands and configuration.
- Ensure relative/local Markdown links point to existing files or directories. Prefer descriptive link labels.
- Write for people using or maintaining the project. Use direct, concrete language and short paragraphs.
- Documentation is project documentation, not a conversation with the repository owner or an assistant response. Never include direct replies to the user, chat references, personal messages, profanity, rhetorical reactions, assistant meta-commentary, or raw scratch notes/placeholders such as `!TODO` and `!DOTO`. Convert verified requirements into neutral technical statements and usable instructions.
- Keep the root README an index: concise project overview, status, repository map, essential boot/build pointers and links. Do not put lengthy procedures, historical research, raw logs, full configuration files or repeated technical policy in it.
- Keep component READMEs focused on their component. Put step-by-step procedures in user guides; hardware research in hardware/technical guides; historical detail in archive or technical references.
- Use one consistent vocabulary: "D630 Tiny", "D630 Gentoo", "kernel profile", "SquashFS", "OverlayFS", "Core 2", "GM965/GMA X3100". Explain uncommon acronyms once when needed.
- Use Markdown tables for compact status/matrix data, bullets for short parallel items, and fenced code blocks for commands/configuration. Do not use screenshots or decorative ASCII art as a substitute for instructions.
- Prefer relative links inside the repository. Use exact release tags/asset names when known; do not write ambiguous "latest" links when a pinned release is required.
- State what is implemented and what is not. Distinguish source validation, package/kernel build, checksum verification, QEMU boot, graphical startup and physical D630 validation. Never turn a plan or an untested hypothesis into a "working" claim.
- Avoid badges, oversized banners, duplicate summaries, changelog dumps, verbose AI-generated filler and duplicated content maintained in several READMEs.
- The root README is the only human-facing README that links to this file.

The authoritative guidance is `docs/README-TEMPLATE.md`; it is intentionally flexible. Do not create filler sections merely to satisfy a template.
## 7. Source, workflow and release discipline

- Inspect the active workflow and its scripts before changing build inputs, runner restoration, caches, artifact names or release behavior.
- Preserve the original Gentoo runner root and /var/cache/binpkgs; runtime pruning operates only on a separate staging copy.
- Treat repository-root output/ as CI staging, not automatically the newest release.
- Do not silently replace pinned kernel bundles, module archives, firmware or binpkg sets. Their exact tags, manifests and checksums are part of the build input.
- Never delete a release, tag, asset or saved runner snapshot by age alone. Follow scripts/prune-obsolete-releases.sh, inspect its dry-run, retain all pinned kernel bundles and preserve the newest two encrypted runner states.
- Never expose or log STATE_ENCRYPTION_PASSPHRASE, GitHub credentials, private keys or decrypted runner-state contents.
- Do not trigger expensive kernel, full Gentoo or restored-runner workflows merely to validate documentation. Use the light source-validation workflow for static checks.
- Use readable workflow/job/step names. Record runner resources, selected target flags, package/config inputs and artifact checksums in build diagnostics.
- Keep Tiny and Gentoo artifacts, boot entries and release tags separate.

## 8. Validation and reporting

From repository root, run the relevant checks:

~~~bash
./scripts/validate-sources.sh
bash scripts/validate-kernel-profiles.sh
bash scripts/validate-kernel-config.sh
~~~

Read the validator before changing files it checks. Do not weaken or remove assertions just to make an edit pass; update checks when a deliberate design change requires it.

Report results as separate facts:

- Source/layout validation passed or failed.
- Package/kernel compilation completed or did not.
- Artifact contents and checksums verified or not.
- QEMU boot path tested or not.
- Xorg/Openbox startup tested or not.
- Physical D630 devices and graphics tested or not.

A green static-validation job is not proof of compilation, boot, graphics acceleration, media decoding or physical hardware support.
