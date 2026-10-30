# AGENTS.md — D630 Linux repository

Operational instructions for AI coding agents. Human-facing documentation is in component READMEs and user guides; concise project context is in [llms.txt](llms.txt).

## Required reading

Before editing, read `llms.txt`, this file, the root [README](README.md), the nearest component `README.md` and `AGENTS.md`, and [known issues](docs/known-issues.md). Before changing or deleting release assets, also read [the release index](docs/releases.md).

## Architecture invariants

There are two separate operating systems:

- `d630-tiny/`: standalone BusyBox shell and external initramfs; no Gentoo root or Portage; runtime changes are RAM-only.
- `d630-gentoo/`: Gentoo/OpenRC live OS; read-only SquashFS and volatile RAM OverlayFS.

There are three mutually exclusive kernel profiles:

- `20-d630-base.config`: modular overlay for conventional installed Gentoo.
- `30-d630-live.config`: standalone Tiny kernel.
- `40-d630-builtin.config`: built-in Gentoo live/SquashFS kernel and current kernel workflow target.

These are configuration fragments, not three complete `.config` files. Never combine them. Do not imply profiles 20/30 have dedicated built and tested releases until those builds exist.

## Hardware and compiler policy

Target: Dell Latitude D630, Core 2 Duo T7250, Intel GM965/GMA X3100, Intel PRO/Wireless 3945ABG, HDA/SigmaTel, AHCI/ATA_PIIX, USB 2.0 and legacy BIOS/GRUB.

Gentoo userland: `-O2 -pipe -march=core2 -mtune=core2`. 64-bit Linux kernel: generic x86-64 ISA baseline with `KCFLAGS=-mtune=core2`. Do not set `CONFIG_MCORE2` or use `-march=native` in CI.

## Change discipline

- Inspect active workflows, manifests and release-tag references before changing build inputs.
- Keep the direct-folder Gentoo boot path as the current tested method. ISO remains an optional packaging/distribution target; ISO-specific early userspace and end-to-end boot/persistence testing are unfinished.
- Keep writable `gentoo-data.img` beside the ISO on a writable host filesystem, never inside the read-only ISO.
- Preserve the original Gentoo runner root and `/var/cache/binpkgs`; trim only a separate runtime staging root.
- Treat repository-root `output/` as historical CI staging, not automatically the newest release.
- Never delete a release, tag, asset or saved runner snapshot by age alone. Follow the explicit cleanup policy and dry-run in `scripts/prune-obsolete-releases.sh`; preserve all currently pinned kernel bundles and the newest two encrypted runner states.
- Do not reveal/log `STATE_ENCRYPTION_PASSPHRASE`, GitHub credentials or decrypted runner-state contents.
- Do not silently replace pinned artifacts with newer ones: kernel configurations, module archives and firmware may differ.
- Report source validation, package/kernel build, artifact checksums, QEMU boot, graphical startup and physical D630 tests as separate results.

## Canonical checks

From repository root:

- `./scripts/validate-sources.sh`
- `bash scripts/validate-kernel-profiles.sh`
- `bash scripts/validate-kernel-config.sh`

Read each workflow before dispatch. Expensive kernel and restored-runner workflows are not documentation-validation tools.

## Documentation policy

Every project `README.md` follows [docs/README-TEMPLATE.md](docs/README-TEMPLATE.md), with the same section order. Detailed runbooks belong in dedicated guides.

Keep these audiences separate:

- `README.md`: human-facing purpose, status and navigation.
- `AGENTS.md`: operational instructions and repository invariants for coding agents.
- `llms.txt`: compact project context and authoritative document map.
- `.github/copilot-instructions.md`: pointer to the canonical agent instructions.

Avoid maintaining conflicting duplicated rules. Nested `AGENTS.md` files may add component-specific constraints, but must not override root architecture rules.
