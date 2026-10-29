#!/usr/bin/env bash
set -Eeuo pipefail
die() { echo "d630-runtime-rootfs: ERROR: $*" >&2; exit 2; }
log() { echo; echo "[d630-runtime-rootfs] $*"; }

[[ "$EUID" -eq 0 ]] || die "run as root"
GH_API_AUTH_ARGS=()
if [[ -n "${GH_TOKEN:-}" ]]; then GH_API_AUTH_ARGS=(-H "Authorization: Bearer $GH_TOKEN"); fi
[[ "$RUNTIME_PROFILE" =~ ^(tiny-console|console|desktop|daily-driver|gui-initram)$ ]] || die "invalid runtime profile"
[[ -z "$BINPKG_RUN_IDS" || "$BINPKG_RUN_IDS" =~ ^[0-9,[:space:]]+$ ]] || die "binpkg_run_ids must be numeric IDs separated by commas or spaces"
[[ "$SOURCE_FALLBACK" == true || "$SOURCE_FALLBACK" == false ]] || die "SOURCE_FALLBACK must be true or false"
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

log "Install Core 2 Portage configuration"
mkdir -p "$ROOT/etc/portage/package-sets" "$ROOT/etc/portage/profile/package.use.force" \
  "$ROOT/etc/portage/binrepos.conf" "$ROOT/etc/portage/repos.conf" \
  "$ROOT/etc/bash/bashrc.d" "$ROOT/etc/env.d" "$ROOT/etc/X11/xorg.conf.d" \
  "$ROOT/usr/local/sbin" "$ROOT/var/cache/binpkgs" "$ROOT/var/log/portage" \
  "$ROOT/dev" "$ROOT/proc" "$ROOT/sys" "$ROOT/run"
if [[ -f "$ROOT/etc/portage/package.use" ]]; then mv "$ROOT/etc/portage/package.use" "$ROOT/etc/portage/package.use.stage3"; fi
mkdir -p "$ROOT/etc/portage/package.use"
install -m 0644 "$GITHUB_WORKSPACE/config/portage/make.conf" "$ROOT/etc/portage/make.conf"
install -m 0644 "$GITHUB_WORKSPACE/config/portage/profile/package.use.force" "$ROOT/etc/portage/profile/package.use.force/zz-d630-llvm"
install -m 0644 "$GITHUB_WORKSPACE/config/bash/bashrc.d/10-portage-ask.sh" "$ROOT/etc/bash/bashrc.d/10-portage-ask.sh"
install -m 0644 "$GITHUB_WORKSPACE/config/locale.gen" "$ROOT/etc/locale.gen"
install -m 0644 "$GITHUB_WORKSPACE/config/env.d/02locale" "$ROOT/etc/env.d/02locale"
install -m 0644 "$GITHUB_WORKSPACE/config/xorg/99-synaptics.conf" "$ROOT/etc/X11/xorg.conf.d/99-synaptics.conf"
rm -rf "$ROOT/etc/portage/package.accept_keywords" "$ROOT/etc/portage/package.keywords"
mkdir -p "$ROOT/etc/portage/package.accept_keywords"
cp -a "$GITHUB_WORKSPACE/config/portage/package.accept_keywords/." "$ROOT/etc/portage/package.accept_keywords/"
cp -a "$GITHUB_WORKSPACE/config/portage/package.use/." "$ROOT/etc/portage/package.use/"
cp -a "$GITHUB_WORKSPACE/config/portage/binrepos.conf/." "$ROOT/etc/portage/binrepos.conf/"
cp -a "$GITHUB_WORKSPACE/config/package-sets/." "$ROOT/etc/portage/package-sets/"
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

