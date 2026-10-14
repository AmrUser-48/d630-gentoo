#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

die() { echo "publish-pending-state: ERROR: $*" >&2; exit 2; }
REPO="${GITHUB_REPOSITORY:-AmrUser-48/d630-gentoo}"
[[ "$EUID" -eq 0 ]] || die "run as root inside the restored Gentoo environment"
[[ "$REPO" == "AmrUser-48/d630-gentoo" ]] || die "unexpected target repository: $REPO"
[[ $# -eq 1 ]] || die "Usage: $0 /tmp/gentoo-state-save.XXXXXXXX"

WORK="$(realpath "$1")"
case "$WORK" in
  /tmp/gentoo-state-save.*) ;;
  *) die "refusing to process a directory outside /tmp/gentoo-state-save.*" ;;
esac
[[ -s "$WORK/release-response.json" && -s "$WORK/manifest.txt" && -s "$WORK/SHARD-SHA256SUMS" ]] ||
  die "directory does not contain the pending encrypted snapshot metadata"
for tool in curl python3 sha256sum; do
  command -v "$tool" >/dev/null || die "missing required tool: $tool"
done

# Parse every embedded Python heredoc before doing expensive or destructive work.
python3 - "$0" <<'PY'
from pathlib import Path
import re, sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
snippets = re.findall(r"<<'PY'[ \t]*\r?\n(.*?)^[ \t]*PY[ \t]*$", source, re.S | re.M)
if not snippets:
    raise SystemExit("No embedded Python heredocs found in " + sys.argv[1])
for index, snippet in enumerate(snippets, start=1):
    compile(snippet, f"{sys.argv[1]}:python-heredoc-{index}", "exec")
PY

# Only encrypted chunks are uploaded. Never print or put the token in a command argument.
GH_TOKEN_FOUND=""
for auth_file in "${GH_HOSTS_FILE:-}" "$HOME/.config/gh/hosts.yml" /root/.config/gh/hosts.yml /home/runner/.config/gh/hosts.yml /home/gentoo/.config/gh/hosts.yml; do
  [[ -n "$auth_file" && -s "$auth_file" ]] || continue
  GH_TOKEN_FOUND="$(python3 - "$auth_file" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'(?m)^github\.com:[ \t]*\r?\n((?:[ \t]+[^\r\n]*(?:\r?\n|$))*)', text)
if m:
    token = re.search(r'(?m)^[ \t]+(?:oauth_token|token):[ \t]*([^\s#]+)', m.group(1))
    if token:
        value = token.group(1).strip().strip('"').strip("'").strip()
        if value:
            print(value)
PY
)"
  [[ -n "$GH_TOKEN_FOUND" ]] && break
done
if [[ -z "$GH_TOKEN_FOUND" ]]; then
  GH_TOKEN_FOUND="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
fi
[[ -n "$GH_TOKEN_FOUND" ]] || die "no GitHub API token found in gh hosts.yml or GH_TOKEN/GITHUB_TOKEN"

CURL_CONFIG="$WORK/curl-auth.conf"
printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/vnd.github+json"\nheader = "X-GitHub-Api-Version: 2022-11-28"\n' "$GH_TOKEN_FOUND" > "$CURL_CONFIG"
chmod 0600 "$CURL_CONFIG"
cleanup() {
  status=$?
  rm -f "$CURL_CONFIG"
  unset GH_TOKEN_FOUND GH_TOKEN GITHUB_TOKEN
  if (( status == 0 )); then
    echo "Pending encrypted files remain at: $WORK"
    echo "Remove that directory after confirming the release is present."
  else
    echo "Encrypted snapshot files remain at: $WORK" >&2
    echo "The temporary token header file was removed." >&2
  fi
}
trap cleanup EXIT

# Verify checksums before making any release changes.
(cd "$WORK" && sha256sum --check SHARD-SHA256SUMS)

RELEASE_ID="$(python3 - "$WORK/release-response.json" <<'PY'
import json, re, sys
data=json.load(open(sys.argv[1], encoding="utf-8"))
tag=data.get("tag_name", "")
rid=data.get("id", "")
if not re.fullmatch(r"runner-state-[0-9]{8}T[0-9]{6}Z", tag):
    raise SystemExit("Unexpected pending release tag.")
if not isinstance(rid, int) or data.get("draft") is not True:
    raise SystemExit("Pending release is not a draft or has no numeric ID.")
