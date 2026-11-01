#!/usr/bin/env bash
set -Eeuo pipefail
die() { echo "d630-runtime-rootfs: ERROR: $*" >&2; exit 2; }
log() { echo; echo "[d630-runtime-rootfs] $*"; }

[[ "$EUID" -eq 0 ]] || die "run as root"
GH_API_AUTH_ARGS=()
if [[ -n "${GH_TOKEN:-}" ]]; then GH_API_AUTH_ARGS=(-H "Authorization: Bearer $GH_TOKEN"); fi
[[ "$RUNTIME_PROFILE" =~ ^(tiny-console|console|openbox|desktop|daily-driver|gui-initram)$ ]] || die "invalid runtime profile"
[[ -z "$BINPKG_RUN_IDS" || "$BINPKG_RUN_IDS" =~ ^[0-9,[:space:]]+$ ]] || die "binpkg_run_ids must be numeric IDs separated by commas or spaces"
[[ "$SOURCE_FALLBACK" == true || "$SOURCE_FALLBACK" == false ]] || die "SOURCE_FALLBACK must be true or false"
[[ "$RUNTIME_PROFILE" != openbox || "$SOURCE_FALLBACK" == false ]] || die "Openbox SFS is binpkg-only; SOURCE_FALLBACK must be false"
[[ -z "$KERNEL_BUNDLE_TAG" || "$KERNEL_BUNDLE_TAG" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid kernel bundle tag"
BUILD_GUI_INITRAMFS="${BUILD_GUI_INITRAMFS:-false}"
EARLY_MICROCODE_CPIO="${EARLY_MICROCODE_CPIO:-}"
[[ "$BUILD_GUI_INITRAMFS" == true || "$BUILD_GUI_INITRAMFS" == false ]] || die "BUILD_GUI_INITRAMFS must be true or false"
if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then
  [[ "$RUNTIME_PROFILE" == gui-initram ]] || die "GUI initramfs output requires RUNTIME_PROFILE=gui-initram"
  [[ -s "$EARLY_MICROCODE_CPIO" ]] || die "EARLY_MICROCODE_CPIO must name the verified kernel microcode archive"
  for tool in cpio zstd; do command -v "$tool" >/dev/null || die "required host tool missing: $tool"; done
elif [[ "$RUNTIME_PROFILE" == gui-initram ]]; then
  die "RUNTIME_PROFILE=gui-initram requires BUILD_GUI_INITRAMFS=true"
fi
LOCAL_RELEASE_ASSETS_DIR="${LOCAL_RELEASE_ASSETS_DIR:-}"
LOCAL_BINPKG_ARCHIVE="${LOCAL_BINPKG_ARCHIVE:-}"
if [[ -z "$BINPKG_RUN_IDS" && -z "$LOCAL_RELEASE_ASSETS_DIR" && -z "$LOCAL_BINPKG_ARCHIVE" && "$SOURCE_FALLBACK" != true ]]; then
  die "no binpkgs supplied; provide a package source or enable SOURCE_FALLBACK"
fi
if [[ -n "$LOCAL_RELEASE_ASSETS_DIR" ]]; then
  [[ -d "$LOCAL_RELEASE_ASSETS_DIR" ]] || die "prepared assets directory not found: $LOCAL_RELEASE_ASSETS_DIR"
  [[ -s "$LOCAL_RELEASE_ASSETS_DIR/SHA256SUMS" ]] || die "prepared assets have no SHA256SUMS"
fi
if [[ -n "$LOCAL_BINPKG_ARCHIVE" ]]; then
  [[ -s "$LOCAL_BINPKG_ARCHIVE" ]] || die "local binpkg archive not found: $LOCAL_BINPKG_ARCHIVE"
  zstd -t "$LOCAL_BINPKG_ARCHIVE" >/dev/null || die "local binpkg archive is not valid Zstandard data"
fi
if [[ "$RUNTIME_PROFILE" == openbox && -z "$BINPKG_RUN_IDS" && -z "$LOCAL_RELEASE_ASSETS_DIR" && -z "$LOCAL_BINPKG_ARCHIVE" ]]; then
  die "the openbox SquashFS profile requires an imported binary-package release containing Mesa"
fi

IDS="$(printf '%s' "$BINPKG_RUN_IDS" | tr ',' ' ')"
ROOT="$RUNNER_TEMP/d630-runtime-root"
WORK="$RUNNER_TEMP/d630-runtime-work"
OUT="${OUTPUT_DIR:-$GITHUB_WORKSPACE/output}"
mkdir -p "$WORK" "$OUT"
rm -rf "$ROOT" "$WORK/stage3"
mkdir -p "$WORK/stage3"
cleanup() {
  for mp in run sys proc dev; do
    mountpoint -q "$ROOT/$mp" 2>/dev/null && umount -R "$ROOT/$mp" 2>/dev/null || true
  done
  rm -rf "$ROOT"
}
trap cleanup EXIT

printf 'Profile: %s\nBinpkg releases: %s\nPrepared assets directory: %s\nLocal package archive: %s\nSource fallback: %s\nKernel bundle tag: %s\n' \
  "$RUNTIME_PROFILE" "$IDS" "$LOCAL_RELEASE_ASSETS_DIR" "$LOCAL_BINPKG_ARCHIVE" "$SOURCE_FALLBACK" "$KERNEL_BUNDLE_TAG" > "$OUT/BUILD-INPUTS.txt"

log "Fetch and verify official Gentoo amd64 OpenRC Stage 3"
BASE='https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc'
curl -fsSL --retry 3 "$BASE/latest-stage3-amd64-openrc.txt" -o "$WORK/stage3/latest.txt"
LINE="$(grep -E '^stage3-amd64-openrc-[0-9]{8}T[0-9]{6}Z\.tar\.xz [0-9]+$' "$WORK/stage3/latest.txt" | head -n 1)"
[[ -n "$LINE" ]] || die "could not parse Stage 3 manifest"
ARCHIVE="$(echo "$LINE" | awk '{print $1}')"
SIZE="$(echo "$LINE" | awk '{print $2}')"
curl -fL --retry 3 "$BASE/$ARCHIVE" -o "$WORK/stage3/$ARCHIVE"
[[ "$(stat -c '%s' "$WORK/stage3/$ARCHIVE")" == "$SIZE" ]] || die "Stage 3 size mismatch"
curl -fsSL --retry 3 "$BASE/$ARCHIVE.sha256" -o "$WORK/stage3/checksums"
SHA="$(grep -Eo '[[:xdigit:]]{64}' "$WORK/stage3/checksums" | head -n 1)"
[[ "$SHA" =~ ^[[:xdigit:]]{64}$ ]] || die "Stage 3 checksum not found"
printf '%s  %s\n' "$SHA" "$WORK/stage3/$ARCHIVE" | sha256sum --check -
mkdir -p "$ROOT"
tar -xpf "$WORK/stage3/$ARCHIVE" -C "$ROOT" --numeric-owner --xattrs --xattrs-include='*' --same-permissions
printf 'Archive: %s\nSHA256: %s\n' "$ARCHIVE" "$SHA" > "$OUT/STAGE3-MANIFEST.txt"
PORTAGE_GID="$(awk -F: '$1 == "portage" { print $3; exit }' "$ROOT/etc/group")"
[[ "$PORTAGE_GID" =~ ^[0-9]+$ ]] || die "Stage 3 has no portage group"

log "Install Core 2 Portage configuration"
mkdir -p "$ROOT/etc/portage/package-sets" "$ROOT/etc/portage/profile/package.use.force" \
  "$ROOT/etc/portage/binrepos.conf" "$ROOT/etc/portage/repos.conf" \
  "$ROOT/etc/bash/bashrc.d" "$ROOT/etc/env.d" "$ROOT/etc/X11/xorg.conf.d" \
  "$ROOT/usr/local/sbin" "$ROOT/var/cache/binpkgs" "$ROOT/var/log/portage" \
  "$ROOT/var/tmp/portage" "$ROOT/dev" "$ROOT/proc" "$ROOT/sys" "$ROOT/run"
chown "0:$PORTAGE_GID" "$ROOT/var/tmp/portage"
chmod 2775 "$ROOT/var/tmp/portage"
if [[ -f "$ROOT/etc/portage/package.use" ]]; then mv "$ROOT/etc/portage/package.use" "$ROOT/etc/portage/package.use.stage3"; fi
mkdir -p "$ROOT/etc/portage/package.use"
install -m 0644 "$GITHUB_WORKSPACE/config/portage/make.conf" "$ROOT/etc/portage/make.conf"
install -m 0644 "$GITHUB_WORKSPACE/config/portage/profile/package.use.force" "$ROOT/etc/portage/profile/package.use.force/zz-d630-llvm"
install -m 0644 "$GITHUB_WORKSPACE/config/bash/bashrc.d/10-portage-ask.sh" "$ROOT/etc/bash/bashrc.d/10-portage-ask.sh"
install -m 0644 "$GITHUB_WORKSPACE/config/locale.gen" "$ROOT/etc/locale.gen"
install -m 0644 "$GITHUB_WORKSPACE/config/env.d/02locale" "$ROOT/etc/env.d/02locale"
install -m 0644 "$GITHUB_WORKSPACE/d630-gentoo/config/xorg/99-synaptics.conf" "$ROOT/etc/X11/xorg.conf.d/99-synaptics.conf"
rm -rf "$ROOT/etc/portage/package.accept_keywords" "$ROOT/etc/portage/package.keywords"
mkdir -p "$ROOT/etc/portage/package.accept_keywords"
cp -a "$GITHUB_WORKSPACE/config/portage/package.accept_keywords/." "$ROOT/etc/portage/package.accept_keywords/"
cp -a "$GITHUB_WORKSPACE/config/portage/package.use/." "$ROOT/etc/portage/package.use/"
mkdir -p "$ROOT/etc/portage/env"
install -m 0644 "$GITHUB_WORKSPACE/config/portage/package.env" "$ROOT/etc/portage/package.env"
cp -a "$GITHUB_WORKSPACE/config/portage/env/." "$ROOT/etc/portage/env/"
cp -a "$GITHUB_WORKSPACE/config/portage/binrepos.conf/." "$ROOT/etc/portage/binrepos.conf/"
cp -a "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/." "$ROOT/etc/portage/package-sets/"
install -m 0755 "$GITHUB_WORKSPACE/scripts/gentoo-build-set" "$ROOT/usr/local/sbin/gentoo-build-set"
if [[ ! -f "$ROOT/etc/portage/repos.conf/gentoo.conf" ]]; then
  cat > "$ROOT/etc/portage/repos.conf/gentoo.conf" <<'EOF'
[gentoo]
location = /var/db/repos/gentoo
sync-type = rsync
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
auto-sync = yes
EOF
fi
rm -f "$ROOT/etc/resolv.conf"
cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"
CPUS="$(nproc)"
MEM_KIB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
if (( CPUS >= 4 && MEM_KIB >= 9000000 )); then JOBS=8
elif (( CPUS >= 4 && MEM_KIB >= 6000000 )); then JOBS=6
elif (( CPUS >= 2 && MEM_KIB >= 3500000 )); then JOBS=4
else JOBS=1
fi
sed -i '/^MAKEOPTS=/d;/^NINJAOPTS=/d' "$ROOT/etc/portage/make.conf"
printf 'MAKEOPTS="-j%s"\nNINJAOPTS="-j%s"\n' "$JOBS" "$JOBS" >> "$ROOT/etc/portage/make.conf"
printf 'Compiler flags: -O2 -pipe -march=core2 -mtune=core2\nMAKEOPTS: -j%s\n' "$JOBS" > "$OUT/PORTAGE-TARGET.txt"

for MP in dev proc sys run; do mount --rbind "/$MP" "$ROOT/$MP"; mount --make-rslave "$ROOT/$MP"; done
log "Sync Portage and initialize signed binpkg trust"
if ! chroot "$ROOT" /bin/bash -lc 'emerge-webrsync --quiet' |& tee "$OUT/portage-bootstrap.log"; then
  chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --sync --quiet' |& tee -a "$OUT/portage-bootstrap.log"
fi
chroot "$ROOT" /bin/bash -lc 'getuto' |& tee -a "$OUT/portage-bootstrap.log"

if [[ "$RUNTIME_PROFILE" == tiny-console || "$RUNTIME_PROFILE" == console || "$RUNTIME_PROFILE" == openbox || "$RUNTIME_PROFILE" == desktop || "$RUNTIME_PROFILE" == daily-driver ]]; then
  log "Fetch GURU ebuilds required by the lf package"
  mkdir -p "$ROOT/var/db/repos"
  cat > "$ROOT/etc/portage/repos.conf/guru.conf" <<'EOF'
[guru]
location = /var/db/repos/guru
sync-type = git
sync-uri = https://github.com/gentoo-mirror/guru.git
auto-sync = no
EOF
  git clone --depth 1 https://github.com/gentoo-mirror/guru.git "$ROOT/var/db/repos/guru"
fi

log "Install the pinned SDL2 scrcpy 3.3.4 local ebuild"
LOCAL_REPO="$ROOT/var/db/repos/d630-local"
mkdir -p "$LOCAL_REPO/metadata" "$LOCAL_REPO/app-mobilephone/scrcpy"
cat > "$LOCAL_REPO/metadata/layout.conf" <<'EOF'
repo-name = d630-local
masters = gentoo
thin-manifests = true
EOF
cat > "$ROOT/etc/portage/repos.conf/d630-local.conf" <<'EOF'
[d630-local]
location = /var/db/repos/d630-local
priority = 1000
auto-sync = no
EOF
install -m 0644 "$GITHUB_WORKSPACE/config/portage/local-overlay/app-mobilephone/scrcpy/scrcpy-3.3.4.ebuild" \
  "$LOCAL_REPO/app-mobilephone/scrcpy/scrcpy-3.3.4.ebuild"
chroot "$ROOT" /bin/bash -lc \
  'ebuild /var/db/repos/d630-local/app-mobilephone/scrcpy/scrcpy-3.3.4.ebuild manifest' \
  |& tee "$OUT/scrcpy-manifest.log"

log "Import binary package assets"
if [[ -n "$LOCAL_RELEASE_ASSETS_DIR" ]]; then
  log "Verify recovered publisher artifact and import package shards"
  (cd "$LOCAL_RELEASE_ASSETS_DIR" && sha256sum --check SHA256SUMS) |& tee "$OUT/PREPARED-ASSET-CHECK.log"
  shopt -s nullglob
  PARTS=( "$LOCAL_RELEASE_ASSETS_DIR"/binpkgs-part-*.tar.zst )
  shopt -u nullglob
  (( ${#PARTS[@]} > 0 )) || die "prepared assets have no binpkgs-part-*.tar.zst package shards"
  for PART in "${PARTS[@]}"; do
    tar --use-compress-program=unzstd -xf "$PART" -C "$ROOT/var/cache/binpkgs"
  done
  printf 'Source: prepared Actions artifact\nPackage shards: %s\n' "${#PARTS[@]}" > "$OUT/LOCAL-BINPKG-IMPORT.txt"
elif [[ -n "$LOCAL_BINPKG_ARCHIVE" ]]; then
  log "Import local binpkg bundle: $LOCAL_BINPKG_ARCHIVE"
  tar --use-compress-program=unzstd -xf "$LOCAL_BINPKG_ARCHIVE" -C "$ROOT/var/cache/binpkgs"
  PKG_COUNT="$(find "$ROOT/var/cache/binpkgs" -type f \( -name '*.gpkg.tar' -o -name '*.tbz2' \) | wc -l)"
  (( PKG_COUNT > 0 )) || die "local binpkg archive contained no .gpkg.tar/.tbz2 files under PKGDIR"
  printf 'Source: local archive\nArchive: %s\nPackage files: %s\n' "$LOCAL_BINPKG_ARCHIVE" "$PKG_COUNT" > "$OUT/LOCAL-BINPKG-IMPORT.txt"
else
  for ID in $IDS; do
    curl -fsSL --retry 3 "${GH_API_AUTH_ARGS[@]}" -H 'Accept: application/vnd.github+json' \
      "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/binpkgs-$ID" -o "$WORK/release.json"
    python3 - "$WORK/release.json" "$WORK/assets.tsv" <<'PY'
import json, re, sys
with open(sys.argv[1], encoding="utf-8") as f: r = json.load(f)
assets = r.get("assets", [])
sums = [a for a in assets if a.get("name") == "SHA256SUMS"]
parts = sorted((a for a in assets if re.fullmatch(r"binpkgs-part-\d+\.tar\.zst", a.get("name", ""))), key=lambda a:a["name"])
if not sums or not parts: raise SystemExit("Release has no SHA256SUMS or binary package shards.")
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write("SHA256SUMS\t" + sums[0]["browser_download_url"] + "\n")
    for a in parts: f.write(a["name"] + "\t" + a["browser_download_url"] + "\n")
PY
    SUMS_URL="$(awk -F '\t' '$1=="SHA256SUMS"{print $2; exit}' "$WORK/assets.tsv")"
    curl -fsSL --retry 3 "$SUMS_URL" -o "$WORK/SHA256SUMS"
    while IFS=$'\t' read -r NAME URL; do
      [[ "$NAME" == SHA256SUMS ]] && continue
      curl -fL --retry 3 "$URL" -o "$WORK/$NAME"
      (cd "$WORK" && grep -F "  $NAME" SHA256SUMS | sha256sum --check)
      tar --use-compress-program=unzstd -xf "$WORK/$NAME" -C "$ROOT/var/cache/binpkgs"
      rm -f "$WORK/$NAME"
    done < "$WORK/assets.tsv"
  done
fi
chroot "$ROOT" /bin/bash -lc 'emaint binhost --fix' |& tee -a "$OUT/portage-bootstrap.log"

log "Select package atoms"
if [[ "$RUNTIME_PROFILE" == tiny-console ]]; then
  # A deliberately narrow runtime atop the official OpenRC Stage 3.
  # Keep only account/boot/package-manager essentials plus the requested tools.
  cat > "$WORK/atoms.txt" <<'EOF'
app-admin/sudo
sys-apps/openrc
sys-apps/portage
sys-apps/coreutils
sys-apps/util-linux
sys-apps/shadow
sys-apps/kmod
EOF
  cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/tiny-console.list" >> "$WORK/atoms.txt"
elif [[ "$RUNTIME_PROFILE" == gui-initram ]]; then
  cat > "$WORK/atoms.txt" <<'EOF'
app-admin/sudo
app-shells/bash
net-misc/dhcpcd
sys-apps/coreutils
sys-apps/kmod
sys-apps/openrc
sys-apps/portage
sys-apps/shadow
sys-apps/util-linux
EOF
  cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/gui-initram.list" >> "$WORK/atoms.txt"
else
  cat > "$WORK/atoms.txt" <<'EOF'
app-admin/sudo
app-shells/bash
sys-apps/openrc
sys-apps/portage
sys-apps/coreutils
sys-apps/util-linux
sys-apps/shadow
sys-apps/kmod
sys-apps/pciutils
sys-apps/usbutils
sys-apps/dbus
sys-apps/man-db
sys-auth/pambase
sys-fs/e2fsprogs
sys-fs/dosfstools
sys-fs/ntfs3g
sys-fs/btrfs-progs
sys-block/parted
sys-boot/grub
net-misc/dhcpcd
net-misc/networkmanager
net-wireless/iw
net-wireless/wpa_supplicant
net-wireless/wireless-regdb
EOF
  case "$RUNTIME_PROFILE" in
    console) cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/cli.list" >> "$WORK/atoms.txt" ;;
    openbox)
      cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/gui-initram.list" >> "$WORK/atoms.txt"
      grep -vx 'sys-apps/man-db' "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/cli.list" >> "$WORK/atoms.txt"
      cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/multimedia.list" >> "$WORK/atoms.txt"
      ;;
    desktop) cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/cli.list" "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/desktop.list" >> "$WORK/atoms.txt" ;;
    daily-driver) cat "$GITHUB_WORKSPACE/d630-gentoo/config/package-sets/daily-driver.list" >> "$WORK/atoms.txt" ;;
  esac
fi
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  sed -i '/^sys-apps\/man-db$/d' "$WORK/atoms.txt"
fi
sed -i 's/#.*$//; /^[[:space:]]*$/d' "$WORK/atoms.txt"
sort -u "$WORK/atoms.txt" -o "$WORK/atoms.txt"
if grep -Evq '^[A-Za-z0-9+_.-]+/[A-Za-z0-9+_.-]+(:[A-Za-z0-9+_.-]+)?$' "$WORK/atoms.txt"; then die "invalid package atom in selected set"; fi

if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  # Mandatory desktop and device services must resolve from imported Core 2 binpkgs.
  # Every other tool is included only if its complete dependency closure is available.
  cat > "$WORK/required-atoms.txt" <<'EOF'
app-admin/sudo
app-shells/bash
sys-apps/openrc
sys-apps/coreutils
sys-apps/util-linux
sys-apps/shadow
sys-apps/kmod
sys-apps/dbus
sys-auth/elogind
sys-auth/pambase
net-misc/dhcpcd
net-misc/networkmanager
net-wireless/wpa_supplicant
net-wireless/wireless-regdb
dev-lang/python
media-libs/mesa
media-libs/alsa-lib
media-libs/alsa-ucm-conf
media-video/pipewire
media-video/wireplumber
media-sound/alsa-utils
x11-apps/xinit
x11-base/xorg-drivers
x11-base/xorg-server
x11-terms/xterm
x11-wm/openbox
app-mobilephone/scrcpy
EOF
  sort -u "$WORK/required-atoms.txt" -o "$WORK/required-atoms.txt"
  while IFS= read -r atom; do
    grep -Fqx "$atom" "$WORK/atoms.txt" || die "required Openbox atom is absent from runtime package sets: $atom"
  done < "$WORK/required-atoms.txt"
  grep -Fvx -f "$WORK/required-atoms.txt" "$WORK/atoms.txt" > "$WORK/optional-atoms.txt" || true

  log "Preflight mandatory Openbox dependency closure from imported binpkgs"
  REQUIRED_ATOMS="$(paste -sd ' ' "$WORK/required-atoms.txt")"
  chroot "$ROOT" /bin/bash -lc \
    "emerge --ignore-default-opts --ask=n --verbose --pretend --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly $REQUIRED_ATOMS" \
    |& tee "$OUT/required-binpkg-plan.log"

  : > "$WORK/selected-optional-atoms.txt"
  : > "$OUT/BINPKG-OPTIONAL-SKIPPED.txt"
  mkdir -p "$WORK/binpkg-probes"
  while IFS= read -r atom; do
    [[ -n "$atom" ]] || continue
    probe_name="$(printf '%s' "$atom" | tr '/:' '__')"
    if chroot "$ROOT" /bin/bash -lc \
        "emerge --ignore-default-opts --ask=n --quiet --pretend --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly '$atom'" \
        > "$WORK/binpkg-probes/$probe_name.log" 2>&1; then
      printf '%s\n' "$atom" >> "$WORK/selected-optional-atoms.txt"
    else
      printf '%s\n' "$atom" >> "$OUT/BINPKG-OPTIONAL-SKIPPED.txt"
    fi
  done < "$WORK/optional-atoms.txt"

  cat "$WORK/required-atoms.txt" "$WORK/selected-optional-atoms.txt" | sort -u > "$WORK/selected-atoms.txt"
  mv -f "$WORK/selected-atoms.txt" "$WORK/atoms.txt"
  if [[ -s "$OUT/BINPKG-OPTIONAL-SKIPPED.txt" ]]; then
    log "Skipped optional packages without a complete imported binary-package closure"
    cat "$OUT/BINPKG-OPTIONAL-SKIPPED.txt"
  fi
fi

cp "$WORK/atoms.txt" "$OUT/PACKAGES.txt"
ATOMS="$(paste -sd ' ' "$WORK/atoms.txt")"
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  mesa_binpkg="$(find "$ROOT/var/cache/binpkgs/media-libs/mesa" -maxdepth 1 -type f \
    \( -name 'mesa-*.gpkg.tar' -o -name 'mesa-*.tbz2' \) -print -quit 2>/dev/null || true)"
  [[ -n "$mesa_binpkg" ]] || die "imported binary packages do not contain Mesa"
  mesa_filename="$(basename "$mesa_binpkg")"
  case "$mesa_filename" in
    *.gpkg.tar) mesa_version="${mesa_filename#mesa-}"; mesa_version="${mesa_version%-[0-9]*.gpkg.tar}"; mesa_version="${mesa_version%.gpkg.tar}" ;;
    *.tbz2) mesa_version="${mesa_filename#mesa-}"; mesa_version="${mesa_version%.tbz2}" ;;
  esac
  [[ -n "$mesa_version" ]] || die "could not determine the Mesa version from $mesa_filename"
  mesa_atom="=media-libs/mesa-$mesa_version"
  log "Install Mesa runtime dependencies from binary packages"
  chroot "$ROOT" /bin/bash -lc \
    "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly --onlydeps '$mesa_atom'" \
    |& tee "$OUT/mesa-binpkg.log"
  log "Install Mesa from an imported binary package only"
  chroot "$ROOT" /bin/bash -lc \
    "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly '$mesa_atom'" \
    |& tee -a "$OUT/mesa-binpkg.log"
  mesa_pkg="$(find "$ROOT/var/db/pkg/media-libs" -mindepth 1 -maxdepth 1 -type d -name 'mesa-*' -print -quit 2>/dev/null)"
  [[ -n "$mesa_pkg" && -s "$mesa_pkg/USE" ]] || die "Mesa binary package did not install package metadata"
  if grep -Eq '(^|[[:space:]])llvm([[:space:]]|$)' "$mesa_pkg/USE"; then
    die "the installed Mesa binpkg has USE=llvm; refusing an LLVM-enabled Mesa runtime"
  fi
  find "$ROOT/usr/lib" "$ROOT/usr/lib64" -path '*/dri/crocus_dri.so' -print -quit 2>/dev/null | grep -q . ||
    die "installed Mesa binary package is missing the Crocus driver"
