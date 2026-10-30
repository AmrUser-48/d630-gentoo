#!/usr/bin/env bash
set -Eeuo pipefail

REPO="AmrUser-48/d630-gentoo"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/releases.md"
JSON="$(mktemp)"
trap 'rm -f "$JSON"' EXIT

command -v gh >/dev/null || { echo "GitHub CLI (gh) is required." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }

gh api --paginate "repos/$REPO/releases?per_page=100" | jq -s 'add' > "$JSON"

python3 - "$JSON" "$OUT" "$REPO" <<'PY'
import json
import sys
from datetime import datetime, timezone

source, target, repo = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    releases = json.load(handle)

def classify(tag):
    if tag.startswith("runner-state-"):
        return "Encrypted runner state"
    if tag.startswith("d630-kernel-"):
        return "Kernel bundle"
    if tag.startswith("d630-tiny-shell-"):
        return "Tiny initramfs"
    if tag.startswith("binpkgs-"):
        return "Gentoo binary packages"
    if any(word in tag for word in ("openbox", "squashfs", "rescue")):
        return "Gentoo SquashFS"
    return "Other"

releases.sort(key=lambda item: item.get("published_at") or "", reverse=True)
lines = [
    "# GitHub Releases index",
    "",
    "Generated: " + datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    "",
    "Live inventory fetched from the GitHub Releases API. Asset download counts are cumulative per asset, not unique users.",
    "",
    "| Channel | Type | Release | Published (UTC) | Assets | Total size (MiB) | Asset downloads |",
    "|---|---|---|---:|---:|---:|---:|",
]
for item in releases:
    assets = item.get("assets") or []
    size_mib = sum(asset.get("size", 0) for asset in assets) / (1024 * 1024)
    downloads = sum(asset.get("download_count", 0) for asset in assets)
    tag = item.get("tag_name", "")
    title = (item.get("name") or tag).replace("|", r"\|")
    url = item.get("html_url") or f"https://github.com/{repo}/releases/tag/{tag}"
    published = (item.get("published_at") or "")[:10] or "—"
    channel = "Draft" if item.get("draft") else ("Pre-release" if item.get("prerelease") else "Release")
    lines.append(
        f"| {channel} | {classify(tag)} | [{title}]({url})<br><code>{tag}</code> | "
        f"{published} | {len(assets)} | {size_mib:.1f} | {downloads} |"
    )

with open(target, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
print(f"Indexed {len(releases)} GitHub releases: {target}")
PY
