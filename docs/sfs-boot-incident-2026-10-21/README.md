# SFS boot-failure investigation and recovery log

**Date:** 2026-10-21  
**Repository branch:** `test/sfs-initrd-20261016`  
**Scope:** Existing D630 Gentoo graphics runtime (Mesa + Xorg + Openbox); no fresh Stage 3 build.  
**Status:** The source fix is committed and static workflow validation passed. The rebuilt SquashFS and QEMU boot test are not yet confirmed.

## 1. User-visible failure

The machine reaches SysVinit's runlevel selection and then has no persistent process left to keep that runlevel alive:

```text
Enter runlevel: 3
INIT: Entering runlevel: 3
INIT: no more processes left in this runlevel
```

The requirement is a working console login after boot, not merely a successful initramfs mount or a successful `switch_root`. Preserve the existing graphics/Mesa package set while fixing the init handoff.

## 2. Repository and image investigation

The newest relevant state-based SFS workflow before this fix was [run 8, ID 39497302427](https://github.com/AmrUser-48/d630-gentoo/actions/runs/39497302427), dated 2026-10-20. It failed in the **Build runtime SquashFS from the restored Core 2 state** step, before the packer reached `mksquashfs`. The strict symlink audit found 16 dangling/unreadable links, including optional GCC static-archive aliases, Vim documentation links, man-page aliases, and command aliases such as `/usr/bin/vi` and `/usr/bin/lua`. The QEMU step was skipped, so that run did not validate a new bootable SFS.

The only actual `.sfs` asset found in the public GitHub Releases list was [`d630-rescue.sfs` in release `d630-rescue-20261015-1734`](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-rescue-20261015-1734), size 119,361,536 bytes, published 2026-10-15. This is the separately named rescue image; it was **not** treated as the target graphics/Mesa image.

The state-based workflow restores the saved Gentoo tree from release tag `runner-state-20261015T153832Z` into `/opt/gentoo`, preserves its binary-package cache, creates a separate runtime copy, and emits the new image at `output/squashfs`. The active job uses the existing kernel/initramfs artifact rather than rebuilding the kernel.

## 3. Init diagnosis

This image uses **SysVinit as PID 1 and OpenRC for service/runlevel work**. The generated `/etc/inittab` already selected runlevel 3 and delegated startup to OpenRC, but its generated template omitted SysVinit-managed virtual-console `respawn` entries. It also tried to use an OpenRC `agetty.tty1` service for tty1. Those are competing console-supervision arrangements: when SysVinit is PID 1, inittab should supervise each getty with `respawn`, or the image must deliberately switch to OpenRC's init/getty supervision model. The build now explicitly uses the SysVinit/inittab model.

The diagnosis matches the Gentoo Handbook's description of `/etc/inittab`: it dispatches `sysinit`, `boot`, selects the default runlevel, and then defines virtual consoles using entries such as `c1:12345:respawn:/sbin/agetty 38400 tty1 linux`. OpenRC's own SysVinit template has the same contract, and its agetty guide says not to use the OpenRC getty supervisor when that terminal is already supervised elsewhere.

References:
- [Gentoo Handbook — Initscripts / how init works](https://wiki.gentoo.org/wiki/Handbook:AMD64/Full/Working/cs)
- [OpenRC's SysVinit `inittab` template](https://github.com/OpenRC/openrc/blob/master/support/sysvinit/inittab)
- [OpenRC agetty guide](https://github.com/OpenRC/openrc/blob/master/agetty-guide.md)

## 4. Changes committed

Commit: [`b644f423` — Fix SysVinit console respawn and validate SFS boot](https://github.com/AmrUser-48/d630-gentoo/commit/b644f423f300d62be75bf235dcaef2c3e7341e30)

The following files changed on `test/sfs-initrd-20261016`:

### `scripts/build-state-squashfs.sh`

- Generates `/etc/inittab` with default runlevel 3 and the OpenRC `sysinit`, `boot`, and runlevel handoff entries.
- Adds SysVinit `respawn` entries for `tty1` through `tty6`, running `/sbin/agetty`.
- Checks that `agetty` and the login executable exist.
- Removes a stale/custom OpenRC `agetty.tty1` service and default-runlevel link, so tty1 has one supervisor.
- Validates the required inittab entries and first-boot service before packing.
- Inspects `etc/inittab` from the **packed SquashFS itself**, not just from the temporary runtime root.

### `scripts/build-squashfs-inplace.sh`

- Keeps the global runtime symlink audit strict.
- Before the audit, removes symlink aliases to build-only `.a`/`.la` files and dangling links limited to known optional, pruned categories: `/usr/share/man`, `/usr/share/vim`, and a short list of optional command aliases (`HEAD`, `GET`, `POST`, `vi`, `view`, `ex`, `lua`, `luac`).
- Records the optional cleanup separately, then fails normally if the full runtime symlink audit still finds broken links. This does not disable the audit or broadly ignore dangling runtime links.

### `.github/workflows/build-d630-state-boot-bundle.yml`

- Installs `python3-pexpect` for serial-console interaction in the QEMU boot test.
- Extends the QEMU timeout.
- Boots the actual kernel + initramfs + generated SquashFS; answers the first-boot account/password prompts; waits for runlevel 3; and fails if the log contains `INIT: no more processes left in this runlevel`.
- Retains the earlier checks for SquashFS discovery and successful `switch_root`.

### Documentation

- `README.md` now states which process supervises console gettys for the SysVinit/OpenRC arrangement.
- `TODO-2026-10-15/README.md` now describes PID 1 as SysVinit, documents inittab getty respawning, and removes the conflicting recommendation to enable the OpenRC `agetty.tty1` service in this build.

No local SFS file was manually extracted or patched. These are build-pipeline changes intended to create a new SFS from the preserved Gentoo state; the original saved build state and binpkgs remain the inputs.

## 5. Validation status

- [Source/workflow validation run 410](https://github.com/AmrUser-48/d630-gentoo/actions/runs/39507549236): **passed**, including the repository source checks and GitHub Actions workflow lint.
- [State-based SFS workflow run 9](https://github.com/AmrUser-48/d630-gentoo/actions/runs/39507549274): at the last status check, the run had successfully checked out the commit, passed source validation and state/passphrase checks, verified/staged the existing kernel and initramfs artifact, and restored the saved Gentoo build root. The SquashFS build and QEMU boot test were still pending. No artifact had been published by that run at the time of checking.

**Do not call the problem fixed until run 9 finishes successfully and `QEMU-BOOT-TEST.log` proves that the generated image reaches runlevel 3 without the empty-runlevel error.** The next action is to inspect that workflow's final build output and boot log. If a step fails, fix the first failing step based on its log; do not switch to the old rescue SFS or start a fresh Stage 3 build.
