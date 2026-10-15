#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

die() { echo "save-gentoo-state: ERROR: $*" >&2; exit 2; }
REPO="${GITHUB_REPOSITORY:-AmrUser-48/d630-gentoo}"
API="https://api.github.com"
WORK=""
CURL_CONFIG=""
GH_TOKEN_FOUND=""
MODE="snapshot"
ROOT="/"

[[ "$EUID" -eq 0 ]] || die "run inside the restored Gentoo root as root"
[[ "$REPO" == "AmrUser-48/d630-gentoo" ]] || die "unexpected target repository: $REPO"

if [[ "${1:-}" == "--resume" ]]; then
  [[ $# -eq 2 ]] || die "Usage: save-gentoo-state [--resume /tmp/gentoo-state-save.XXXXXXXX]"
  MODE="resume"
  WORK="$(realpath "$2")"
  case "$WORK" in /tmp/gentoo-state-save.*) ;; *) die "refusing to resume a directory outside /tmp/gentoo-state-save.*" ;; esac
elif [[ $# -le 1 ]]; then
  ROOT="${1:-/}"
  [[ "$(realpath "$ROOT")" == "/" ]] || die "the snapshot root must be / inside the restored Gentoo environment"
else
  die "Usage: save-gentoo-state [--resume /tmp/gentoo-state-save.XXXXXXXX]"
fi

for tool in curl python3 sha256sum realpath; do
  command -v "$tool" >/dev/null || die "missing required tool: $tool"
done

if [[ "$MODE" == snapshot ]]; then
  for tool in tar zstd gpg split stat; do
    command -v "$tool" >/dev/null || die "missing required tool: $tool"
  done
else
  [[ -d "$WORK" ]] || die "resume directory does not exist: $WORK"
  [[ -s "$WORK/manifest.txt" && -s "$WORK/SHARD-SHA256SUMS" ]] ||
    die "directory has no complete manifest/checksum metadata; cannot resume this snapshot"
fi

cleanup() {
  local status=$?
  trap - EXIT
  [[ -z "$CURL_CONFIG" ]] || rm -f "$CURL_CONFIG"
  unset GH_TOKEN_FOUND GH_TOKEN GITHUB_TOKEN PASS1 PASS2
  if [[ -n "$WORK" && -d "$WORK" ]]; then
    if (( status == 0 )); then
      rm -rf -- "$WORK"
    elif [[ -s "$WORK/manifest.txt" && -s "$WORK/SHARD-SHA256SUMS" ]] &&
         compgen -G "$WORK/gentoo-rootfs.tar.zst.gpg.part-*" >/dev/null; then
      echo "Encrypted snapshot preserved at: $WORK" >&2
      echo "Retry using this SAME command (no new snapshot will be created):" >&2
      echo "  save-gentoo-state --resume '$WORK'" >&2
    else
      echo "Snapshot failed before a resumable archive was complete; temporary data: $WORK" >&2
      echo "Inspect it before removing it; a new save may be required." >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

# Prefer explicitly supplied credentials, then the active gh CLI session.
# Never print tokens; the curl config is mode 0600 and removed on exit.
resolve_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    GH_TOKEN_FOUND="$GITHUB_TOKEN"
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    GH_TOKEN_FOUND="$GH_TOKEN"
  elif command -v gh >/dev/null 2>&1; then
    GH_TOKEN_FOUND="$(gh auth token --hostname github.com 2>/dev/null || true)"
  fi

  # Compatibility fallback for older runner images without a working gh command.
  if [[ -z "$GH_TOKEN_FOUND" ]]; then
    local auth_file
    for auth_file in "${GH_HOSTS_FILE:-}" "$HOME/.config/gh/hosts.yml" \
        /root/.config/gh/hosts.yml /home/runner/.config/gh/hosts.yml /home/gentoo/.config/gh/hosts.yml; do
      [[ -n "$auth_file" && -s "$auth_file" ]] || continue
      GH_TOKEN_FOUND="$(python3 - "$auth_file" <<'PYTOKEN'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'(?m)^github\.com:[ \t]*\r?\n((?:[ \t]+[^\r\n]*(?:\r?\n|$))*)', text)
if m:
    token = re.search(r'(?m)^[ \\t]+(?:oauth_token|token):[ \\t]*([^\\s#]+)', m.group(1))
    if token:
        value = token.group(1).strip().strip("\\\"'").strip()
        if value:
            print(value)
PYTOKEN
)"
      [[ -n "$GH_TOKEN_FOUND" ]] && break
    done
  fi
  [[ -n "$GH_TOKEN_FOUND" ]] || die "no GitHub token found; run gh auth login or provide GH_TOKEN/GITHUB_TOKEN with release Contents: write permission"
}
write_curl_config() {
  CURL_CONFIG="$WORK/curl-auth.conf"
  printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/vnd.github+json"\nheader = "X-GitHub-Api-Version: 2022-11-28"\n' "$GH_TOKEN_FOUND" > "$CURL_CONFIG"
  chmod 0600 "$CURL_CONFIG"
  curl --config "$CURL_CONFIG" --fail --silent --show-error "$API/repos/$REPO" -o "$WORK/repository.json" ||
    die "GitHub token cannot access $REPO"
  python3 - "$WORK/repository.json" "$REPO" <<'PY'
import json, sys
repo = json.load(open(sys.argv[1], encoding="utf-8"))
if repo.get("full_name", "").lower() != sys.argv[2].lower():
    raise SystemExit("GitHub API returned a different repository.")
PY
}

# Validate local state and idempotently publish or finish publishing that state.
# This is the only publication/recovery implementation; --resume never re-tars.
publish_snapshot() {
  local tag release_id upload_url draft_state name expected_size asset_state
  local -a parts part_names
  [[ -s "$WORK/manifest.txt" && -s "$WORK/SHARD-SHA256SUMS" ]] || die "snapshot manifest/checksums are missing"
  grep -Fxq 'Archive format: gpg-aes256-encrypted-zstd-tar' "$WORK/manifest.txt" ||
    die "manifest archive format is not supported by this restore workflow"
  tag="$(sed -n 's/^Tag: //p' "$WORK/manifest.txt" | head -n 1)"
  [[ "$tag" =~ ^runner-state-[0-9]{8}T[0-9]{6}Z$ ]] || die "invalid state tag in manifest: $tag"

  shopt -s nullglob
  parts=( "$WORK"/gentoo-rootfs.tar.zst.gpg.part-* )
  shopt -u nullglob
  (( ${#parts[@]} > 0 )) || die "no encrypted archive chunks found in $WORK"
  part_names=()
  for asset in "${parts[@]}"; do
    name="$(basename "$asset")"
    [[ "$name" =~ ^gentoo-rootfs\.tar\.zst\.gpg\.part-[0-9]{3,}$ ]] || die "invalid archive chunk name: $name"
    (( $(stat -c '%s' "$asset") < 2000000000 )) || die "chunk exceeds GitHub release asset limit: $name"
    part_names+=("$name")
  done
  python3 - "$WORK/SHARD-SHA256SUMS" "${part_names[@]}" <<'PY'
import sys
checksum_file, *parts = sys.argv[1:]
actual = []
for line in open(checksum_file, encoding="utf-8"):
    fields = line.split()
    if len(fields) >= 2:
        name = fields[1].removeprefix("*")
        if len(fields[0]) != 64 or any(c not in "0123456789abcdefABCDEF" for c in fields[0]):
            raise SystemExit("Invalid SHA-256 entry in SHARD-SHA256SUMS")
        actual.append(name)
if sorted(actual) != sorted(parts) or len(actual) != len(set(actual)):
    raise SystemExit("SHARD-SHA256SUMS does not name exactly the local archive chunks")
PY
  (cd "$WORK" && sha256sum --check SHARD-SHA256SUMS) || die "local chunk checksum verification failed"

  : > "$WORK/expected-assets.tsv"
  for asset in "${parts[@]}" "$WORK/manifest.txt" "$WORK/SHARD-SHA256SUMS"; do
    printf '%s\t%s\t%s\n' "$(basename "$asset")" "$(stat -c '%s' "$asset")" "$(sha256sum "$asset" | awk '{print $1}')" >> "$WORK/expected-assets.tsv"
  done

  # Recreate release metadata from the manifest. This still works if the network
  # failed before GitHub returned the original create-release response.
  python3 - "$tag" <<'PY' > "$WORK/release.json.tmp"
import json, sys
tag = sys.argv[1]
data = {
    "tag_name": tag,
    "name": "Gentoo runner state (encrypted) — " + tag,
    "body": "Full Gentoo runner snapshot. Archive chunks are GPG AES-256 encrypted. Configure the Actions secret STATE_ENCRYPTION_PASSPHRASE to restore this state.",
    "draft": True,
    "prerelease": True,
    "generate_release_notes": False,
}
json.dump(data, sys.stdout)
PY
  mv "$WORK/release.json.tmp" "$WORK/release.json"

  # Search paginated release listings. The tag endpoint can return 404 for
  # draft releases in some token/repository configurations; never treat a
  # failed lookup as proof that no release exists.
  local found=false page count
  page=1
  while :; do
    curl --config "$CURL_CONFIG" --fail --silent --show-error \
      "$API/repos/$REPO/releases?per_page=100&page=$page" \
      -o "$WORK/releases-page.json" ||
      die "cannot list releases; refusing to create a duplicate release"
    count="$(python3 - "$WORK/releases-page.json" <<'PYCOUNT'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(data, list):
    raise SystemExit("GitHub releases API returned an unexpected response.")
print(len(data))
PYCOUNT
)"
    if python3 - "$WORK/releases-page.json" "$tag" > "$WORK/current-release.json" <<'PYSELECT'
import json, sys
releases = json.load(open(sys.argv[1], encoding="utf-8"))
tag = sys.argv[2]
matches = [r for r in releases if r.get("tag_name") == tag]
if matches:
    # Prefer the draft with the most uploaded assets, then the newest ID.
    matches.sort(key=lambda r: (len(r.get("assets", [])), bool(r.get("draft")), int(r.get("id", 0))), reverse=True)
    print(json.dumps(matches[0]))
PYSELECT
    then
      if [[ -s "$WORK/current-release.json" ]]; then
        found=true
        echo "Reusing existing draft release for $tag."
        break
      fi
    fi
    (( count < 100 )) && break
    ((page += 1))
  done

  if [[ "$found" != true ]]; then
    echo "No matching draft release found; creating one."
    if curl --config "$CURL_CONFIG" --fail --silent --show-error \
        -H 'Content-Type: application/json' -X POST --data-binary "@$WORK/release.json" \
        "$API/repos/$REPO/releases" -o "$WORK/current-release.json"; then
      found=true
    else
      # The server may have created the release even if the response was lost.
      echo "Create response failed; rechecking release list before any retry." >&2
      page=1
      while :; do
        curl --config "$CURL_CONFIG" --fail --silent --show-error \
          "$API/repos/$REPO/releases?per_page=100&page=$page" \
          -o "$WORK/releases-page.json" ||
          die "cannot verify release creation; encrypted snapshot remains resumable"
        count="$(python3 - "$WORK/releases-page.json" <<'PYCOUNT2'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(data, list):
    raise SystemExit("GitHub releases API returned an unexpected response.")
print(len(data))
PYCOUNT2
)"
        if python3 - "$WORK/releases-page.json" "$tag" > "$WORK/current-release.json" <<'PYSELECT2'
import json, sys
releases = json.load(open(sys.argv[1], encoding="utf-8"))
matches = [r for r in releases if r.get("tag_name") == sys.argv[2]]
if matches:
    matches.sort(key=lambda r: (len(r.get("assets", [])), bool(r.get("draft")), int(r.get("id", 0))), reverse=True)
    print(json.dumps(matches[0]))
PYSELECT2
        then
          if [[ -s "$WORK/current-release.json" ]]; then
            found=true
            break
          fi
        fi
        (( count < 100 )) && break
        ((page += 1))
      done
    fi
  fi
  [[ "$found" == true && -s "$WORK/current-release.json" ]] ||
    die "could not verify a draft release for $tag; refusing to create duplicates"

  upload_url="$(python3 - "$WORK/current-release.json" "$tag" "$REPO" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
tag, repo = sys.argv[2:]
if r.get("tag_name") != tag:
    raise SystemExit("Remote release tag does not match the local snapshot.")
expected_name = "Gentoo runner state (encrypted) — " + tag
if r.get("name") != expected_name:
    raise SystemExit("The tag already belongs to a release with a different name; refusing to modify it.")
release_id = r.get("id")
u = r.get("upload_url", "").split("{", 1)[0]
if not isinstance(release_id, int) or u != f"https://uploads.github.com/repos/{repo}/releases/{release_id}/assets":
    raise SystemExit("Remote release ID/upload URL failed validation.")
print(u)
PY
  )" || die "remote release cannot be verified; encrypted snapshot is preserved"
  release_id="$(python3 - "$WORK/current-release.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["id"])
PY
  )"

  for asset in "${parts[@]}" "$WORK/manifest.txt" "$WORK/SHARD-SHA256SUMS"; do
    name="$(basename "$asset")"
    expected_size="$(stat -c '%s' "$asset")"
    curl --config "$CURL_CONFIG" --fail --silent --show-error \
      "$API/repos/$REPO/releases/$release_id" -o "$WORK/current-release.json" ||
      die "cannot inspect release before uploading $name"
    asset_state="$(python3 - "$WORK/current-release.json" "$name" "$expected_size" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
