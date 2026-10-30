# GitHub Releases index

Snapshot: **2026-10-31 UTC**. Source: GitHub Releases API. Asset download totals are sums of per-asset GitHub counters, not unique users.

The repository has **39 releases** in this snapshot: 10 selected for retention and 29 cleanup candidates.

## Retention set

- Tiny OS: `d630-tiny-shell-40818375822`.
- Gentoo Openbox SquashFS: `d630-gentoo-openbox-2026.10.29`.
- Kernel bundles: newest `41134237939`, plus the three bundles pinned by current workflows: `40922514538`, `40813428910` and `39509781896`.
- Gentoo binary packages: `binpkgs-39507549274`, containing the Mesa-related package set used by current build workflows.
- Encrypted runner states: newest two, `runner-state-20261030T214009Z` and `runner-state-20261030T010021Z`, plus `runner-state-20261015T153832Z`, which is the explicit default input of `.github/workflows/build-d630-state-boot-bundle.yml`.

Older kernel builds and saved stages remain retained when active workflows pin their exact tags; their configs and checksums are not interchangeable with newer artifacts.

## Cleanup policy

The 29 entries marked **CLEANUP CANDIDATE** are older duplicate Tiny builds, unpinned kernel bundles, older encrypted runner snapshots, an old binary-package snapshot and the obsolete rescue SFS.

Review the dry run:

    ./scripts/prune-obsolete-releases.sh

Actual deletion requires an authenticated GitHub CLI session and an explicit typed confirmation:

    ./scripts/prune-obsolete-releases.sh --apply

The script searches active source and workflow references before deleting. It preserves the ten releases listed above, deletes candidate release assets and associated Git tags, and then regenerates this index. It does not delete Actions run artifacts or historical repository-root `output/` files.

**No release deletion has been run as part of this update.** The connected GitHub repository interface used for source changes does not expose a release-delete operation; the script is ready for an authenticated maintainer to run.

## Full inventory

