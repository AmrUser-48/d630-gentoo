# Workflow architecture audit and refactor plan

**Date:** 2026-10-21  
**Branch audited:** `test/sfs-initrd-20261016`  
**Purpose:** identify the canonical build paths and define a safe cleanup plan. This is an audit, not a workflow rewrite; the current SFS build should be allowed to finish before build workflows are changed.

## Intended operating model

Expose three operational workflows:

1. **Build kernel** — build and publish a pinned D630 kernel, its matching external initramfs, modules, firmware, checksums, and manifest.
2. **Build SFS** — restore one named encrypted Gentoo checkpoint, finish the required packages, create a disposable runtime copy, build `squashfs`, and QEMU-test the exact kernel + initramfs + SFS set.
3. **Interactive saved-state runner** — restore a named (or explicitly selected latest) checkpoint, provide the private interactive session, and let the operator manually create a new encrypted checkpoint.

Keep `.github/workflows/validate.yml` as lightweight CI. It is not a production build workflow.

The `runner-state-*` checkpoint, `binpkgs-*` package release, kernel bundle, and bootable SFS bundle are different artifacts and must stay clearly distinguished. Never treat a temporary Actions artifact as a durable restore point.

## Current workflow inventory

There are currently nine workflow files. Their roles overlap:

| Current workflow | What it actually does | Refactor disposition |
|---|---|---|
| `build-d630-kernel.yml` | Builds Linux plus the **external** initramfs, modules, firmware, manifest and checksums. Uploads a 30-day Actions artifact and a persistent kernel release. | Keep as the kernel build. Make its release tag the explicit input to the SFS build. |
| `build-d630-state-boot-bundle.yml` | Restores an encrypted full Gentoo state, finishes runtime packages, makes a separate trimmed root, builds SquashFS, QEMU-tests the boot set, and publishes the boot bundle and binpkgs. | Keep as the canonical SFS build, but remove accidental/implicit inputs and automatic expensive triggers. |
| `restore-gentoo-runner-state.yml` | Restores a selected encrypted `runner-state-*` release to `/opt/gentoo`, then starts private SSH and installs the manual state-save command. | Preserve the stateful interactive-runner capability. It should be the single canonical restore-point runner. |
| `restore-gentoo-runner-state-retry.yml` | Near-copy of the preceding workflow, plus a push trigger on `main` intended to force a replacement run. | Consolidate only after checking the active session/recovery need; do not keep two copies long-term. |
| `gentoo-interactive-build.yml` | Starts a **fresh official Stage 3** and provides a private package-building session. Publishes binpkgs and a redacted reference snapshot. It does **not** restore the full encrypted Gentoo root. | Treat as a separate/legacy builder until its useful package-set/export behavior has been mapped into the desired runner. Do not silently delete it or describe its reference snapshot as a full restore point. |
| `build-d630-runtime-squashfs.yml` | Alternative SFS path: starts a fresh Stage 3 and imports selected binpkg releases. | Retire after the state-based SFS path is proven and no longer needs this fallback. |
| `build-mesa-binpkgs.yml` | Another fresh-Stage-3 builder devoted to Mesa/dependencies. | Optional/legacy package-production path; do not present it as a required step in the core pipeline. |
| `publish-gentoo-binpkgs.yml` | Converts an existing, not-yet-expired interactive-runner artifact into durable release assets. | Temporary recovery helper only; unnecessary for new runs once durable publishing is reliable. |
| `validate.yml` | Validates repository sources and workflow syntax. | Keep. |

### The two interactive concepts must not be confused

- `gentoo-interactive-build.yml` is a fresh-Stage-3 package builder. Its `SESSION-SNAPSHOT.tar.zst` records configuration/package/runner information for reference; it is **not** the full root filesystem.
- `restore-gentoo-runner-state.yml` restores the encrypted root filesystem from `runner-state-*`. The installed `save-gentoo-state` command creates a new encrypted, chunked full-state checkpoint that the restore workflow can consume.

For the requested three-workflow interface, the state-preserving restore runner is the checkpoint-capable path to preserve. Before removing or merging the fresh-Stage-3 runner, transfer any still-needed package-set, binpkg-export, or optional boot-bundle behavior; its current outputs are not equivalent to a full-state checkpoint.

## Confirmed problems to fix

### 1. The SFS workflow does not actually select the kernel version it advertises

In `build-d630-state-boot-bundle.yml`, the input `kernel_version` is validated and shown in the run name, but the download step is fixed to:

- Actions run ID: `38891651088`
- Artifact name: `d630-kernel-bundle-6.18.56-run-1`

That is a particular historical artifact, not a lookup for the requested version and not the output of the latest kernel build. A later kernel build may publish a newer release while the SFS workflow continues to use the old bundle.

**Fix:** have the SFS workflow take an explicit kernel-release tag (for example, a tag published by `build-d630-kernel.yml`), download that release's files, check `SHA256SUMS`, and verify its manifest/kernel release before proceeding. Do not guess “latest” or bind an unrelated version input to a hard-coded run ID. Show the exact source state and kernel bundle tag in the SFS manifest.

### 2. Editing an SFS script launches a costly build

The state-based SFS workflow has a `push` trigger on the branch for edits to the workflow and the runtime/SquashFS scripts. A normal script fix therefore restores the full encrypted build state and starts package/SFS work automatically. The latest run was started by this trigger.

**Fix:** use `workflow_dispatch` for the expensive build. Push and pull-request validation should stay in `validate.yml`; validation must never imply that a package build or boot test has passed.

### 3. There are two incompatible SFS construction paths