print(rid)
PY
)" || die "invalid pending release response"
TAG="$(python3 - "$WORK/release-response.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["tag_name"])
PY
)"
API="https://api.github.com"
curl --config "$CURL_CONFIG" --fail --silent --show-error \
  "$API/repos/$REPO/releases/$RELEASE_ID" -o "$WORK/current-release.json"
UPLOAD_URL="$(python3 - "$WORK/current-release.json" "$TAG" "$REPO" <<'PY'
import json, re, sys
r=json.load(open(sys.argv[1], encoding="utf-8"))
tag, repo=sys.argv[2:]
if r.get("tag_name") != tag:
    raise SystemExit("Remote release tag does not match the pending snapshot.")
u=r.get("upload_url", "").split("{",1)[0]
if not u.startswith(f"https://uploads.github.com/repos/{repo}/releases/{r.get('id')}/assets"):
    raise SystemExit("Remote upload URL is invalid.")
print(u)
PY
)" || die "the pending release cannot be verified"

shopt -s nullglob
PARTS=("$WORK"/gentoo-rootfs.tar.zst.gpg.part-*)
shopt -u nullglob
(( ${#PARTS[@]} > 0 )) || die "no encrypted snapshot chunks found"
ASSETS=("${PARTS[@]}" "$WORK/manifest.txt" "$WORK/SHARD-SHA256SUMS")

echo "Resuming uploads for $TAG (release ID $RELEASE_ID); no new snapshot will be created."
# Refresh the release after each upload so retries skip assets already uploaded successfully.
for asset in "${ASSETS[@]}"; do
  name="$(basename "$asset")"
  expected_size="$(stat -c '%s' "$asset")"
  curl --config "$CURL_CONFIG" --fail --silent --show-error \
    "$API/repos/$REPO/releases/$RELEASE_ID" -o "$WORK/current-release.json"
  exists="$(python3 - "$WORK/current-release.json" "$name" "$expected_size" <<'PY'
import json, sys
r=json.load(open(sys.argv[1], encoding="utf-8"))
name, expected=sys.argv[2], int(sys.argv[3])
for a in r.get("assets", []):
    if a.get("name") == name:
        if a.get("state") != "uploaded" or int(a.get("size",-1)) != expected:
            raise SystemExit("Existing asset has an unexpected size or upload state: "+name)
        print("yes")
        break
else:
    print("no")
PY
)" || die "an existing remote asset does not match $name"
  if [[ "$exists" == yes ]]; then
    echo "Already uploaded and verified: $name"
    continue
  fi
  echo "Uploading encrypted snapshot asset: $name"
  curl --config "$CURL_CONFIG" --fail --silent --show-error --retry 3 --retry-all-errors \
    -H 'Content-Type: application/octet-stream' -X POST \
    --data-binary "@$asset" "$UPLOAD_URL?name=$name" -o "$WORK/upload-response.json"
done

curl --config "$CURL_CONFIG" --fail --silent --show-error \
  "$API/repos/$REPO/releases/$RELEASE_ID" -o "$WORK/verify-release.json"
python3 - "$WORK/verify-release.json" "${ASSETS[@]}" <<'PY' || die "remote encrypted assets failed name/size verification"
import json, os, sys
r=json.load(open(sys.argv[1], encoding="utf-8"))
expected={os.path.basename(p):os.path.getsize(p) for p in sys.argv[2:]}
assets={a.get("name"):a for a in r.get("assets", [])}
for name,size in expected.items():
    a=assets.get(name)
    if not a or a.get("state") != "uploaded" or int(a.get("size",-1)) != size:
        raise SystemExit("Missing or invalid encrypted asset: "+name)
PY

printf '{"draft":false}\n' > "$WORK/publish.json"
curl --config "$CURL_CONFIG" --fail --silent --show-error --retry 3 \
  -H 'Content-Type: application/json' -X PATCH --data-binary "@$WORK/publish.json" \
  "$API/repos/$REPO/releases/$RELEASE_ID" -o "$WORK/published-release.json"
RELEASE_URL="$(python3 - "$WORK/published-release.json" "$TAG" "$REPO" <<'PY'
import json, sys
r=json.load(open(sys.argv[1], encoding="utf-8"))
tag, repo=sys.argv[2:]
expected=f"https://github.com/{repo}/releases/tag/{tag}"
if r.get("draft") is not False or r.get("html_url") != expected:
    raise SystemExit("Release was not published at the expected tagged URL.")
print(expected)
PY
)" || die "assets were uploaded but final publication could not be verified"
echo "Encrypted state release is published: $RELEASE_URL"