if [[ "$RUNTIME_PROFILE" == tiny-console ]]; then
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
  cat "$GITHUB_WORKSPACE/config/package-sets/tiny-console.list" >> "$WORK/atoms.txt"
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
  cat "$GITHUB_WORKSPACE/config/package-sets/gui-initram.list" >> "$WORK/atoms.txt"
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
net-wireless/bluez
EOF
  case "$RUNTIME_PROFILE" in
    console) cat "$GITHUB_WORKSPACE/config/package-sets/cli.list" >> "$WORK/atoms.txt" ;;
    desktop) cat "$GITHUB_WORKSPACE/config/package-sets/cli.list" "$GITHUB_WORKSPACE/config/package-sets/desktop.list" >> "$WORK/atoms.txt" ;;
    daily-driver) cat "$GITHUB_WORKSPACE/config/package-sets/daily-driver.list" >> "$WORK/atoms.txt" ;;
  esac
fi
sed -i 's/#.*$//; /^[[:space:]]*$/d' "$WORK/atoms.txt"
sort -u "$WORK/atoms.txt" -o "$WORK/atoms.txt"
if grep -Evq '^[A-Za-z0-9+_.-]+/[A-Za-z0-9+_.-]+(:[A-Za-z0-9+_.-]+)?$' "$WORK/atoms.txt"; then die "invalid package atom in selected set"; fi
cp "$WORK/atoms.txt" "$OUT/PACKAGES.txt"
ATOMS="$(paste -sd ' ' "$WORK/atoms.txt")"

if [[ "$RUNTIME_PROFILE" == gui-initram && "$SOURCE_FALLBACK" == false ]]; then
  log "Require the GUI package atoms in the pinned binary-package release"
  while IFS= read -r atom || [[ -n "$atom" ]]; do
    atom="${atom%%#*}"
    atom="${atom//[[:space:]]/}"
    [[ -n "$atom" ]] || continue
    category="${atom%%/*}"
    package="${atom#*/}"
    if ! find "$ROOT/var/cache/binpkgs/$category/$package" -maxdepth 1 -type f \
      \( -name "$package-*.gpkg.tar" -o -name "$package-*.tbz2" \) -print -quit 2>/dev/null | grep -q .; then
      die "pinned binpkg release does not contain a binary for required GUI atom $atom"
    fi
  done < "$GITHUB_WORKSPACE/config/package-sets/gui-initram.list"
fi

log "Install runtime packages (source fallback: $SOURCE_FALLBACK)"
if [[ "$SOURCE_FALLBACK" == true ]]; then
  chroot "$ROOT" /bin/bash -lc "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg --usepkg --buildpkg $ATOMS" |& tee "$OUT/emerge-runtime.log"
else
  chroot "$ROOT" /bin/bash -lc "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg --usepkgonly $ATOMS" |& tee "$OUT/emerge-runtime.log"
fi
chroot "$ROOT" /bin/bash -lc 'test -x /sbin/init && command -v useradd && command -v groupadd && command -v passwd && command -v visudo'
chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --ask=n --verbose --depclean --with-bdeps=n' |& tee "$OUT/depclean.log"
if [[ "$RUNTIME_PROFILE" == gui-initram ]]; then
  for atom in llvm-core/llvm llvm-core/clang llvm-runtimes/libclc dev-util/mesa_clc; do
    category="${atom%%/*}"
    package="${atom#*/}"
    if find "$ROOT/var/db/pkg/$category" -mindepth 1 -maxdepth 1 -type d -name "$package-*" -print -quit 2>/dev/null | grep -q .; then
      die "GUI runtime retained build-only Mesa compiler dependency $atom after depclean"
    fi
  done
fi