fi

RUNTIME_ATOMS="$ATOMS"
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  RUNTIME_ATOMS="$(awk '$0 != "media-libs/mesa"' "$WORK/atoms.txt" | paste -sd ' ' -)"
  log "Mesa is already installed from its verified binpkg; installing the remaining runtime atoms"
fi

# Strict runtime assembly reads only the imported Core 2 PKGDIR. The Gentoo
# network binhost is disabled so an untracked generic package cannot slip in.
# Missing binaries fail immediately; source compilation is never permitted.

log "Install runtime packages (source fallback: $SOURCE_FALLBACK)"
if [[ "$SOURCE_FALLBACK" == true ]]; then
  chroot "$ROOT" /bin/bash -lc "umask 0002; export LC_ALL=C; source /etc/portage/make.conf; export FEATURES=\"\${FEATURES} -userpriv\"; emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --usepkg --buildpkg $RUNTIME_ATOMS" |& tee "$OUT/emerge-runtime.log"
else
  chroot "$ROOT" /bin/bash -lc "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly $RUNTIME_ATOMS" |& tee "$OUT/emerge-runtime.log"
fi

# glxgears is optional: use it only when its already-built binary package was
# imported. Never start a new source build merely to add this diagnostic tool.
GLXGEARS_STATUS="omitted: no imported x11-apps/mesa-progs binary package"
MESA_PROGS_BINPKG="$(find "$ROOT/var/cache/binpkgs/x11-apps/mesa-progs" -maxdepth 1 -type f \
  \( -name 'mesa-progs-*.gpkg.tar' -o -name 'mesa-progs-*.tbz2' \) -print -quit 2>/dev/null || true)"