name, expected = sys.argv[2], int(sys.argv[3])
for a in r.get("assets", []):
    if a.get("name") == name:
        if a.get("state") != "uploaded" or int(a.get("size", -1)) != expected:
            raise SystemExit("Remote asset name exists with unexpected state/size: " + name)
        print("present")
        break
else:
    print("missing")
PY
    )" || die "remote asset verification failed for $name"
    if [[ "$asset_state" == missing ]]; then
      echo "Uploading $name"
      if ! curl --config "$CURL_CONFIG" --fail --silent --show-error --retry 3 --retry-all-errors \
          -H 'Content-Type: application/octet-stream' -X POST --data-binary "@$asset" \
          "$upload_url?name=$name" -o "$WORK/upload-response.json"; then
        echo "Upload response was unsuccessful/ambiguous for $name; checking remote state." >&2
      fi
      curl --config "$CURL_CONFIG" --fail --silent --show-error \
        "$API/repos/$REPO/releases/$release_id" -o "$WORK/current-release.json" ||
        die "cannot verify upload of $name; rerun save-gentoo-state --resume '$WORK'"
      asset_state="$(python3 - "$WORK/current-release.json" "$name" "$expected_size" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
name, expected = sys.argv[2], int(sys.argv[3])
for a in r.get("assets", []):
    if a.get("name") == name:
        if a.get("state") != "uploaded" or int(a.get("size", -1)) != expected:
            raise SystemExit("Remote asset exists but state/size is wrong: " + name)
        print("present")
        break