| Channel | Type | Release | Published (UTC) | Assets | Total size (MiB) | Asset downloads | Status |
|---|---|---|---:|---:|---:|---:|---:|
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 41134237939](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-41134237939)<br><code>d630-kernel-6.18.56-run-41134237939</code> | 2026-10-30 | 10 | 12.1 | 9 | KEEP |
| Pre-release | Encrypted runner state | [Gentoo runner state (encrypted) — runner-state-20261030T214009Z](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261030T214009Z)<br><code>runner-state-20261030T214009Z</code> | 2026-10-30 | 7 | 8264.5 | 8 | KEEP |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 40983813237](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-40983813237)<br><code>d630-kernel-6.18.56-run-40983813237</code> | 2026-10-30 | 10 | 12.1 | 8 | CLEANUP CANDIDATE |
| Pre-release | Encrypted runner state | [Gentoo runner state (encrypted) — runner-state-20261030T010021Z](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261030T010021Z)<br><code>runner-state-20261030T010021Z</code> | 2026-10-30 | 5 | 4804.2 | 6 | KEEP |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 40936606243](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-40936606243)<br><code>d630-kernel-6.18.56-run-40936606243</code> | 2026-10-29 | 10 | 12.1 | 10 | CLEANUP CANDIDATE |
| Release | Gentoo SquashFS | [D630 Gentoo Openbox live 2026-10-29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-gentoo-openbox-2026.10.29)<br><code>d630-gentoo-openbox-2026.10.29</code> | 2026-10-29 | 5 | 208.6 | 19 | KEEP |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 40922514538](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-40922514538)<br><code>d630-kernel-6.18.56-run-40922514538</code> | 2026-10-29 | 10 | 12.1 | 113 | KEEP |
| Pre-release | Encrypted runner state | [Gentoo runner state (encrypted) — runner-state-20261029T172846Z](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261029T172846Z)<br><code>runner-state-20261029T172846Z</code> | 2026-10-29 | 5 | 4278.6 | 22 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 64](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818375822)<br><code>d630-tiny-shell-40818375822</code> | 2026-10-29 | 26 | 47.3 | 13 | KEEP |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 63](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40818082122)<br><code>d630-tiny-shell-40818082122</code> | 2026-10-29 | 26 | 47.3 | 5 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 62](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40814321663)<br><code>d630-tiny-shell-40814321663</code> | 2026-10-29 | 26 | 47.3 | 14 | CLEANUP CANDIDATE |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 40813428910](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-40813428910)<br><code>d630-kernel-6.18.56-run-40813428910</code> | 2026-10-29 | 10 | 12.1 | 29 | KEEP |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 61](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40809730342)<br><code>d630-tiny-shell-40809730342</code> | 2026-10-29 | 26 | 47.3 | 13 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 55](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40790886368)<br><code>d630-tiny-shell-40790886368</code> | 2026-10-29 | 25 | 40.3 | 8 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 54](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40773717605)<br><code>d630-tiny-shell-40773717605</code> | 2026-10-28 | 25 | 40.3 | 5 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 52](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40773361301)<br><code>d630-tiny-shell-40773361301</code> | 2026-10-28 | 25 | 40.3 | 5 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 48](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40772359334)<br><code>d630-tiny-shell-40772359334</code> | 2026-10-28 | 25 | 40.3 | 25 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 45](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40771411042)<br><code>d630-tiny-shell-40771411042</code> | 2026-10-28 | 25 | 40.3 | 5 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 40](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40770198254)<br><code>d630-tiny-shell-40770198254</code> | 2026-10-28 | 25 | 40.3 | 9 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 36](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40769082621)<br><code>d630-tiny-shell-40769082621</code> | 2026-10-28 | 25 | 40.3 | 6 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 31](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40767637091)<br><code>d630-tiny-shell-40767637091</code> | 2026-10-28 | 25 | 40.3 | 6 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 30](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40766757234)<br><code>d630-tiny-shell-40766757234</code> | 2026-10-28 | 25 | 40.3 | 6 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 29](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40749510674)<br><code>d630-tiny-shell-40749510674</code> | 2026-10-28 | 25 | 40.3 | 9 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 27](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40741562544)<br><code>d630-tiny-shell-40741562544</code> | 2026-10-28 | 23 | 35.7 | 15 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux single initramfs / run 23](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40735737041)<br><code>d630-tiny-shell-40735737041</code> | 2026-10-28 | 22 | 34.5 | 13 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux shell + setup tools / run 22](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40732664609)<br><code>d630-tiny-shell-40732664609</code> | 2026-10-28 | 32 | 54.3 | 22 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux shell + internet tools / run 13](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40721490410)<br><code>d630-tiny-shell-40721490410</code> | 2026-10-28 | 20 | 28.9 | 14 | CLEANUP CANDIDATE |
| Release | Tiny initramfs | [D630 Tiny Linux standalone shell / run 7](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-tiny-shell-40639215550)<br><code>d630-tiny-shell-40639215550</code> | 2026-10-28 | 12 | 11.5 | 24 | CLEANUP CANDIDATE |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 39509781896](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-39509781896)<br><code>d630-kernel-6.18.56-run-39509781896</code> | 2026-10-20 | 10 | 12.1 | 195 | KEEP |
| Pre-release | Gentoo binary packages | [D630 Core 2 binary packages — run 39507549274](https://github.com/AmrUser-48/d630-gentoo/releases/tag/binpkgs-39507549274)<br><code>binpkgs-39507549274</code> | 2026-10-20 | 3 | 1019.4 | 94 | KEEP |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 39499284729](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-39499284729)<br><code>d630-kernel-6.18.56-run-39499284729</code> | 2026-10-20 | 10 | 12.1 | 8 | CLEANUP CANDIDATE |
| Pre-release | Gentoo binary packages | [D630 Core 2 binary packages — run 39497302427](https://github.com/AmrUser-48/d630-gentoo/releases/tag/binpkgs-39497302427)<br><code>binpkgs-39497302427</code> | 2026-10-20 | 3 | 1019.4 | 4 | CLEANUP CANDIDATE |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — run 38891651088](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-run-38891651088)<br><code>d630-kernel-6.18.56-run-38891651088</code> | 2026-10-16 | 10 | 12.1 | 18 | CLEANUP CANDIDATE |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — build 16](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-build-16)<br><code>d630-kernel-6.18.56-build-16</code> | 2026-10-15 | 10 | 12.1 | 8 | CLEANUP CANDIDATE |
| Release | Gentoo SquashFS | [D630 Minimal Rescue SFS](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-rescue-20261015-1734)<br><code>d630-rescue-20261015-1734</code> | 2026-10-15 | 2 | 113.8 | 5 | CLEANUP CANDIDATE |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — build 15](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-build-15)<br><code>d630-kernel-6.18.56-build-15</code> | 2026-10-15 | 10 | 12.1 | 10 | CLEANUP CANDIDATE |
| Pre-release | Encrypted runner state | [Gentoo runner state (encrypted) — runner-state-20261015T153832Z](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261015T153832Z)<br><code>runner-state-20261015T153832Z</code> | 2026-10-15 | 5 | 4020.2 | 50 | KEEP |
| Pre-release | Kernel bundle | [D630 Gentoo kernel bundle 6.18.56 — build 14](https://github.com/AmrUser-48/d630-gentoo/releases/tag/d630-kernel-6.18.56-build-14)<br><code>d630-kernel-6.18.56-build-14</code> | 2026-10-15 | 10 | 12.1 | 8 | CLEANUP CANDIDATE |
| Pre-release | Encrypted runner state | [Gentoo runner state (encrypted) — runner-state-20261015T100327Z](https://github.com/AmrUser-48/d630-gentoo/releases/tag/runner-state-20261015T100327Z)<br><code>runner-state-20261015T100327Z</code> | 2026-10-15 | 5 | 3937.3 | 20 | CLEANUP CANDIDATE |