if [[ -n "$MESA_PROGS_BINPKG" ]]; then
  if chroot "$ROOT" /bin/bash -lc \
      'emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg=n --usepkgonly x11-apps/mesa-progs' \
      |& tee "$OUT/mesa-progs-binpkg.log"; then
    GLXGEARS_STATUS="installed from existing binary package"
  else
    GLXGEARS_STATUS="omitted: imported mesa-progs binary package had unresolved dependencies"
  fi
fi
if [[ -x "$ROOT/usr/bin/glxgears" ]]; then
  GLXGEARS_STATUS="included: /usr/bin/glxgears"
else
  GLXGEARS_STATUS="omitted: glxgears was not successfully installed"
fi
printf '%s\n' "$GLXGEARS_STATUS" > "$OUT/GLXGEARS-STATUS.txt"

chroot "$ROOT" /bin/bash -lc 'test -x /sbin/init && command -v useradd && command -v groupadd && command -v usermod && command -v openssl && command -v visudo'
chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --ask=n --verbose --depclean --with-bdeps=n' |& tee "$OUT/depclean.log"
if [[ "$RUNTIME_PROFILE" == gui-initram || "$RUNTIME_PROFILE" == openbox ]]; then
  for atom in llvm-core/llvm llvm-core/clang llvm-runtimes/compiler-rt llvm-runtimes/clang-runtime llvm-runtimes/libclc dev-util/mesa_clc dev-util/spirv-llvm-translator; do
    category="${atom%%/*}"
    package="${atom#*/}"
    if find "$ROOT/var/db/pkg/$category" -mindepth 1 -maxdepth 1 -type d -name "$package-*" -print -quit 2>/dev/null | grep -q .; then
      die "GUI runtime retained build-only Mesa compiler dependency $atom after depclean"
    fi
  done
