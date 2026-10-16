# Checkpoint: d630tiny

**Checkpoint label:** `d630tiny`  
**Recorded:** 2026-10-16  
**Repository:** [AmrUser-48/d630-gentoo](https://github.com/AmrUser-48/d630-gentoo)

## Resume here first

Do not restart the kernel build or the old full Gentoo package rebuild. Inspect current Actions status and this file before changing anything.

### Current objective

Finish and verify the small Gentoo runtime SquashFS (SFS) and external initramfs for the Dell Latitude D630 / Core 2 Duo T7250. Final direct-folder boot contract:

```text
/d630-gentoo/kernel
/d630-gentoo/initramfs
/d630-gentoo/squashfs
```

Kernel/userland target stays Core 2 compatible; userland flags are `-O2 -pipe -march=core2 -mtune=core2`. Legacy BIOS/GRUB, OpenRC, constrained boot partition, Intel GM965/GMA X3100, Intel 3945ABG and Intel HDA are the primary target. The runtime SFS should be kept around 400 MiB or less if feasible for the available ~500 MiB partition; measure the actual image, do not assume it fits.

## Repository and branches

- `main` at README AI working-rules commit: [`c8f45f97d9c3`](https://github.com/AmrUser-48/d630-gentoo/commit/c8f45f97d9c3ae7d76245c549f07e6eb1d48c1c2).
- Current experimental branch: `test/sfs-initrd-20261016`, last observed at [`2a92a5e094f9`](https://github.com/AmrUser-48/d630-gentoo/commit/2a92a5e094f9d96a2781f9cbfa14f5c969483540).
- Its latest source-validation run [38899622668](https://github.com/AmrUser-48/d630-gentoo/actions/runs/38899622668) passed.
- The README now has **AI assistant operating instructions** near the top: inspect existing artifacts before rebuilds, protect state/binpkgs, use Handbook/Wiki/Forums critically, and distinguish lint/build/QEMU/real-hardware success.

## Confirmed artifacts and runs

- Encrypted Gentoo runner snapshot: [`runner-state-20261015T153832Z`](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261015T153832Z). Its three encrypted rootfs shards, manifest and shard checksums were present at last inspection. Repository secret `STATE_ENCRYPTION_PASSPHRASE` is required to restore it.
- Existing kernel/initramfs was built successfully in run [38891651088](https://github.com/AmrUser-48/d630-gentoo/actions/runs/38891651088), with published release [`d630-kernel-6.18.56-run-38891651088`](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-38891651088). Its generated config, kernel and initramfs checksums passed when reused in the latest SFS run. Do not rebuild it unless inspection or tests prove it necessary.
- That kernel workflow's initramfs construction normalizes BusyBox applet symlinks to the relative target `busybox`, explicitly creates `/bin/sh` and `/bin/static-sh`, rejects absolute/dangling applet links, and checks the archive contains executable `/init` plus the 3945ABG firmware.
- Latest SFS/boot test: [run 38899622646](https://github.com/AmrUser-48/d630-gentoo/actions/runs/38899622646). It reused the existing kernel/initramfs artifact successfully and passed that artifact's checksum verification. **It did not reach SFS creation or QEMU.**

## Exact last failure and next action

Run 38899622646 failed in **Restore the encrypted saved Gentoo build root**, after the restore, mounts and chroot validation had proceeded. The last log shows `du` traversing mounted pseudo-filesystems under `/opt/gentoo/proc` (permission errors), then reporting the Gentoo tree at 6.7 GiB and exiting status 1. The restore script is run with `set -euo pipefail`, so the `du | tee` pipeline aborts the step. This is a diagnostics/mount traversal issue, not evidence of a bad encrypted snapshot or missing kernel option.

In `.github/workflows/build-d630-state-boot-bundle.yml`, change the size-report command in the restore step from:

```bash
du -sh "$GENTOO_ROOT" "$GENTOO_ROOT/var/cache/binpkgs" | tee "$RUNNER_TEMP/restored-root-size.txt"
```

to a mount-safe size check that does not walk pseudo-filesystems, e.g.:

```bash
du -shx "$GENTOO_ROOT" "$GENTOO_ROOT/var/cache/binpkgs" | tee "$RUNNER_TEMP/restored-root-size.txt"
```

Then re-run the isolated test branch. Ensure the resume path does **not** rebuild the kernel. If the restore proceeds, the planned sequence is:

1. Run `scripts/build-state-squashfs.sh /opt/gentoo "$GITHUB_WORKSPACE/output"`.
2. Preserve the restored build tree and binpkgs; build/depclean only the disposable runtime copy created by the script.
3. Check actual SquashFS size, Zstandard format, required package/runtime probes, and archive manifests.
4. QEMU-boot the **actual reused kernel + corrected initramfs + newly built SFS**. Required serial milestones: finds `/d630-gentoo/squashfs`, mounts SquashFS and OverlayFS, prints `[d630-init] Switching to Gentoo userspace`, reaches `Create a local username:`.
5. Publish the usable artifacts only after the logs prove success. QEMU success is not a claim of successful boot on the physical D630.

## Working rules

- Be direct, concise and operational; avoid noisy terminal output and long scripts when a targeted change suffices.
- Inspect current run IDs/status and relevant logs before acting. Keep source/build root and `/var/cache/binpkgs`; never depclean or aggressively prune the only copy.
- Do not equate a green source-validation workflow with a successful SFS build or boot.
- Consult Gentoo Handbook, Wiki and Forums for relevant questions, but check dates, Gentoo/eBuild version, profile, OpenRC, Core 2 hardware and this tiny multi-partition SFS/initramfs use case. Documentation can be obsolete or assume a conventional full installation.
- Resume phrase: **`d630tiny`**. Start by reading this checkpoint, checking the latest run state, then fix the mount-safe `du` step and continue from the SFS build—no unnecessary kernel/package rebuild.
