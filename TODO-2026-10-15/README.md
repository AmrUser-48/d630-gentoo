# TODO — Gentoo Core2 minimal SquashFS
**Date:** 2026-10-15  
**Repository:** `AmrUser-48/d630-gentoo`

## Goal for today

Continue the existing Gentoo Stage 3 rebuild optimized for the Intel Core 2 system, then assemble and test a minimal SquashFS system using the rebuilt binary packages.

## 1. Restore and continue the existing build

- Restore the saved runner state: `runner-state-20261015T100327Z`.
- The restored state already contains packages partly or fully recompiled for Core 2. **Continue from this state; do not start a fresh Stage 3 build.**
- Recover the remaining rebuild queue (approximately 100 packages) from the restored state, Portage logs, and available build records.
- Determine which packages have already completed successfully and resume only the remaining work. Do not guess or replace the queue with a generic package set.
- Keep the generated binary packages from the existing state.

## 2. Finish the minimal system packages

After resuming the Stage 3 system-package rebuild, compile these target packages:

1. `x11-base/xorg-server` / required Xorg components
2. `x11-wm/openbox`
3. `app-misc/fbterm`
4. `app-misc/mc`

Resolve dependencies through the existing Gentoo configuration and continue in practical batches. Preserve successful binary packages so they can be reused.

## 3. Save and collect binary packages

- Collect the Core 2 binary packages from the restored state's Portage binpkg cache.
- Verify that packages needed by the minimal system and their dependencies are available.
- Keep the binpkgs as build outputs; do not discard them while trimming the filesystem.

## 4. Build and test the minimal SquashFS

- Construct a trimmed root filesystem from the existing build state and its binary packages.
- First test target: **Mesa + Xorg + Openbox**, with the runtime dependencies needed to run them.
- Include `fbterm` and `mc` in the minimal system.
- Produce the SquashFS image and test the minimal environment today.

## Constraints

- Preserve and reuse the saved Core 2 build state.
- Do not recompile packages that are already successfully rebuilt unless a dependency or configuration change requires it.
- Do not launch a new generic build or invent a replacement package list.
- Prioritize actual compilation, binpkg preservation, image creation, and testing over verbose terminal output.