fi
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  bluez_pkg="$(find "$ROOT/var/db/pkg/net-wireless" -mindepth 1 -maxdepth 1 -type d -name 'bluez-*' -print -quit 2>/dev/null || true)"
  [[ -z "$bluez_pkg" ]] || die "Openbox runtime unexpectedly contains BlueZ: ${bluez_pkg##*/}"
  pipewire_pkg="$(find "$ROOT/var/db/pkg/media-video" -mindepth 1 -maxdepth 1 -type d -name 'pipewire-*' -print -quit 2>/dev/null || true)"
  [[ -n "$pipewire_pkg" && -s "$pipewire_pkg/USE" ]] || die "Openbox runtime has no PipeWire package metadata"
  if grep -qw bluetooth "$pipewire_pkg/USE"; then
    die "Openbox PipeWire was built with Bluetooth enabled; rebuild the binpkg with USE=-bluetooth"
  fi
  xorg_server="$ROOT/usr/bin/Xorg"
  [[ -x "$xorg_server" ]] || xorg_server="$ROOT/usr/libexec/Xorg"
  [[ -x "$xorg_server" ]] || die "Openbox runtime has no executable Xorg server"
  xorg_pkg="$(find "$ROOT/var/db/pkg/x11-base" -mindepth 1 -maxdepth 1 -type d -name 'xorg-server-*' -print -quit)"
  [[ -n "$xorg_pkg" && -s "$xorg_pkg/USE" ]] || die "Xorg package USE metadata is missing"
  grep -qw elogind "$xorg_pkg/USE" || die "Xorg lacks elogind VT/session support"
  if grep -qw suid "$xorg_pkg/USE"; then die "Xorg was built with USE=suid"; fi
  [[ ! -u "$xorg_server" ]] || die "Xorg unexpectedly has the setuid bit; use the elogind-managed local VT"
  chroot "$ROOT" chmod 0755 /usr/bin/startx
  for executable in /usr/bin/startx /usr/bin/xterm /usr/bin/openbox-session \
    /usr/bin/python3 /usr/bin/scrcpy /usr/bin/nmcli /usr/bin/nmtui \
    /usr/sbin/wpa_supplicant \
    /usr/bin/pipewire /usr/bin/wireplumber /usr/bin/aplay /usr/bin/arecord \
    /usr/bin/amixer /usr/bin/alsamixer /usr/bin/speaker-test; do
    chroot "$ROOT" /bin/bash -lc "test -x '$executable'" || die "Openbox runtime missing required executable $executable"
  done
  [[ -s "$ROOT/usr/share/scrcpy/scrcpy-server" ]] || die "Openbox runtime is missing the matching scrcpy-server"
  : > "$OUT/TOOL-AVAILABILITY.txt"
  for executable in /usr/bin/nvim /usr/bin/lf /usr/bin/fd /usr/bin/sd /usr/bin/rdmsr /usr/bin/wrmsr /usr/bin/msr-cpuid \
    /usr/bin/grep /usr/bin/egrep /usr/bin/tldr /usr/bin/htop /usr/bin/btop /usr/bin/mc /usr/bin/rg /usr/bin/xdotool \
    /usr/bin/zsh /usr/bin/nano /usr/bin/tmux /usr/bin/sox /usr/bin/lame /usr/bin/ffmpeg /usr/bin/ffprobe \
    /usr/bin/xclip /usr/bin/xdg-open /usr/bin/xmodmap /usr/bin/xrdb /usr/sbin/iw \
    /usr/bin/ntfs-3g /usr/sbin/mount.ntfs-3g; do
    if [[ -x "$ROOT$executable" ]]; then
      printf 'included: %s\n' "$executable" >> "$OUT/TOOL-AVAILABILITY.txt"
    else
      printf 'omitted: %s (no compatible imported binpkg)\n' "$executable" >> "$OUT/TOOL-AVAILABILITY.txt"
    fi
  done
  mesa_pkg="$(find "$ROOT/var/db/pkg/media-libs" -mindepth 1 -maxdepth 1 -type d -name 'mesa-*' -print -quit 2>/dev/null)"
  [[ -n "$mesa_pkg" && -s "$mesa_pkg/USE" ]] || die "Openbox runtime has no installed Mesa package metadata"
  if grep -Eq '(^|[[:space:]])llvm([[:space:]]|$)' "$mesa_pkg/USE"; then
    die "the installed Mesa binpkg has USE=llvm; refusing an LLVM-enabled Mesa runtime"
  fi
  find "$ROOT/usr/lib" "$ROOT/usr/lib64" -path '*/dri/crocus_dri.so' -print -quit 2>/dev/null | grep -q . ||
    die "Openbox runtime is missing Mesa's Crocus driver"