else:
    print("missing")
PY
      )" || die "upload verification failed for $name"
      [[ "$asset_state" == present ]] || die "upload of $name did not complete; rerun save-gentoo-state --resume '$WORK'"
    else
      echo "Already uploaded and verified: $name"
    fi
  done

  curl --config "$CURL_CONFIG" --fail --silent --show-error \
    "$API/repos/$REPO/releases/$release_id" -o "$WORK/current-release.json" || die "cannot verify final release assets"
  python3 - "$WORK/current-release.json" "$WORK/expected-assets.tsv" "$tag" "$REPO" <<'PY' || die "remote assets failed final verification; the snapshot can be resumed"
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {}
for line in open(sys.argv[2], encoding="utf-8"):
    name, size, digest = line.rstrip("\n").split("\t")
    expected[name] = (int(size), digest.lower())
assets_list = r.get("assets", [])
assets = {a.get("name"): a for a in assets_list}
if len(assets) != len(assets_list) or set(assets) != set(expected):
    raise SystemExit("Remote release assets do not exactly match this snapshot.")
for name, (size, digest) in expected.items():
    a = assets[name]
    if a.get("state") != "uploaded" or int(a.get("size", -1)) != size:
        raise SystemExit("Remote asset failed state/size verification: " + name)
    remote_digest = a.get("digest")
    if remote_digest and remote_digest.lower() != "sha256:" + digest:
        raise SystemExit("Remote asset digest mismatch: " + name)