log "Configure console login, first-boot account creation, and OpenRC"
mkdir -p "$ROOT/etc/sudoers.d" "$ROOT/etc/skel" "$ROOT/var/lib/d630"
cat > "$ROOT/etc/init.d/d630-firstboot" <<'EOF'
#!/sbin/openrc-run
description="Interactive first-boot user creation"
start() {
    [ -e /var/lib/d630/firstboot.done ] && return 0
    exec 3<>/dev/console || return 1
    while :; do
        printf '\nCreate a local username: ' >&3
        IFS= read -r username <&3 || return 1
        case "$username" in ""|root|*[!a-zA-Z0-9_-]*|[!a-zA-Z_]*)
            printf 'Invalid username.\n' >&3; continue ;;
        esac
        [ "$(expr length "$username")" -le 32 ] || { printf 'Username too long.\n' >&3; continue; }
        break
    done
    for group in wheel audio video plugdev usb netdev; do groupadd -f "$group" || return 1; done
    useradd -m -s /bin/bash -G wheel,audio,video,plugdev,usb,netdev "$username" || return 1
    printf '\nSet a password for %s when prompted.\n' "$username" >&3
    passwd "$username" <&3 >&3 2>&3 || { userdel -r "$username" >/dev/null 2>&1 || true; return 1; }
    touch /var/lib/d630/firstboot.done || return 1
    printf 'Account created; use sudo for administration.\n' >&3
    exec 3>&-
}
EOF
chmod 0755 "$ROOT/etc/init.d/d630-firstboot"
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' > "$ROOT/etc/sudoers.d/10-d630-wheel"
chmod 0440 "$ROOT/etc/sudoers.d/10-d630-wheel"
grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers.d' "$ROOT/etc/sudoers" || echo '#includedir /etc/sudoers.d' >> "$ROOT/etc/sudoers"
chroot "$ROOT" /bin/bash -lc 'visudo -c'
printf '%s\n' d630-gentoo > "$ROOT/etc/hostname"
cat > "$ROOT/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost
127.0.1.1 d630-gentoo.localdomain d630-gentoo
EOF
cat > "$ROOT/etc/fstab" <<'EOF'
# The initramfs mounts the read-only SquashFS and volatile OverlayFS.
EOF
if [[ "$RUNTIME_PROFILE" != console ]]; then printf '%s\n' 'exec openbox-session' > "$ROOT/etc/skel/.xinitrc"; chmod 0644 "$ROOT/etc/skel/.xinitrc"; fi
if [[ ! -x "$ROOT/etc/init.d/agetty.tty1" ]]; then
  cat > "$ROOT/etc/init.d/agetty.tty1" <<'EOF'
#!/sbin/openrc-run
description="D630 local tty1 login"
command="/sbin/agetty"
command_args="--noclear tty1 linux"
command_background="yes"
pidfile="/run/agetty.tty1.pid"
EOF
  chmod 0755 "$ROOT/etc/init.d/agetty.tty1"
fi
chroot "$ROOT" /bin/bash -lc 'rc-update add d630-firstboot sysinit'
chroot "$ROOT" /bin/bash -lc 'rc-update add agetty.tty1 default' || echo "WARNING: could not enable agetty.tty1"
if [[ "$RUNTIME_PROFILE" == gui-initram ]]; then
  [[ -x "$ROOT/etc/init.d/elogind" ]] || die "rootless Xorg requires the elogind OpenRC service"
  chroot "$ROOT" /bin/bash -lc 'rc-update add elogind boot'
fi
for SERVICE in dbus NetworkManager bluetooth; do
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
if [[ "$RUNTIME_PROFILE" == desktop || "$RUNTIME_PROFILE" == daily-driver || "$RUNTIME_PROFILE" == gui-initram ]]; then
  [[ -x "$ROOT/usr/bin/Xorg" || -x "$ROOT/usr/libexec/Xorg" ]] || die "graphical profile missing Xorg"
  [[ -x "$ROOT/usr/bin/openbox-session" ]] || die "graphical profile missing openbox-session"
fi
if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then
  for executable in /usr/bin/startx /usr/bin/xterm /usr/bin/openbox-session; do
    [[ -x "$ROOT$executable" ]] || die "GUI runtime missing required executable $executable"
  done
  xorg_server="$ROOT/usr/bin/Xorg"
  [[ -x "$xorg_server" ]] || xorg_server="$ROOT/usr/libexec/Xorg"
  [[ -x "$xorg_server" ]] || die "GUI runtime has no executable Xorg server"
  xorg_pkg="$(find "$ROOT/var/db/pkg/x11-base" -mindepth 1 -maxdepth 1 -type d -name 'xorg-server-*' -print -quit)"
  [[ -n "$xorg_pkg" && -s "$xorg_pkg/USE" ]] || die "Xorg package USE metadata is missing"
  grep -qw elogind "$xorg_pkg/USE" || die "Xorg was not built with elogind support"
  if grep -qw suid "$xorg_pkg/USE"; then die "Xorg was built with USE=suid"; fi
  [[ ! -u "$xorg_server" ]] || die "Xorg executable unexpectedly has the setuid bit"
  crocus_driver="$(find "$ROOT/usr/lib" "$ROOT/usr/lib64" -path '*/dri/crocus_dri.so' -print -quit 2>/dev/null || true)"
  [[ -n "$crocus_driver" ]] || die "Mesa Crocus driver is missing from the GUI runtime"
  [[ "$(stat -c '%a' "$xorg_server")" == 4755 ]] || die "Xorg server is not installed setuid-root for local console graphics"