fi

log "Install pinned deb12dots user configuration"
bash "$GITHUB_WORKSPACE/d630-gentoo/scripts/install-runtime-dotfiles.sh" "$ROOT" "$WORK/dotfiles"
chroot "$ROOT" /bin/bash -lc 'env-update'

log "Configure console login, first-boot account creation, and OpenRC"
mkdir -p "$ROOT/etc/sudoers.d" "$ROOT/etc/skel" "$ROOT/var/lib/d630"
chroot "$ROOT" /bin/bash -lc 'getent group wheel >/dev/null 2>&1 || groupadd wheel'
install -m 0755 "$GITHUB_WORKSPACE/d630-gentoo/config/runtime/d630-firstboot" "$ROOT/etc/init.d/d630-firstboot"
printf '%s\n' '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > "$ROOT/etc/sudoers.d/10-d630-wheel"
chmod 0755 "$ROOT/etc/sudoers.d"
chmod 0440 "$ROOT/etc/sudoers.d/10-d630-wheel"
grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers.d' "$ROOT/etc/sudoers" || echo '#includedir /etc/sudoers.d' >> "$ROOT/etc/sudoers"
chroot "$ROOT" /bin/bash -lc 'visudo -c'
chroot "$ROOT" chmod 4755 /usr/bin/sudo
printf '%s\n' d630-gentoo > "$ROOT/etc/hostname"
cat > "$ROOT/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost
127.0.1.1 d630-gentoo.localdomain d630-gentoo
EOF
cat > "$ROOT/etc/fstab" <<'EOF'
# The initramfs mounts the read-only SquashFS and volatile OverlayFS.
EOF
if [[ "$RUNTIME_PROFILE" != console ]]; then
  cat > "$ROOT/etc/skel/.xinitrc" <<'EOF'
#!/bin/sh
cd "$HOME" || exit 1
if command -v xrdb >/dev/null 2>&1 && [ -r "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi
if command -v xmodmap >/dev/null 2>&1 && [ -r "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
fi
exec openbox-session
EOF
  chmod 0644 "$ROOT/etc/skel/.xinitrc"
fi
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  # Rootless Xorg must use the VT owned by the current logind login session.
  # startx can infer it; direct xinit must use the same local VT explicitly.
  mkdir -p "$ROOT/etc/X11/xinit"
  cat > "$ROOT/etc/X11/xinit/xserverrc" <<'EOF'
#!/bin/sh
set -eu
current_tty="$(tty 2>/dev/null || true)"
case "$current_tty" in
  /dev/tty[0-9]*) vt="${current_tty#/dev/tty}" ;;
  *) vt="${XDG_VTNR:-}" ;;
esac
case "$vt" in
  ''|*[!0-9]*|0)
    echo "Xorg requires an active local VT; run startx/xinit from the tty login session." >&2
    exit 1
    ;;
esac
if [ -x /usr/bin/Xorg ]; then xorg=/usr/bin/Xorg; else xorg=/usr/libexec/Xorg; fi
exec "$xorg" -nolisten tcp "$@" "vt$vt" -keeptty
EOF
  chmod 0755 "$ROOT/etc/X11/xinit/xserverrc"
  sh -n "$ROOT/etc/X11/xinit/xserverrc"
fi
# Configure the kernel's built-in ZRAM as 1.5 GiB LZ4 swap.
cat > "$ROOT/etc/init.d/d630-zram" <<'EOF'
#!/sbin/openrc-run
description="D630 LZ4 compressed RAM swap"

depend() {
  before localmount
}

start() {
  ebegin "Activating 1.5 GiB LZ4 ZRAM swap"
  if [ ! -b /dev/zram0 ] || [ ! -w /sys/block/zram0/disksize ]; then
    eerror "Built-in zram device is missing; expected CONFIG_ZRAM=y"
    eend 1
    return 1
  fi
  if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq /dev/zram0; then
    eend 0
    return 0
  fi
  current_size="$(cat /sys/block/zram0/disksize)" || {
    eend 1
    return 1
  }
  if [ "$current_size" -eq 0 ]; then
    echo lz4 > /sys/block/zram0/comp_algorithm || {
      eend 1
      return 1
    }
    echo 2 > /sys/block/zram0/max_comp_streams 2>/dev/null || true
    echo 1610612736 > /sys/block/zram0/disksize || {
      eend 1
      return 1
    }
    mkswap -L d630-zram /dev/zram0 >/dev/null || {
      eend 1
      return 1
    }
  fi
  swapon -p 100 /dev/zram0
  result=$?
  eend "$result"
  return "$result"
}

stop() {
  if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq /dev/zram0; then
    swapoff /dev/zram0 || return 1
  fi
  echo 1 > /sys/block/zram0/reset
}
EOF
chmod 0755 "$ROOT/etc/init.d/d630-zram"
chroot "$ROOT" /bin/bash -lc 'rc-update add d630-zram boot'

# Create the live user during sysinit, before init starts the tty1 login.
chroot "$ROOT" /bin/bash -lc 'rc-update add d630-firstboot sysinit'