if r.get("tag_name") != sys.argv[3] or r.get("name") != "Gentoo runner state (encrypted) — " + sys.argv[3]:
    raise SystemExit("Remote release identity changed during upload.")
PY

  draft_state="$(python3 - "$WORK/current-release.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
print("true" if r.get("draft") is True else "false")
PY
  )"
  if [[ "$draft_state" == true ]]; then
    printf '{"draft":false}\n' > "$WORK/publish.json"
    echo "All assets verified; publishing release $tag."
    if ! curl --config "$CURL_CONFIG" --fail --silent --show-error --retry 3 \
        -H 'Content-Type: application/json' -X PATCH --data-binary "@$WORK/publish.json" \
        "$API/repos/$REPO/releases/$release_id" -o "$WORK/published-release.json"; then
      echo "Publish response was interrupted; checking final release state." >&2
    fi
  fi

  curl --config "$CURL_CONFIG" --fail --silent --show-error \
    "$API/repos/$REPO/releases/$release_id" -o "$WORK/published-release.json" ||
    die "cannot verify final publication; rerun save-gentoo-state --resume '$WORK'"
  RELEASE_URL="$(python3 - "$WORK/published-release.json" "$WORK/expected-assets.tsv" "$tag" "$REPO" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {}
for line in open(sys.argv[2], encoding="utf-8"):
    name, size, digest = line.rstrip("\n").split("\t")
    expected[name] = (int(size), digest.lower())