- State-preserving route: `scripts/build-state-squashfs.sh` calls Portage in the restored build root, constructs a separate runtime copy, then calls `scripts/build-squashfs-inplace.sh`.
- Fresh-Stage-3 route: `scripts/build-runtime-squashfs.sh` downloads the current upstream Stage 3 and builds a new root from supplied binpkgs.
- `scripts/build-squashfs.sh` is another staging-copy packer, and `scripts/build-runtime-squashfs-local.sh` wraps the fresh-Stage-3 route with a pinned old binpkg archive.

These approaches have different inputs and preservation guarantees. The state-based route is the one that matches the current saved-Core-2-state objective. Keep one canonical production path; label any retained alternative as legacy/manual instead of putting both in the same “how to build the SFS” instructions.

**Invariant:** never depclean, trim, or pack `/opt/gentoo` in place. Keep the restored builder and `var/cache/binpkgs` intact. Only the disposable runtime copy is eligible for pruning.

### 4. The restore workflow has a duplicate and an external-branch dependency

The two restore workflows duplicate the restore and SSH logic. The recovery clone adds a push trigger on `main`, while both workflows use the same concurrency group with cancellation enabled. That is a reason to consolidate, not to keep the clone permanently.

Also, the restore workflow downloads `scripts/save-runner-state-encrypted.sh` from the mutable `main` URL instead of installing the version in the checked-out commit. A run on another branch can therefore restore a checkpoint but install a different version of the save script.

**Fix:** keep one restore-point workflow and install the checked-out script after validating it, so the saved-state procedure corresponds to the workflow revision. Do not change restore/encryption behavior during the first consolidation pass; test checkpoint creation, checksum verification, and restoration together.

### 5. The root README describes old and conflicting pipeline stages

The main README still says the SquashFS is unfinished and describes `build-d630-runtime-squashfs.yml` as the automated route, despite the state-based builder and QEMU test now being present. It also mixes the direct-folder external-initramfs design with an older ISO plan that calls for an embedded initramfs and a live ISO. The repository map omits the state-based scripts/workflow and restore-point path.

The documentation should have one current-status statement and one canonical “which workflow do I run?” section. Historical/optional ISO work belongs in a separate design document, clearly marked as not the current boot pipeline.

## Artifact and restore-point contracts

Keep these names/roles unambiguous:

- **Kernel release:** `d630-kernel-<version>-run-<run_id>`; contains `kernel`, `initramfs`, `modules-<kernelrelease>.tar.zst`, `d630-firmware.tar.zst`, config, manifest and `SHA256SUMS`.
- **Full build-state checkpoint:** `runner-state-YYYYMMDDTHHMMSSZ`; encrypted archive chunks plus `manifest.txt` and `SHARD-SHA256SUMS`. It is the restore source, not a boot image.
- **Binpkg release:** `binpkgs-<run_id>`; package shards and package manifest/checksums. A reference session snapshot is not a full root backup.
- **Tested boot release:** `d630-gentoo-boot-<run_id>`; `squashfs`, the exact tested `kernel` and `initramfs`, matching kernel release/manifest/checksum information, and QEMU diagnostics.

The final filename expected by the current GRUB/initramfs contract is `squashfs` (without a required extension). Keep the persistent kernel/boot release separate from state checkpoints so a release cannot be mistaken for a restore source.

Every workflow must fail closed if a required file is missing, if checksums fail, or if the selected module archive does not match `KERNELRELEASE.txt`. Create the “tested boot release” only after QEMU passes. A green source validator is not a successful SFS build and is not proof of a boot.

## Recommended refactor sequence

1. **Let the current build finish.** Capture its actual result and outputs; specifically distinguish SFS creation from QEMU success. Do not overwrite or delete its selected checkpoint.
2. **Define the input/output contracts first.** Kernel tag and restore-state tag should be explicit SFS inputs. Manifests should record the immutable source commit, checkpoint tag, kernel release/tag, target package list, compressor/options, and test result.
3. **Make the kernel workflow self-describing.** Publish one persistent release with a predictable asset set. The SFS workflow must download the selected release and verify it rather than referring to an Actions run number embedded in YAML.
4. **Make SFS a manual production action.** Remove the expensive push trigger; retain source validation on push/PR. Keep the saved build tree immutable by building/pruning only a separate runtime copy.
5. **Consolidate restore-point entry points.** Preserve a single restore + private SSH + manual save workflow. Confirm the versioned save script and the existing secret/passphrase contract before removing the recovery clone.
6. **Reduce the visible workflows.** Keep the kernel build, state-based SFS build, one stateful runner, and validation. Migrate any needed binpkg/boot-bundle export from the fresh-stage3 runner before retiring that route. Treat the Mesa-only workflow and temporary publisher as optional/recovery tooling or retire them after verifying no active use.
7. **Rewrite the README last.** Make it a concise entry point with current status, the three operational workflows, inputs/outputs, restore-point rules, and troubleshooting links. Move deep configuration/history into focused docs; archive, do not silently erase, incident notes and old design decisions.

## Status at audit time

- Source validation on commit `09f00b99275bd61d28a01441d36645b9d78d0262` passed: [run 39508356461](https://github.com/AmrUser-48/d630-gentoo/actions/runs/39508356461).
- State-based SFS run [39507549274](https://github.com/AmrUser-48/d630-gentoo/actions/runs/39507549274), started from commit `b644f423f300d62be75bf235dcaef2c3e7341e30`, has restored `runner-state-20261015T153832Z` and is in the runtime SquashFS build step. Its QEMU boot test is pending as of this audit. Do not call the SFS fixed until the actual test output confirms a successful boot and a live runlevel-3 console.
- No production workflows were rewritten as part of this audit.