fi
chroot "$ROOT" /bin/bash -lc 'emerge --ignore-default-opts --info' > "$OUT/EMERGE-INFO.txt"
find "$ROOT/var/db/pkg" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | sort > "$OUT/INSTALLED-PACKAGES.txt"
rm -rf "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/cache/edb/dep" "$ROOT/var/tmp/portage" "$ROOT/var/db/repos/gentoo" "$ROOT/var/db/repos/guru"
mkdir -p "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/tmp/portage" "$ROOT/var/db/repos"
chmod 1777 "$ROOT/var/tmp/portage"

cat > "$OUT/RUNTIME-MANIFEST.txt" <<EOF
Project: AmrUser-48/d630-gentoo
Profile: $RUNTIME_PROFILE
Base: Gentoo amd64 glibc/OpenRC Stage 3
Flags: -O2 -pipe -march=core2 -mtune=core2
Source fallback: $SOURCE_FALLBACK
Root file: $(if [[ "$BUILD_GUI_INITRAMFS" == true ]]; then echo "gui-initram (complete Gentoo runtime root)"; else echo "/d630-gentoo/squashfs (no extension)"; fi)
Writable storage: RAM-only; changes are lost on reboot.
First boot: create local account and password at console.
$(cat "$OUT/KERNEL-MODULES.txt")
EOF
cat > "$OUT/RELEASE-NOTES.md" <<EOF
D630 Gentoo runtime SquashFS — profile $RUNTIME_PROFILE

Place the release asset **squashfs** at **/d630-gentoo/squashfs**. Keep the kernel and initramfs from the interactive Gentoo runner at **/d630-gentoo/kernel** and **/d630-gentoo/initramfs**.

This first boot image uses a volatile RAM OverlayFS. Changes and user accounts are lost on reboot until persistence is added. The console first-boot service asks you to create a local account. No default password or root autologin is included.

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
  bash "$GITHUB_WORKSPACE/scripts/build-squashfs.sh" "$ROOT" "$OUT/squashfs"
  unsquashfs -s "$OUT/squashfs" | tee "$OUT/SQUASHFS-INFO.txt"
  unsquashfs -ll "$OUT/squashfs" | grep -E 'sbin/init($| ->)' | tee "$OUT/INIT-PROBE.txt"
  [[ -s "$OUT/squashfs" ]] || die "SquashFS output is empty"
  sum_files=(squashfs RUNTIME-MANIFEST.txt PACKAGES.txt BUILD-INPUTS.txt STAGE3-MANIFEST.txt INSTALLED-PACKAGES.txt EMERGE-INFO.txt KERNEL-MODULES.txt)
fi
for optional in kernel initramfs KERNELRELEASE.txt KERNEL-BUILD-MANIFEST.txt SOURCE-BUILD-MANIFEST.txt LOCAL-BINPKG-IMPORT.txt PREPARED-ASSET-CHECK.log; do
  [[ ! -f "$OUT/$optional" ]] || sum_files+=("$optional")
done
(cd "$OUT" && sha256sum "${sum_files[@]}" > SHA256SUMS)
[[ ! -s "$OUT/squashfs" ]] || du -h "$OUT/squashfs" | tee -a "$GITHUB_STEP_SUMMARY"
cat "$OUT/SHA256SUMS" | tee -a "$GITHUB_STEP_SUMMARY"
log "Runtime image completed"