assets_list = r.get("assets", [])
assets = {a.get("name"): a for a in assets_list}
if r.get("draft") is not False:
    raise SystemExit("Release is not published yet.")
if r.get("html_url") != f"https://github.com/{sys.argv[4]}/releases/tag/{sys.argv[3]}":
    raise SystemExit("Published release URL does not match the expected tag.")
if r.get("tag_name") != sys.argv[3] or r.get("name") != "Gentoo runner state (encrypted) — " + sys.argv[3]:
    raise SystemExit("Published release identity mismatch.")
if len(assets) != len(assets_list) or set(assets) != set(expected):
    raise SystemExit("Published release asset list does not match this snapshot.")
for name, (size, digest) in expected.items():
    a = assets[name]
    if a.get("state") != "uploaded" or int(a.get("size", -1)) != size:
        raise SystemExit("Published asset failed state/size verification: " + name)
    remote_digest = a.get("digest")
    if remote_digest and remote_digest.lower() != "sha256:" + digest:
        raise SystemExit("Published asset digest mismatch: " + name)
print(r["html_url"])
PY
  )" || die "snapshot release could not be verified as published"
  echo "Encrypted state published and verified: $RELEASE_URL"
  echo "The same passphrase must be stored in Actions secret STATE_ENCRYPTION_PASSPHRASE."
}

if [[ "$MODE" == resume ]]; then
  resolve_token
  write_curl_config
  publish_snapshot
  exit 0
fi

# Drop the old second helper from the filesystem before capturing the root.
rm -f /usr/local/sbin/publish-pending-state-save
[[ -r /dev/tty && -w /dev/tty ]] || die "run from an interactive SSH terminal so the encryption passphrase can be entered"
resolve_token
printf 'Enter the SAME passphrase stored as repository Actions secret STATE_ENCRYPTION_PASSPHRASE. Do not use your GitHub token as this passphrase.\n' > /dev/tty
IFS= read -r -s -p "Snapshot encryption passphrase (minimum 16 characters): " PASS1 </dev/tty
printf '\n' > /dev/tty
IFS= read -r -s -p "Repeat passphrase: " PASS2 </dev/tty
printf '\n' > /dev/tty
[[ "${#PASS1}" -ge 16 ]] || die "passphrase must be at least 16 characters"
[[ "$PASS1" == "$PASS2" ]] || die "passphrases do not match"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gentoo-state-save.XXXXXXXX")"
write_curl_config

TAG="runner-state-$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$WORK/gentoo-rootfs.tar.zst.gpg"
PART_PREFIX="$WORK/gentoo-rootfs.tar.zst.gpg.part-"
printf 'Tag: %s\nRepo: %s\nStarted UTC: %s\n' "$TAG" "$REPO" "$(date -u +%FT%TZ)"

# The root tar -> zstd -> GPG stream never writes an unencrypted archive to disk.
exec 3<<<"$PASS1"
unset PASS1 PASS2
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
cat > "$WORK/manifest.txt" <<EOF_MANIFEST
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
EOF_MANIFEST

echo "Verifying local encrypted chunks..."
(cd "$WORK" && sha256sum --check SHARD-SHA256SUMS)
echo "Starting single-command publish/verification for $TAG..."
publish_snapshot