# tty1 is the only local login respawn. Do not create a serial getty on ttyS0;
# Xorg must take the active login VT rather than reserving tty7.
AGETTY_BIN="$(chroot "$ROOT" /bin/bash -lc 'command -v agetty' | tail -n 1)"
[[ "$AGETTY_BIN" == /* && -x "$ROOT$AGETTY_BIN" ]] || die "util-linux agetty executable is missing from the runtime root"
for runlevel_dir in "$ROOT"/etc/runlevels/*; do
  [[ -d "$runlevel_dir" ]] || continue
  rm -f "$runlevel_dir"/agetty.tty* "$runlevel_dir"/getty.tty*
done
rm -f "$ROOT"/etc/init.d/agetty.tty* "$ROOT"/etc/init.d/getty.tty*
[[ -f "$ROOT/etc/inittab" ]] || die "Stage 3 has no /etc/inittab; cannot configure tty1 autologin"
python3 - "$ROOT/etc/inittab" "$AGETTY_BIN" <<'PY'
import re
import sys

path, agetty = sys.argv[1:]
with open(path, encoding="utf-8") as stream:
    lines = stream.readlines()

kept = []
for line in lines:
    if line.lstrip().startswith("#"):
        kept.append(line)
        continue
    fields = line.rstrip("\n").split(":", 3)
    if len(fields) == 4:
        ident, _runlevels, action, command = fields
        is_getty = re.search(r"\b(?:agetty|getty)\b", command)
        owns_target_vt = re.search(r"\b(?:tty1|tty7|ttyS0)\b", command)
        if ident in {"c1", "s0"} or (action == "respawn" and is_getty and owns_target_vt):
            continue
    kept.append(line)

entry = f"c1:12345:respawn:{agetty} --autologin gentoo --noclear tty1 linux\n"
with open(path, "w", encoding="utf-8") as stream:
    stream.writelines(kept)
    if kept and not kept[-1].endswith("\n"):
        stream.write("\n")
    stream.write(entry)
PY
[[ "$(grep -Ec '^[^#][^:]*:[^:]*:respawn:.*(agetty|getty).*tty1([[:space:]]|$)' "$ROOT/etc/inittab")" == 1 ]] ||
  die "expected exactly one tty1 getty respawn entry"
! grep -Eq '^[^#][^:]*:[^:]*:respawn:.*(agetty|getty).*(tty7|ttyS0)([[:space:]]|$)' "$ROOT/etc/inittab" ||
  die "unexpected tty7 or serial getty respawn entry remains"
grep -Fq "c1:12345:respawn:$AGETTY_BIN --autologin gentoo --noclear tty1 linux" "$ROOT/etc/inittab" ||
  die "tty1 autologin entry was not written to /etc/inittab"
if find "$ROOT/etc/runlevels" -type l \( -name 'agetty.tty*' -o -name 'getty.tty*' \) -print -quit | grep -q .; then
  die "OpenRC still has a local getty runlevel alias"
fi
if [[ -L "$ROOT/etc/runlevels/default/netmount" ]]; then
  chroot "$ROOT" /bin/bash -lc 'rc-update del netmount default'
fi
grep -E '^[^#].*respawn:.*(tty1|tty7|ttyS0)' "$ROOT/etc/inittab" > "$OUT/INITTAB-PROBE.txt"
if [[ "$RUNTIME_PROFILE" == gui-initram || "$RUNTIME_PROFILE" == openbox ]]; then
  [[ -x "$ROOT/etc/init.d/elogind" ]] || die "rootless Xorg requires the elogind OpenRC service"
  chroot "$ROOT" /bin/bash -lc 'rc-update add elogind boot'
  grep -Rqs 'pam_elogind\.so' "$ROOT/etc/pam.d" || die "PAM login stack has no pam_elogind session hook"
fi
for SERVICE in dbus NetworkManager; do
  [[ -x "$ROOT/etc/init.d/$SERVICE" ]] && chroot "$ROOT" /bin/bash -lc "rc-update add '$SERVICE' default" || true
done
if [[ "$RUNTIME_PROFILE" == gui-initram && -x "$ROOT/etc/init.d/dhcpcd" ]]; then
  chroot "$ROOT" /bin/bash -lc 'rc-update add dhcpcd default'
fi
if chroot "$ROOT" /bin/bash -lc 'command -v locale-gen >/dev/null 2>&1'; then
  chroot "$ROOT" /bin/bash -lc 'locale-gen && env-update' |& tee "$OUT/locale.log" || true
fi

log "Install matching kernel modules and preserve the recovered boot files"
if [[ -n "$LOCAL_RELEASE_ASSETS_DIR" ]]; then
  [[ -s "$LOCAL_RELEASE_ASSETS_DIR/kernel" && -s "$LOCAL_RELEASE_ASSETS_DIR/initramfs" ]] ||
    die "prepared assets do not contain both kernel and initramfs"
  cp -p "$LOCAL_RELEASE_ASSETS_DIR/kernel" "$OUT/kernel"
  cp -p "$LOCAL_RELEASE_ASSETS_DIR/initramfs" "$OUT/initramfs"
  cp -p "$LOCAL_RELEASE_ASSETS_DIR/KERNELRELEASE.txt" "$OUT/KERNELRELEASE.txt" 2>/dev/null || true
  cp -p "$LOCAL_RELEASE_ASSETS_DIR/KERNEL-BUILD-MANIFEST.txt" "$OUT/KERNEL-BUILD-MANIFEST.txt" 2>/dev/null || true
  cp -p "$LOCAL_RELEASE_ASSETS_DIR/BUILD-MANIFEST.txt" "$OUT/SOURCE-BUILD-MANIFEST.txt" 2>/dev/null || true
  MOD_ARCHIVE="$(find "$LOCAL_RELEASE_ASSETS_DIR" -maxdepth 1 -name 'modules-*.tar.zst' -print -quit)"
  [[ -n "$MOD_ARCHIVE" ]] || die "prepared assets do not contain a matching modules-*.tar.zst archive"
  MOD_DIR="$(tar --use-compress-program=unzstd -tf "$MOD_ARCHIVE" | awk '/^(\.\/)?lib\/modules\/[^/]+\/$/ && !found { print; found = 1 }')"
  [[ -n "$MOD_DIR" ]] || die "module archive has no /lib/modules tree"
  MOD_REL="$(printf '%s\n' "$MOD_DIR" | sed -E 's#^(\./)?lib/modules/([^/]+)/$#\2#')"
  REL_FILE="$LOCAL_RELEASE_ASSETS_DIR/KERNELRELEASE.txt"
  [[ -s "$REL_FILE" ]] || REL_FILE="$LOCAL_RELEASE_ASSETS_DIR/kernel-release.txt"
  if [[ -s "$REL_FILE" ]]; then
    [[ "$(tr -d '\r\n' < "$REL_FILE")" == "$MOD_REL" ]] || die "module release mismatch"
  fi
  tar --use-compress-program=unzstd -xf "$MOD_ARCHIVE" -C "$ROOT"
  [[ ! -f "$LOCAL_RELEASE_ASSETS_DIR/d630-firmware.tar.zst" ]] ||
    tar --use-compress-program=unzstd -xf "$LOCAL_RELEASE_ASSETS_DIR/d630-firmware.tar.zst" -C "$ROOT"
  printf 'Source: recovered Actions artifact\nKernel release: %s\nModules: %s\n' "$MOD_REL" "$(basename "$MOD_ARCHIVE")" > "$OUT/KERNEL-MODULES.txt"
elif [[ -n "$KERNEL_BUNDLE_TAG" ]]; then
  mkdir -p "$WORK/kernel"
  curl -fsSL --retry 3 "${GH_API_AUTH_ARGS[@]}" -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$KERNEL_BUNDLE_TAG" -o "$WORK/kernel/release.json"
  python3 - "$WORK/kernel/release.json" "$WORK/kernel/assets.tsv" <<'PY'
import json,re,sys
with open(sys.argv[1],encoding="utf-8") as f:r=json.load(f)
assets=r.get("assets",[])
sums=[a for a in assets if a.get("name")=="SHA256SUMS"]
mods=[a for a in assets if re.fullmatch(r"modules-[A-Za-z0-9._+-]+\.tar\.zst",a.get("name",""))]
extra=[a for a in assets if a.get("name") in ("d630-firmware.tar.zst","KERNELRELEASE.txt","kernel-release.txt")]
if not sums or len(mods)!=1: raise SystemExit("Kernel release must contain SHA256SUMS and exactly one modules-*.tar.zst")
with open(sys.argv[2],"w",encoding="utf-8") as f:
 f.write("SHA256SUMS\t"+sums[0]["browser_download_url"]+"\n")
 for a in mods+extra:f.write(a["name"]+"\t"+a["browser_download_url"]+"\n")
PY
  SUMS_URL="$(awk -F '\t' '$1=="SHA256SUMS"{print $2;exit}' "$WORK/kernel/assets.tsv")"
  curl -fsSL --retry 3 "$SUMS_URL" -o "$WORK/kernel/SHA256SUMS"
  while IFS=$'\t' read -r NAME URL; do
    [[ "$NAME" == SHA256SUMS ]] && continue
    curl -fL --retry 3 "$URL" -o "$WORK/kernel/$NAME"
    (cd "$WORK/kernel" && grep -F "  $NAME" SHA256SUMS | sha256sum --check)
  done < "$WORK/kernel/assets.tsv"
  MOD_ARCHIVE="$(find "$WORK/kernel" -maxdepth 1 -name 'modules-*.tar.zst' -print -quit)"
  MOD_DIR="$(tar --use-compress-program=unzstd -tf "$MOD_ARCHIVE" | awk '/^(\.\/)?lib\/modules\/[^/]+\/$/ && !found { print; found = 1 }')"
  [[ -n "$MOD_DIR" ]] || die "module archive has no /lib/modules tree"
  MOD_REL="$(printf '%s\n' "$MOD_DIR" | sed -E 's#^(\./)?lib/modules/([^/]+)/$#\2#')"
  REL_FILE="$WORK/kernel/KERNELRELEASE.txt"
  [[ -s "$REL_FILE" ]] || REL_FILE="$WORK/kernel/kernel-release.txt"
  if [[ -s "$REL_FILE" ]]; then [[ "$(tr -d '\r\n' < "$REL_FILE")" == "$MOD_REL" ]] || die "module release mismatch"; fi
  tar --use-compress-program=unzstd -xf "$MOD_ARCHIVE" -C "$ROOT"
  [[ ! -f "$WORK/kernel/d630-firmware.tar.zst" ]] || tar --use-compress-program=unzstd -xf "$WORK/kernel/d630-firmware.tar.zst" -C "$ROOT"
  printf 'Release: %s\nKernel release: %s\n' "$KERNEL_BUNDLE_TAG" "$MOD_REL" > "$OUT/KERNEL-MODULES.txt"
else
  echo "No kernel bundle supplied; optional modules are not bundled." > "$OUT/KERNEL-MODULES.txt"
fi

log "Validate runtime root and build SquashFS"
[[ -x "$ROOT/sbin/init" ]] || die "runtime root has no executable /sbin/init"
if [[ "$RUNTIME_PROFILE" == openbox || "$RUNTIME_PROFILE" == desktop || "$RUNTIME_PROFILE" == daily-driver || "$RUNTIME_PROFILE" == gui-initram ]]; then
  chroot "$ROOT" /bin/bash -lc 'test -x /usr/bin/Xorg || test -x /usr/libexec/Xorg' || die "graphical profile missing Xorg"
  chroot "$ROOT" /bin/bash -lc 'test -x /usr/bin/openbox-session' || die "graphical profile missing openbox-session"
fi
if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then
  for executable in /usr/bin/startx /usr/bin/xterm /usr/bin/openbox-session; do
    chroot "$ROOT" /bin/bash -lc "test -x '$executable'" || die "GUI runtime missing required executable $executable"
  done
  xorg_server="$ROOT/usr/bin/Xorg"
  [[ -x "$xorg_server" ]] || xorg_server="$ROOT/usr/libexec/Xorg"
  [[ -x "$xorg_server" ]] || die "GUI runtime has no executable Xorg server"
  xorg_pkg="$(find "$ROOT/var/db/pkg/x11-base" -mindepth 1 -maxdepth 1 -type d -name 'xorg-server-*' -print -quit)"
  [[ -n "$xorg_pkg" && -s "$xorg_pkg/USE" ]] || die "Xorg package USE metadata is missing"
  grep -qw elogind "$xorg_pkg/USE" || die "Xorg was not built with elogind support"
  if grep -qw suid "$xorg_pkg/USE"; then die "Xorg was built with USE=suid"; fi
  [[ ! -u "$xorg_server" ]] || die "Xorg executable unexpectedly has the setuid bit"
  [[ -s "$ROOT/etc/X11/xinit/xserverrc" ]] || die "rootless Xorg is missing the active-VT xserverrc"
  crocus_driver="$(find "$ROOT/usr/lib" "$ROOT/usr/lib64" -path '*/dri/crocus_dri.so' -print -quit 2>/dev/null || true)"
  [[ -n "$crocus_driver" ]] || die "Mesa Crocus driver is missing from the GUI runtime"
fi
chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --info' > "$OUT/EMERGE-INFO.txt"
find "$ROOT/var/db/pkg" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | sort > "$OUT/INSTALLED-PACKAGES.txt"
if [[ "$RUNTIME_PROFILE" == openbox ]]; then
  filtered_packages="$OUT/INSTALLED-PACKAGES.txt.tmp"
  grep -Ev '^(app-admin/(eselect|perl-cleaner)-|app-eselect/|app-portage/|dev-build/|dev-lang/perl-|dev-perl/|dev-util/|perl-core/|dev-libs/gobject-introspection-common-|sys-apps/(locale-gen|portage)-|sys-devel/(binutils|binutils-config|gcc|gcc-config|gettext|gnuconfig|patch)-)' \
    "$OUT/INSTALLED-PACKAGES.txt" > "$filtered_packages"
  mv -f "$filtered_packages" "$OUT/INSTALLED-PACKAGES.txt"
fi
rm -rf "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/cache/edb/dep" "$ROOT/var/tmp/portage" "$ROOT/var/db/repos/gentoo" "$ROOT/var/db/repos/guru"
mkdir -p "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/tmp/portage" "$ROOT/var/db/repos"
chown "0:$PORTAGE_GID" "$ROOT/var/tmp/portage"
chmod 2775 "$ROOT/var/tmp/portage"

cat > "$OUT/RUNTIME-MANIFEST.txt" <<EOF
Project: AmrUser-48/d630-gentoo
Profile: $RUNTIME_PROFILE
Base: Gentoo amd64 glibc/OpenRC Stage 3
Flags: -O2 -march=core2 -mtune=core2
Source fallback: $SOURCE_FALLBACK
Root file: $(if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then echo "gui-initram (complete Gentoo runtime root)"; else echo "/d630-gentoo/squashfs (no extension)"; fi)
Writable storage: RAM-only; changes are lost on reboot.
Live login: gentoo / gentoo; account and all-group membership are initialized at every boot.
TTY: one tty1 autologin respawn; no tty7 or serial getty.
Xorg: rootless elogind session uses the active login VT.
$(if [[ "$RUNTIME_PROFILE" == openbox ]]; then echo "Minimal runtime: Python 3 and its installed runtime modules retained; no Portage, package database, Perl, development tools, or compiler binaries. Only libgcc_s/libstdc++/libatomic GCC runtime libraries retained."; fi)
$(cat "$OUT/KERNEL-MODULES.txt")
EOF
cat > "$OUT/RELEASE-NOTES.md" <<EOF
D630 Gentoo runtime SquashFS — profile $RUNTIME_PROFILE

Place the release asset **squashfs** at **/d630-gentoo/squashfs**. Keep the kernel and initramfs from the interactive Gentoo runner at **/d630-gentoo/kernel** and **/d630-gentoo/initramfs**.

This live image uses a volatile RAM OverlayFS. Changes are lost on reboot. Every boot creates or refreshes the local **gentoo** account, assigns it to all system groups, and resets its password to **gentoo**. The account can use `sudo`; log in as `gentoo` with password `gentoo`. This fixed test password is intended for local live-media testing, not network-exposed use.

The kernel and initramfs are separate deliverables. Supply their release tag to kernel_bundle_tag to add matching modules and firmware.
EOF
if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then
  log "Create complete Gentoo desktop initramfs"
  cat > "$ROOT/init" <<'INIT'
#!/bin/sh
set -eu
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
mkdir -p /dev /dev/pts /dev/shm /proc /sys /run /run/lock /tmp
mount -t proc proc /proc 2>/dev/null || grep -q ' /proc proc ' /proc/mounts
mount -t sysfs sysfs /sys 2>/dev/null || grep -q ' /sys sysfs ' /proc/mounts
grep -q ' /dev devtmpfs ' /proc/mounts ||
  mount -t devtmpfs -o mode=0755 devtmpfs /dev
mount -t devpts devpts /dev/pts 2>/dev/null || grep -q ' /dev/pts devpts ' /proc/mounts
mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs /run
mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs /tmp
hostname d630-gui 2>/dev/null || :
exec /sbin/init
INIT
  chmod 0755 "$ROOT/init"
  root_cpio="$WORK/gui-rootfs.cpio"
  root_zstd="$WORK/gui-rootfs.cpio.zst"
  if ! (
    cd "$ROOT"
    find . -xdev -print0 | LC_ALL=C sort -z | cpio --null --create --format=newc --owner=0:0
  ) > "$root_cpio"; then
    die "could not create the GUI root CPIO archive"
  fi
  zstd -q -T0 -3 -f "$root_cpio" -o "$root_zstd"
  zstd -q -t "$root_zstd"
  cat "$EARLY_MICROCODE_CPIO" "$root_zstd" > "$OUT/gui-initram"
  [[ -s "$OUT/gui-initram" ]] || die "GUI initramfs output is empty"
  zstd -q -dc "$root_zstd" | cpio -it > "$OUT/GUI-INITRAMFS-FILES.txt" 2>"$OUT/gui-cpio-list.log" ||
    die "could not list the generated GUI CPIO archive"
  for path in ./init ./sbin/init ./usr/bin/openbox-session ./usr/bin/startx ./usr/bin/xterm; do
    grep -Fxq "$path" "$OUT/GUI-INITRAMFS-FILES.txt" || die "GUI archive is missing $path"
  done
  file "$OUT/gui-initram" > "$OUT/GUI-INITRAMFS-INFO.txt"
  du -h "$OUT/gui-initram" | tee -a "$GITHUB_STEP_SUMMARY"
  {
    echo "GUI initramfs: Gentoo OpenRC runtime root with Xorg, Crocus Mesa, xinit, xterm, and Openbox"
    echo "Package source: pinned Core 2 binpkg release; source builds disabled"
    echo "Target: Intel Core 2 Duo / Dell Latitude D630"
    echo "Early microcode: original CPIO prepended unchanged"
    echo "Changes: RAM-only; save them by rebuilding the initramfs to persistent storage"
    echo "X startup: log in on tty1 and run startx; /etc/skel/.xinitrc starts Openbox"
    echo
    cat "$OUT/GUI-INITRAMFS-INFO.txt"
  } > "$OUT/GUI-INITRAMFS-MANIFEST.txt"
  sum_files=(gui-initram RUNTIME-MANIFEST.txt PACKAGES.txt BUILD-INPUTS.txt STAGE3-MANIFEST.txt INSTALLED-PACKAGES.txt EMERGE-INFO.txt KERNEL-MODULES.txt GUI-INITRAMFS-MANIFEST.txt)
else
  log "Build Zstandard SquashFS from runtime-only root"
  if [[ "$RUNTIME_PROFILE" == openbox ]]; then
    MINIMAL_RUNTIME=true bash "$GITHUB_WORKSPACE/d630-gentoo/scripts/build-squashfs.sh" "$ROOT" "$OUT/squashfs"
  else
    bash "$GITHUB_WORKSPACE/d630-gentoo/scripts/build-squashfs.sh" "$ROOT" "$OUT/squashfs"
  fi
  unsquashfs -s "$OUT/squashfs" | tee "$OUT/SQUASHFS-INFO.txt"
  unsquashfs -cat "$OUT/squashfs" etc/inittab > "$OUT/INITTAB-PROBE.txt" || die "final SquashFS has no readable /etc/inittab"
  grep -Fq "c1:12345:respawn:$AGETTY_BIN --autologin gentoo --noclear tty1 linux" "$OUT/INITTAB-PROBE.txt" || die "final SquashFS lost the tty1 autologin respawn entry"
  [[ "$(grep -Ec '^[^#][^:]*:[^:]*:respawn:.*(agetty|getty).*tty1([[:space:]]|$)' "$OUT/INITTAB-PROBE.txt")" == 1 ]] || die "final SquashFS has duplicate or missing tty1 getty respawns"
  ! grep -Eq '^[^#][^:]*:[^:]*:respawn:.*(agetty|getty).*(tty7|ttyS0)([[:space:]]|$)' "$OUT/INITTAB-PROBE.txt" || die "final SquashFS unexpectedly has tty7 or serial getty respawn"
  if [[ "$RUNTIME_PROFILE" == openbox ]]; then
    unsquashfs -cat "$OUT/squashfs" etc/X11/xinit/xserverrc > "$OUT/XSERVERRC-PROBE.txt" || die "final SquashFS has no rootless-Xorg xserverrc"
    grep -Fq '"vt$vt" -keeptty' "$OUT/XSERVERRC-PROBE.txt" || die "final SquashFS xserverrc does not bind Xorg to the active login VT"
  fi
  unsquashfs -ll "$OUT/squashfs" | grep -Fq 'usr/share/scrcpy/scrcpy-server' || die "final SquashFS is missing scrcpy-server"
  unsquashfs -ll "$OUT/squashfs" | grep -E 'sbin/init($| ->)|usr/bin/init($| ->)' | tee "$OUT/INIT-PROBE.txt"
  [[ -s "$OUT/squashfs" ]] || die "SquashFS output is empty"  [[ -s "$OUT/squashfs" ]] || die "SquashFS output is empty"
  (cd "$OUT" && sha256sum squashfs > SQUASHFS-SHA256.txt)
  sum_files=(SQUASHFS-SHA256.txt RUNTIME-MANIFEST.txt PACKAGES.txt BUILD-INPUTS.txt STAGE3-MANIFEST.txt INSTALLED-PACKAGES.txt EMERGE-INFO.txt KERNEL-MODULES.txt)
  if [[ "$RUNTIME_PROFILE" == openbox ]]; then
    sum_files+=(INITTAB-PROBE.txt XSERVERRC-PROBE.txt BINPKG-OPTIONAL-SKIPPED.txt TOOL-AVAILABILITY.txt required-binpkg-plan.log)
  fi
fi
for optional in kernel initramfs KERNELRELEASE.txt KERNEL-BUILD-MANIFEST.txt SOURCE-BUILD-MANIFEST.txt LOCAL-BINPKG-IMPORT.txt PREPARED-ASSET-CHECK.log; do
  [[ ! -f "$OUT/$optional" ]] || sum_files+=("$optional")
done
(cd "$OUT" && sha256sum "${sum_files[@]}" > SHA256SUMS)
[[ ! -s "$OUT/squashfs" ]] || du -h "$OUT/squashfs" | tee -a "$GITHUB_STEP_SUMMARY"
cat "$OUT/SHA256SUMS" | tee -a "$GITHUB_STEP_SUMMARY"
[[ ! -s "$OUT/SQUASHFS-SHA256.txt" ]] || cat "$OUT/SQUASHFS-SHA256.txt" | tee -a "$GITHUB_STEP_SUMMARY"
log "Runtime image completed"
