#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "d630-state-squashfs: ERROR: $*" >&2; exit 2; }
log() { echo; echo "[d630-state-squashfs] $*"; }

BUILD_ROOT="$1"
OUT="$2"
[[ -n "$BUILD_ROOT" ]] || BUILD_ROOT=/opt/gentoo
[[ -n "$OUT" ]] || OUT="$GITHUB_WORKSPACE/output"
REPO="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
WORK="$RUNNER_TEMP/d630-state-rootfs-work"
[[ -n "$RUNNER_TEMP" ]] || WORK="/tmp/d630-state-rootfs-work"
ROOT="$WORK/root"
SUCCESS=false

[[ "$EUID" -eq 0 ]] || die "run as root"
[[ -x "$BUILD_ROOT/bin/bash" && -d "$BUILD_ROOT/var/db/pkg" ]] || die "not a Gentoo build root: $BUILD_ROOT"
[[ -x "$REPO/scripts/build-squashfs.sh" ]] || die "repository checkout is incomplete"
for tool in rsync chroot mount umount mksquashfs unsquashfs; do
    command -v "$tool" >/dev/null || die "required host tool missing: $tool"
done

mkdir -p "$OUT" "$WORK"
rm -rf "$ROOT"
mkdir -p "$ROOT"

cleanup() {
    for mp in run sys proc dev; do
        mountpoint -q "$ROOT/$mp" 2>/dev/null && umount -R "$ROOT/$mp" 2>/dev/null || true
    done
    if [[ "$SUCCESS" == true ]]; then rm -rf "$ROOT"; fi
}
trap cleanup EXIT

TARGETS="app-admin/sudo app-i18n/fbterm app-misc/mc app-shells/bash media-fonts/dejavu media-fonts/terminus-font media-libs/mesa media-sound/alsa-utils net-misc/networkmanager net-wireless/iw net-wireless/wpa_supplicant net-wireless/wireless-regdb sys-apps/coreutils sys-apps/dbus sys-apps/kmod sys-apps/man-db sys-apps/openrc sys-apps/pciutils sys-apps/portage sys-apps/shadow sys-apps/usbutils sys-apps/util-linux sys-auth/elogind sys-auth/pambase x11-apps/xinit x11-apps/xterm x11-base/xorg-drivers x11-base/xorg-server x11-wm/openbox"

printf '%s\n' $TARGETS > "$OUT/RUNTIME-PACKAGES.txt"
du -shx "$BUILD_ROOT" "$BUILD_ROOT/var/cache/binpkgs" 2>/dev/null | tee "$OUT/SOURCE-ROOT-SIZE.txt"
df -h "$BUILD_ROOT" "$WORK" | tee "$OUT/DISK-BEFORE-ROOTFS.txt"

log "Finish required D630 runtime packages in the restored Core 2 build tree"
printf 'Target atoms:\n%s\n' "$(printf '  %s\n' $TARGETS)" | tee "$OUT/target-build.log"
if ! chroot "$BUILD_ROOT" /bin/bash -lc \
    "emerge --ignore-default-opts --ask=n --verbose --jobs=1 --load-average=4 --with-bdeps=n --getbinpkg --usepkg --buildpkg $TARGETS" \
    |& tee -a "$OUT/target-build.log"; then
    die "Portage failed while finishing runtime targets; see output/target-build.log"
fi

for atom in $TARGETS; do
    if ! chroot "$BUILD_ROOT" /usr/bin/portageq has_version / "$atom"; then
        die "runtime target is not installed after emerge: $atom"
    fi
done

log "Package the preserved Core 2 binpkgs for a durable reusable release"
PKG_RELEASE="$OUT/binpkgs-release"
mkdir -p "$PKG_RELEASE"
if ! find "$BUILD_ROOT/var/cache/binpkgs" -type f \( -name '*.gpkg.tar' -o -name '*.tbz2' \) -print -quit | grep -q .; then
    die "no binary packages found in the restored build tree"
fi
bash "$REPO/scripts/package-binpkgs-release.sh" "$BUILD_ROOT/var/cache/binpkgs" "$PKG_RELEASE"
(
    cd "$PKG_RELEASE"
    : > SHA256SUMS
    for asset in PACKAGE-LIST.txt binpkgs-part-*.tar.zst; do
        [[ -f "$asset" ]] && sha256sum "$asset" >> SHA256SUMS
    done
    sha256sum --check SHA256SUMS
)

log "Copy build tree to a separate runtime root; source tree and binpkgs remain untouched"
rsync -aHAX --numeric-ids --one-file-system --delete \
    --exclude='/dev/***' \
    --exclude='/proc/***' \
    --exclude='/sys/***' \
    --exclude='/run/***' \
    --exclude='/tmp/***' \
    --exclude='/var/tmp/portage/***' \
    --exclude='/var/cache/binpkgs/***' \
    --exclude='/var/cache/distfiles/***' \
    --exclude='/var/cache/edb/dep/***' \
    --exclude='/var/log/portage/***' \
    --exclude='/var/log/emerge.log' \
    --exclude='/var/log/gentoo-build-set.log' \
    --exclude='/usr/src/***' \
    --exclude='/root/.cache/***' \
    "$BUILD_ROOT/" "$ROOT/"
if [[ -f "$ROOT/var/lib/portage/world" ]]; then
    cp -a "$ROOT/var/lib/portage/world" "$OUT/WORLD-ORIGINAL.txt"
fi

for MP in dev proc sys run; do
    mkdir -p "$ROOT/$MP"
    mount --rbind "/$MP" "$ROOT/$MP"
    mount --make-rslave "$ROOT/$MP"
