#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

die() { echo "save-runner-state: ERROR: $*" >&2; exit 2; }
REPO="${GITHUB_REPOSITORY:-AmrUser-48/d630-gentoo}"
ROOT="${1:-/}"
[[ "$EUID" -eq 0 ]] || die "run inside the restored root as root"
[[ "$REPO" == "AmrUser-48/d630-gentoo" ]] || die "unexpected target repository: $REPO"
[[ "$(realpath "$ROOT")" == "/" ]] || die "the snapshot root must be / inside the restored Gentoo environment"

for tool in tar zstd gpg split sha256sum gh python3 realpath; do
  command -v "$tool" >/dev/null || die "missing required tool: $tool"
done
[[ -r /dev/tty && -w /dev/tty ]] || die "run from an interactive SSH terminal so GPG can ask for the archive passphrase"

# Prefer the durable GitHub CLI credential in hosts.yml, but never print it.
GH_TOKEN_FOUND=""
for auth_file in "${GH_HOSTS_FILE:-}" "$HOME/.config/gh/hosts.yml" /root/.config/gh/hosts.yml /home/runner/.config/gh/hosts.yml /home/gentoo/.config/gh/hosts.yml; do
  [[ -n "$auth_file" && -s "$auth_file" ]] || continue
  GH_TOKEN_FOUND="$(python3 - "$auth_file" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'(?ms)^github\.com:\s*\n((?:^[ \t].*(?:\n|$))*)', text)
if not m:
    raise SystemExit(0)
token = re.search(r'(?m)^[ \t]+(?:oauth_token|token):[ \t]*([^\s#]+)', m.group(1))
if token:
    value = token.group(1).strip().strip("\"'").strip()
    if value:
        print(value)
PY
)"
  [[ -n "$GH_TOKEN_FOUND" ]] && break
done
if [[ -z "$GH_TOKEN_FOUND" ]]; then
  GH_TOKEN_FOUND="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
fi
[[ -n "$GH_TOKEN_FOUND" ]] || die "no GitHub token found; expected gh auth in hosts.yml or an existing GH_TOKEN/GITHUB_TOKEN environment variable"
# Validate the token without exporting it to the snapshot/compression processes.
GH_TOKEN="$GH_TOKEN_FOUND" gh api "repos/$REPO" --jq '.full_name' >/dev/null ||
  die "GitHub token cannot access $REPO"

printf 'Archive passphrase must be saved OUTSIDE this runner and entered as the repository Actions secret STATE_ENCRYPTION_PASSPHRASE. Do not use your GitHub token as the passphrase.\n' > /dev/tty
IFS= read -r -s -p "New archive passphrase (minimum 16 characters): " PASS1 </dev/tty
printf '\n' > /dev/tty
IFS= read -r -s -p "Repeat passphrase: " PASS2 </dev/tty
printf '\n' > /dev/tty
[[ "${#PASS1}" -ge 16 ]] || die "passphrase must be at least 16 characters"
[[ "$PASS1" == "$PASS2" ]] || die "passphrases do not match"
unset PASS2

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gentoo-state-save.XXXXXXXX")"
cleanup() {
  status=$?
  if (( status == 0 )); then
    rm -rf "$WORK"
  else
    echo "Encrypted snapshot files (if created) remain at: $WORK" >&2
  fi
}
trap cleanup EXIT

TAG="runner-state-$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$WORK/gentoo-rootfs.tar.zst.gpg"
PART_PREFIX="$WORK/gentoo-rootfs.tar.zst.gpg.part-"
printf 'Tag: %s\nRepo: %s\nStarted UTC: %s\n' "$TAG" "$REPO" "$(date -u +%FT%TZ)"

# FD 3 is used only for the secret. The root tar -> zstd stream goes to GPG
# directly, so no unencrypted tar or .tar.zst archive is written to disk.
exec 3<<<"$PASS1"
unset PASS1
tar --create --file=- --directory="$ROOT" --numeric-owner --acls --xattrs --xattrs-include='*' --sparse --one-file-system \
  --exclude='./proc' --exclude='./proc/*' \
  --exclude='./sys' --exclude='./sys/*' \
  --exclude='./dev' --exclude='./dev/*' \
  --exclude='./run' --exclude='./run/*' \
  --exclude='./tmp' --exclude='./tmp/*' \
  --exclude='./mnt' --exclude='./mnt/*' \
  --exclude='./media' --exclude='./media/*' \
  --exclude='./var/tmp/portage' --exclude='./var/tmp/portage/*' \
  . |
  zstd -T0 -3 --check -c |
  gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 --symmetric \
      --cipher-algo AES256 --s2k-digest-algo SHA512 --output "$ARCHIVE"
exec 3<&-
[[ -s "$ARCHIVE" ]] || die "encrypted archive is empty"
split -b 1800M -d -a 3 "$ARCHIVE" "$PART_PREFIX"
shopt -s nullglob
PARTS=( "$PART_PREFIX"* )
shopt -u nullglob
(( ${#PARTS[@]} > 0 )) || die "no encrypted archive chunks were produced"
for part in "${PARTS[@]}"; do
  (( $(stat -c '%s' "$part") < 2000000000 )) || die "chunk exceeds the 2 GB release-asset safety limit: $(basename "$part")"
done

(
  cd "$WORK"
  sha256sum gentoo-rootfs.tar.zst.gpg.part-* > SHARD-SHA256SUMS
)
cat > "$WORK/manifest.txt" <<EOF
Gentoo runner state snapshot
Tag: $TAG
Captured UTC: $(date -u +%FT%TZ)
Archive format: gpg-aes256-encrypted-zstd-tar
Encryption: GPG symmetric AES-256; passphrase is NOT stored in the release.
Restore workflow secret required: STATE_ENCRYPTION_PASSPHRASE
Chunk prefix: gentoo-rootfs.tar.zst.gpg.part-
Chunks: ${#PARTS[@]}
The complete root archive is encrypted before being written to release chunks.
Excluded runtime paths: /proc /sys /dev /run /tmp /mnt /media /var/tmp/portage
The token/configuration files inside the root are contained only inside the encrypted archive.
EOF

echo "Verifying local chunk checksums..."
(cd "$WORK" && sha256sum --check SHARD-SHA256SUMS)

echo "Publishing encrypted state as $TAG..."
GH_TOKEN="$GH_TOKEN_FOUND" gh release create "$TAG" "${PARTS[@]}" "$WORK/manifest.txt" "$WORK/SHARD-SHA256SUMS" \
  --repo "$REPO" \
  --title "Gentoo runner state (encrypted) — $(date -u +%F)" \
  --notes "Full restored Gentoo runner snapshot. Archive chunks are GPG AES-256 encrypted; set the Actions secret STATE_ENCRYPTION_PASSPHRASE to the passphrase used during capture before restoring." \
  --prerelease

GH_TOKEN="$GH_TOKEN_FOUND" gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name' | sort > "$WORK/uploaded-assets.txt"
(
  printf '%s\n' "$(basename "$WORK/manifest.txt")" "$(basename "$WORK/SHARD-SHA256SUMS")"
  printf '%s\n' "${PARTS[@]##*/}"
) | sort > "$WORK/expected-assets.txt"
diff -u "$WORK/expected-assets.txt" "$WORK/uploaded-assets.txt" || die "release was created but the asset list did not verify"

unset GH_TOKEN_FOUND
echo "Encrypted state published: https://github.com/$REPO/releases/tag/$TAG"
echo "Now save the same passphrase as repository Actions secret STATE_ENCRYPTION_PASSPHRASE."
