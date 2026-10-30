#!/usr/bin/env bash
set -Eeuo pipefail

REPO="AmrUser-48/d630-gentoo"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE="dry-run"
case "${1:-}" in
  ""|--dry-run) ;;
  --apply) MODE="apply" ;;
  *) echo "Usage: $0 [--dry-run|--apply]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Too many arguments." >&2; exit 2; }

command -v grep >/dev/null || { echo "grep is required." >&2; exit 1; }

KEEP_TAGS=(
  "runner-state-20261030T214009Z"
  "runner-state-20261030T010021Z"
  "runner-state-20261015T153832Z"
  "d630-kernel-6.18.56-run-41134237939"
  "d630-kernel-6.18.56-run-40922514538"
  "d630-kernel-6.18.56-run-40813428910"
  "d630-kernel-6.18.56-run-39509781896"
  "d630-tiny-shell-40818375822"
  "d630-gentoo-openbox-2026.10.29"
  "binpkgs-39507549274"
)

DELETE_TAGS=(
  "d630-tiny-shell-40818082122"
  "d630-tiny-shell-40814321663"
  "d630-tiny-shell-40809730342"
  "d630-tiny-shell-40790886368"
  "d630-tiny-shell-40773717605"
  "d630-tiny-shell-40773361301"
  "d630-tiny-shell-40772359334"
  "d630-tiny-shell-40771411042"
  "d630-tiny-shell-40770198254"
  "d630-tiny-shell-40769082621"
  "d630-tiny-shell-40767637091"
  "d630-tiny-shell-40766757234"
  "d630-tiny-shell-40749510674"
  "d630-tiny-shell-40741562544"
  "d630-tiny-shell-40735737041"
  "d630-tiny-shell-40732664609"
  "d630-tiny-shell-40721490410"
  "d630-tiny-shell-40639215550"
  "d630-kernel-6.18.56-run-40983813237"
  "d630-kernel-6.18.56-run-40936606243"
  "d630-kernel-6.18.56-run-39499284729"
  "d630-kernel-6.18.56-run-38891651088"
  "d630-kernel-6.18.56-build-16"
  "d630-kernel-6.18.56-build-15"
  "d630-kernel-6.18.56-build-14"
  "runner-state-20261029T172846Z"
  "runner-state-20261015T100327Z"
  "binpkgs-39497302427"
  "d630-rescue-20261015-1734"
)

echo "Repository: $REPO"
echo "Retained releases: ${#KEEP_TAGS[@]}"
echo "Cleanup candidates: ${#DELETE_TAGS[@]}"
echo

# Search active source/config/workflows, not historical archive or this inventory.
for tag in "${DELETE_TAGS[@]}"; do
  matches="$(grep -RFn -- "$tag" README.md AGENTS.md llms.txt .github config d630-tiny d630-gentoo kernels scripts docs/known-issues.md 2>/dev/null \
    | grep -v -E 'scripts/(prune-obsolete-releases|update-release-index)\.sh|docs/releases\.md' || true)"
  if [[ -n "$matches" ]]; then
    echo "Refusing to delete a release referenced by active files: $tag" >&2
    echo "$matches" >&2
    exit 1
  fi
done

if [[ "$MODE" == "dry-run" ]]; then
  printf 'Would delete: %s\n' "${DELETE_TAGS[@]}"
  echo
  echo "No releases were changed. Re-run with --apply after reviewing docs/releases.md."
  exit 0
fi

command -v gh >/dev/null || { echo "GitHub CLI (gh) is required for --apply." >&2; exit 1; }
gh auth status --hostname github.com >/dev/null
for tag in "${KEEP_TAGS[@]}"; do
  gh release view "$tag" --repo "$REPO" >/dev/null
done
for tag in "${DELETE_TAGS[@]}"; do
  gh release view "$tag" --repo "$REPO" >/dev/null
done

confirm_text="DELETE ${#DELETE_TAGS[@]} RELEASES"
echo "This permanently deletes ${#DELETE_TAGS[@]} GitHub Releases, their release assets, and their associated Git tags."
read -r -p "Type $confirm_text to continue: " answer
[[ "$answer" == "$confirm_text" ]] || { echo "Cancelled."; exit 1; }

for tag in "${DELETE_TAGS[@]}"; do
  gh release view "$tag" --repo "$REPO" >/dev/null 2>&1 || { echo "Already absent; skipping $tag"; continue; }
  echo "Deleting $tag"
  gh release delete "$tag" --repo "$REPO" --cleanup-tag --yes
done

"$ROOT/scripts/update-release-index.sh"
echo "Release cleanup complete. Review and commit docs/releases.md."
