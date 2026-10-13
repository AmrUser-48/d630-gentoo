#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-/opt/gentoo}"
OUT="${2:?Usage: snapshot-gentoo-session.sh <gentoo-root> <output-directory>}"
CONFIG="$OUT/config/etc-portage"
STATE="$OUT/state"

[[ -d "$ROOT/etc/portage" ]] || {
  echo "Portage configuration not found under $ROOT/etc/portage" >&2
  exit 1
}
mkdir -p "$CONFIG" "$STATE"

# Capture configuration files, not the whole chroot. Redact suspicious
# credential-like lines before this snapshot is placed in a public Release.
for item in "$ROOT"/etc/portage/*; do
  [[ -e "$item" || -L "$item" ]] || continue
  base="${item##*/}"
  case "$base" in
    make.conf|make.profile|package.*|repos.conf|profile|env|sets|package-sets|dispatch-conf.conf|binrepos.conf)
      sudo cp -a "$item" "$CONFIG/$base" 2>/dev/null || true
      ;;
  esac
done

# Preserve the installed package selection, which is different from the list
# of packages emitted into PKGDIR during this session.
if [[ -d "$ROOT/var/db/pkg" ]]; then
  sudo find "$ROOT/var/db/pkg" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' |
    LC_ALL=C sort > "$STATE/installed-packages.txt"
else
  : > "$STATE/installed-packages.txt"
fi

for rel in var/lib/portage/world var/lib/portage/world_sets etc/portage/world; do
  if [[ -f "$ROOT/$rel" ]]; then
    mkdir -p "$STATE/world-files/$(dirname "$rel")"
    sudo cp "$ROOT/$rel" "$STATE/world-files/$rel"
  fi
done

{
  echo "Captured UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "GitHub Actions run ID: ${GITHUB_RUN_ID:-unknown}"
  echo "Git commit: ${GITHUB_SHA:-unknown}"
  echo "Gentoo rootfs: $ROOT"
  echo "Target: amd64, glibc, OpenRC Stage 3"
  echo "Target CPU flags in repository: -O2 -pipe -march=core2 -mtune=core2"
  echo "Important: this is a chroot sharing the Ubuntu runner kernel; this snapshot does not mean a D630 kernel has been built."
  if [[ -L "$ROOT/etc/portage/make.profile" ]]; then
    printf 'make.profile link: %s\n' "$(readlink "$ROOT/etc/portage/make.profile")"
  elif [[ -e "$ROOT/etc/portage/make.profile" ]]; then
    echo "make.profile exists but is not a symlink."
  fi
} > "$STATE/SNAPSHOT-README.txt"

{
  echo "=== Host runner (not the D630 target) ==="
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  uname -a
  echo
  echo "--- CPU ---"
  lscpu 2>/dev/null || true
  echo
  echo "--- Memory ---"
  free -h 2>/dev/null || true
  echo
  echo "--- Swap ---"
  swapon --show 2>/dev/null || true
  echo
  echo "--- Filesystems ---"
  df -h "$ROOT" / 2>/dev/null || true
  echo
  echo "--- Active compilation processes ---"
  ps -eo pid,ppid,etime,%cpu,%mem,args 2>/dev/null |
    grep -E '[e]merge|[n]inja|[c]make|[c]c1|[l]ld|[l]lvm' || true
} > "$STATE/runner-host.txt"

# Record the effective values from inside Gentoo rather than assuming that
# checked-in defaults survived all runtime edits.
{
  for key in ACCEPT_KEYWORDS CFLAGS CXXFLAGS FFLAGS FCFLAGS RUSTFLAGS MAKEOPTS EMERGE_DEFAULT_OPTS FEATURES PKGDIR PORT_LOGDIR USE VIDEO_CARDS INPUT_DEVICES LLVM_TARGETS; do
    value="$(sudo chroot "$ROOT" /bin/bash -lc "portageq envvar $key" 2>/dev/null || true)"
    printf '%s=%s\n' "$key" "$value"
  done
} > "$STATE/portage-env.txt"

sudo chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --info' \
  > "$STATE/emerge-info.txt" 2>&1 || true

{
  echo "PKGDIR contents at capture time:"
  if [[ -d "$ROOT/var/cache/binpkgs" ]]; then
    sudo find "$ROOT/var/cache/binpkgs" -type f \
      \( -name '*.gpkg.tar' -o -name '*.tbz2' \) \
      -printf '%P\t%s bytes\n' | LC_ALL=C sort
  fi
} > "$STATE/binpkg-inventory.txt"

# Redact whole lines with credential-like names or values in config and reports.
# The snapshot is a reference for a later session, not an automatically applied
# replacement for the repository's canonical configuration.
sudo find "$OUT/config" "$STATE" -type f -size -5M \
  -exec sed -E -i \
    -e '/(password|passphrase|token|secret|api[_-]?key|access[_-]?key|authorization|client[_-]?secret|bearer)/I s@.*@# [redacted sensitive-looking setting line]@' \
    -e 's~((https?|ftp|rsync)://)[^/@[:space:]]+@([^/[:space:]]+)~\1\3~g' {} + \
  2>/dev/null || true

cat > "$STATE/README.txt" <<'EOF'
SESSION SNAPSHOT
================
This is a redacted reference snapshot of the live Gentoo chroot and its runner.
The configuration here may include manual settings made during the session.
It is not blindly copied over /etc/portage on the next run; the checked-in
config/portage files remain the canonical startup configuration.
Use installed-packages.txt and emerge-info.txt to diagnose package selection.
The host runner's kernel is NOT a kernel built for the Dell D630.
EOF

sudo chown -R "$(id -u):$(id -g)" "$OUT"
find "$OUT" -type f -exec chmod 0644 {} +
find "$OUT" -type d -exec chmod 0755 {} +
echo "Session snapshot written to $OUT"