done
rm -f "$ROOT/etc/resolv.conf"
cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"

log "Set explicit runtime world and depclean only the copy"
mkdir -p "$ROOT/var/lib/portage"
cat > "$ROOT/var/lib/portage/world" <<'EOF'
app-admin/sudo
app-i18n/fbterm
app-misc/mc
app-shells/bash
media-fonts/dejavu
media-fonts/terminus-font
media-libs/mesa
media-sound/alsa-utils
net-misc/networkmanager
net-wireless/iw
net-wireless/wpa_supplicant
net-wireless/wireless-regdb
sys-apps/coreutils
sys-apps/dbus
sys-apps/kmod
sys-apps/man-db
sys-apps/openrc
sys-apps/pciutils
sys-apps/portage
sys-apps/shadow
sys-apps/usbutils
sys-apps/util-linux
sys-auth/elogind
sys-auth/pambase
x11-apps/xinit
x11-apps/xterm
x11-base/xorg-drivers
x11-base/xorg-server
x11-wm/openbox
EOF
if ! chroot "$ROOT" /bin/bash -lc \
    'emerge --ignore-default-opts --pretend --verbose --depclean --with-bdeps=n' \
    > "$OUT/depclean-preview.log" 2>&1; then
    tail -n 80 "$OUT/depclean-preview.log" >&2 || true
    die "depclean preview failed on runtime copy"
fi

log "Trim build-only dependencies from runtime copy"
if ! chroot "$ROOT" /bin/bash -lc \
    'emerge --ignore-default-opts --ask=n --verbose --depclean --with-bdeps=n' \
    |& tee "$OUT/depclean.log"; then
    die "depclean failed on runtime copy"
fi

for atom in $TARGETS; do
    if ! chroot "$ROOT" /usr/bin/portageq has_version / "$atom"; then
        die "depclean removed a required runtime target: $atom"
    fi
done
chroot "$ROOT" /bin/bash -lc 'test -x /sbin/init && command -v rc-update && command -v rc-status'

log "Configure first boot, OpenRC services, console login, and Openbox session"
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
grep -Eq '^[#@]includedir[[:space:]]+/etc/sudoers.d' "$ROOT/etc/sudoers" ||
    echo '#includedir /etc/sudoers.d' >> "$ROOT/etc/sudoers"
chroot "$ROOT" /bin/bash -lc 'visudo -c'

printf '%s\n' d630-gentoo > "$ROOT/etc/hostname"
cat > "$ROOT/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost
127.0.1.1 d630-gentoo.localdomain d630-gentoo
EOF
cat > "$ROOT/etc/fstab" <<'EOF'
# The initramfs mounts a read-only SquashFS and volatile OverlayFS.
EOF
printf '%s\n' 'exec openbox-session' > "$ROOT/etc/skel/.xinitrc"
chmod 0644 "$ROOT/etc/skel/.xinitrc"

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
chroot "$ROOT" /bin/bash -lc 'rc-update add agetty.tty1 default'
for service in dbus elogind NetworkManager bluetooth; do
    if [[ -x "$ROOT/etc/init.d/$service" ]]; then
        chroot "$ROOT" /bin/bash -lc "rc-update add '$service' default"
    fi
done
chroot "$ROOT" /bin/bash -lc 'rc-update show -v' | tee "$OUT/OPENRC-RUNLEVELS.txt"
if chroot "$ROOT" /bin/bash -lc 'command -v locale-gen >/dev/null 2>&1'; then
    chroot "$ROOT" /bin/bash -lc 'locale-gen && env-update' |& tee "$OUT/locale.log" || true
fi

log "Remove package caches and ebuild trees from runtime copy, retaining package records"
rm -rf "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/cache/edb/dep" \
    "$ROOT/var/tmp/portage" "$ROOT/var/log/portage" "$ROOT/var/log/emerge.log" \
    "$ROOT/var/log/gentoo-build-set.log" "$ROOT/var/db/repos/gentoo" "$ROOT/var/db/repos/guru" \
    "$ROOT/usr/src" "$ROOT/root/.cache"
mkdir -p "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles" "$ROOT/var/tmp/portage" "$ROOT/var/db/repos"
printf 'Source root: %s\nProfile: OpenRC desktop + fbterm/mc\nTarget: Core 2 Duo, -march=core2 -mtune=core2\nRuntime root: separate copy; build root/binpkgs preserved\nWritable upper: volatile RAM OverlayFS; changes vanish on reboot\n' \
    "$BUILD_ROOT" > "$OUT/RUNTIME-MANIFEST.txt"
find "$ROOT/var/db/pkg" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | sort > "$OUT/INSTALLED-PACKAGES.txt"

log "Build Zstandard SquashFS from runtime-only root"
bash "$REPO/scripts/build-squashfs-inplace.sh" "$ROOT" "$OUT/squashfs"
unsquashfs -s "$OUT/squashfs" | tee "$OUT/SQUASHFS-INFO.txt"
unsquashfs -ll "$OUT/squashfs" | grep -E 'sbin/init($| ->)' | tee "$OUT/INIT-PROBE.txt"
[[ -x "$ROOT/usr/bin/openbox-session" ]] || die "runtime root lost openbox-session"
[[ -x "$ROOT/usr/bin/Xorg" || -x "$ROOT/usr/libexec/Xorg" ]] || die "runtime root lost Xorg"
[[ -s "$OUT/squashfs" ]] || die "SquashFS output is empty"

df -h "$BUILD_ROOT" "$OUT" | tee "$OUT/DISK-AFTER-ROOTFS.txt"
SUCCESS=true
log "SquashFS build completed"
