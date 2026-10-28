#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# -lt 5 || $# -gt 6 ]]; then
  echo "Usage: $0 BUSYBOX FIRMWARE_TAR_ZST EARLY_MICROCODE_CPIO OUTPUT_DIR INIT_SCRIPT [NETWORK_ROOT]" >&2
  exit 2
fi

BUSYBOX=$1
FIRMWARE_ARCHIVE=$2
EARLY_MICROCODE=$3
OUT=$4
INIT_SCRIPT=$5
NETWORK_ROOT=${6:-}
FIRMWARE_LIST="$(cd -- "$(dirname -- "$INIT_SCRIPT")" && pwd)/firmware-files.list"

for f in "$BUSYBOX" "$FIRMWARE_ARCHIVE" "$EARLY_MICROCODE" "$INIT_SCRIPT"; do
  [[ -s "$f" ]] || { echo "Missing required input: $f" >&2; exit 1; }
done
if [[ -n "$NETWORK_ROOT" && ! -d "$NETWORK_ROOT" ]]; then
  echo "Network tools root not found: $NETWORK_ROOT" >&2
  exit 1
fi
command -v cpio >/dev/null
command -v zstd >/dev/null
command -v tar >/dev/null

ROOT="$(mktemp -d)"
FWROOT="$(mktemp -d)"
MAIN_CPIO=""
cleanup() {
  rm -rf "$ROOT" "$FWROOT"
  [[ -z "$MAIN_CPIO" ]] || rm -f "$MAIN_CPIO"
}
trap cleanup EXIT
mkdir -p "$OUT" "$ROOT"/{bin,sbin,etc,dev/pts,dev/shm,proc,sys,run,tmp,root,lib/firmware,usr/share}
mkdir -p "$ROOT/lib/firmware/intel-ucode"

echo "initramfs-build: extract verified firmware"
tar --zstd -xf "$FIRMWARE_ARCHIVE" -C "$FWROOT"
[[ -s "$FWROOT/lib/firmware/iwlwifi-3945-2.ucode" ]] || {
  echo "D630 Intel 3945ABG firmware missing in pinned firmware bundle." >&2
  exit 1
}
cp "$BUSYBOX" "$ROOT/bin/busybox"
APPLET_LIST="$FWROOT/busybox-applets.txt"
"$ROOT/bin/busybox" --list > "$APPLET_LIST"
if ! grep -Fxq ash "$APPLET_LIST" && ! grep -Fxq sh "$APPLET_LIST"; then
  echo "Required BusyBox shell applet ash/sh is missing." >&2
  exit 1
fi
for applet in mount mkdir sleep cat uname setsid cttyhack poweroff hostname dmesg grep; do
  if ! grep -Fxq "$applet" "$APPLET_LIST"; then
    echo "Required BusyBox applet missing: $applet" >&2
    exit 1
  fi
done
if [[ -n "$NETWORK_ROOT" ]]; then
  for applet in ip udhcpc ifconfig route sed head id; do
    if ! grep -Fxq "$applet" "$APPLET_LIST"; then
      echo "Required networking BusyBox applet missing: $applet" >&2
      exit 1
    fi
  done
fi
SETUP_MODE=false
if [[ -n "$NETWORK_ROOT" && -f "$NETWORK_ROOT/etc/d630-tiny/setup-mode" ]]; then
  SETUP_MODE=true
  for applet in login chown umount chroot awk sort cut; do
    if ! grep -Fxq "$applet" "$APPLET_LIST"; then
      echo "Required setup BusyBox applet missing: $applet" >&2
      exit 1
    fi
  done
  [[ -s "$FIRMWARE_LIST" ]] || {
    echo "Requested firmware manifest is missing: $FIRMWARE_LIST" >&2
    exit 1
  }
fi
echo "initramfs-build: BusyBox applets verified"
"$ROOT/bin/busybox" --install -s "$ROOT/bin"
while IFS= read -r -d '' link; do
  ln -sfn busybox "$link"
done < <(find "$ROOT/bin" -mindepth 1 -maxdepth 1 -type l -print0)
ln -sfn busybox "$ROOT/bin/sh"
ln -sfn busybox "$ROOT/bin/static-sh"
"$ROOT/bin/sh" -c 'exit 0'
echo "initramfs-build: /bin/sh link validated"

cp "$INIT_SCRIPT" "$ROOT/init"
chmod 0755 "$ROOT/init"
cp -a "$FWROOT/lib/firmware/." "$ROOT/lib/firmware/"
if [[ -n "$NETWORK_ROOT" ]]; then
  cp -a "$NETWORK_ROOT/." "$ROOT/"
fi
if [[ "$SETUP_MODE" == true ]]; then
  firmware_count=0
  while IFS= read -r firmware || [[ -n "$firmware" ]]; do
    [[ -z "$firmware" || "$firmware" == \#* ]] && continue
    [[ "$firmware" =~ ^(i915|tigon)/[A-Za-z0-9._-]+$ ]] || {
      echo "Invalid firmware path in $FIRMWARE_LIST: $firmware" >&2
      exit 1
    }
    [[ -s "$ROOT/lib/firmware/$firmware" ]] || {
      echo "Requested firmware is absent from the staged image: $firmware" >&2
      exit 1
    }
    ((firmware_count += 1))
  done < "$FIRMWARE_LIST"
  [[ "$firmware_count" -eq 40 ]] || {
    echo "Expected 40 requested i915/tigon firmware files, found $firmware_count." >&2
    exit 1
  }
fi
if [[ -d "$FWROOT/usr/share/licenses" ]]; then
  mkdir -p "$ROOT/usr/share"
  cp -a "$FWROOT/usr/share/licenses" "$ROOT/usr/share/"
fi

cat > "$ROOT/etc/issue" <<'ISSUE'

  D630 TINY LINUX
  Core 2 Duo | BusyBox | RAM-only initramfs

ISSUE
cat > "$ROOT/etc/os-release" <<'OSRELEASE'
NAME="D630 Tiny Linux"
ID=d630-tiny
PRETTY_NAME="D630 Tiny Linux (standalone initramfs)"
VERSION_ID="0.1"
OSRELEASE

test -x "$ROOT/init"
test -x "$ROOT/bin/busybox"
test -x "$ROOT/bin/sh"
test -x "$ROOT/bin/static-sh"
[[ "$(readlink "$ROOT/bin/sh")" == busybox ]]
[[ "$(readlink "$ROOT/bin/static-sh")" == busybox ]]
while IFS= read -r -d '' link; do
  target="$(readlink "$link")"
  [[ "$target" != /* ]] || { echo "Absolute BusyBox link: $link -> $target" >&2; exit 1; }
  [[ -x "$(dirname "$link")/$target" ]] || { echo "Dangling BusyBox link: $link -> $target" >&2; exit 1; }
done < <(find "$ROOT/bin" -mindepth 1 -maxdepth 1 -type l -print0)

echo "initramfs-build: create Zstandard CPIO"
MAIN_CPIO="$(mktemp)"
if ! (
  cd "$ROOT"
  find . -print0 | LC_ALL=C sort -z | cpio --null --create --format=newc --owner=0:0
) > "$MAIN_CPIO" 2> "$OUT/tiny-cpio-build.log"; then
  echo "::error::CPIO archive creation failed; diagnostics follow." >&2
  cat "$OUT/tiny-cpio-build.log" >&2
  exit 1
fi
echo "initramfs-build: CPIO created ($(stat -c '%s' "$MAIN_CPIO") bytes)"
if ! zstd -q -T0 -3 -f "$MAIN_CPIO" -o "$OUT/tiny-main.cpio.zst"; then
  echo "::error::Zstandard compression failed." >&2
  exit 1
fi
chmod 0644 "$OUT/tiny-main.cpio.zst"
zstd -q -t "$OUT/tiny-main.cpio.zst"
echo "initramfs-build: Zstandard archive verified ($(stat -c '%s' "$OUT/tiny-main.cpio.zst") bytes)"
if ! cpio -it < "$MAIN_CPIO" > "$OUT/tiny-file-list.raw" 2> "$OUT/tiny-cpio-list.log"; then
  echo "::error::CPIO listing failed; diagnostics follow." >&2
  cat "$OUT/tiny-cpio-list.log" >&2
  exit 1
fi
sed 's#^\./##' "$OUT/tiny-file-list.raw" > "$OUT/tiny-file-list.txt"
required_members=(init bin/busybox lib/firmware/iwlwifi-3945-2.ucode)
if [[ -n "$NETWORK_ROOT" ]]; then
  required_members+=(usr/sbin/wifi-connect usr/share/udhcpc/default.script lib/firmware/regulatory.db)
fi
if [[ "$SETUP_MODE" == true ]]; then
  firmware_whence_member=""
  for candidate in usr/share/licenses/linux-firmware/WHENCE usr/share/licenses/linux-firmware/WHENCE.bz2; do
    if [[ -s "$ROOT/$candidate" ]]; then
      firmware_whence_member=$candidate
      break
    fi
  done
  [[ -n "$firmware_whence_member" && -d "$ROOT/usr/share/licenses/linux-firmware/LICENSES" ]] || {
    echo "Firmware license notices are missing from the staged image." >&2
    exit 1
  }
  required_members+=(
    bin/bash bin/login usr/bin/lf usr/bin/doas usr/bin/file usr/bin/cpio usr/bin/zstd usr/bin/setfont
    usr/sbin/rdmsr usr/sbin/wrmsr usr/sbin/lf-preview usr/sbin/rebuild-initramfs usr/sbin/gentoo-chroot
    usr/share/d630-tiny/early-microcode.cpio usr/share/d630-tiny/firmware-files.list
    usr/share/fonts/misc/ter-powerline-x16n.pcf.gz usr/share/fonts/misc/ter-powerline-x16b.pcf.gz
    usr/share/consolefonts/ter-powerline-v16n.psf.gz usr/share/consolefonts/ter-powerline-v16b.psf.gz
    usr/share/licenses/terminus-powerline/LICENSE.txt "$firmware_whence_member"
    usr/share/licenses/linux-firmware/LICENSES etc/passwd etc/group etc/shadow etc/doas.conf etc/motd
    home/gmini/.bashrc home/gmini/.bash_profile home/gmini/.config/lf/lfrc
    home/gmini/.config/lf/colors home/gmini/.config/lf/icons etc/d630-tiny/setup-mode
  )
  while IFS= read -r firmware || [[ -n "$firmware" ]]; do
    [[ -z "$firmware" || "$firmware" == \#* ]] && continue
    required_members+=("lib/firmware/$firmware")
  done < "$FIRMWARE_LIST"
fi
for member in "${required_members[@]}"; do
  if ! grep -Fxq "$member" "$OUT/tiny-file-list.txt"; then
    echo "::error::Archive member missing: $member" >&2
    cat "$OUT/tiny-file-list.txt" >&2
    exit 1
  fi
done
if [[ -n "$NETWORK_ROOT" ]] && ! grep -Eq '^usr/(bin|sbin)/curl$' "$OUT/tiny-file-list.txt"; then
  echo "::error::Archive has no Gentoo curl binary under /usr/bin or /usr/sbin." >&2
  cat "$OUT/tiny-file-list.txt" >&2
  exit 1
fi
if [[ "$SETUP_MODE" == true ]] && ! grep -Fxq 'gmini:x:1000:1000:Gentoo Mini:/home/gmini:/bin/bash' "$NETWORK_ROOT/etc/passwd"; then
  echo "::error::Setup account gmini is missing or has an unexpected shell." >&2
  exit 1
fi
echo "initramfs-build: required archive members verified"
cat "$EARLY_MICROCODE" "$OUT/tiny-main.cpio.zst" > "$OUT/initramfs"
test -s "$OUT/initramfs"
{
  echo "D630 Tiny standalone initramfs"
  if [[ "$SETUP_MODE" == true ]]; then
    echo "Init: /init starts BusyBox login as gmini with Gentoo Bash"
  else
    echo "Init: /init (BusyBox static interactive console shell)"
  fi
  echo "Main archive: newc CPIO + Zstandard level 3"
  echo "Early microcode: original uncompressed CPIO from the pinned D630 kernel release"
  echo "Firmware: Intel PRO/Wireless 3945ABG; license notices retained where provided"
  echo "Root model: RAM-only; no Gentoo root, SquashFS, OpenRC or systemd"
  if [[ -n "$NETWORK_ROOT" ]]; then
    echo "Networking: iw, WPA supplicant, BusyBox DHCP, rfkill, curl, and CA certificates"
  else
    echo "Networking: not included in this minimal shell variant"
  fi
  if [[ "$SETUP_MODE" == true ]]; then
    echo "Firmware additions: 36 requested i915 files and 4 tigon files, with WHENCE and LICENSES retained"
    echo "Setup user: gmini, Gentoo Bash/lf/file, msr-tools from binpkg, setfont, selected Terminus Powerline PCF/PSF, gentoo-chroot, and rebuild-initramfs"
  fi
  echo
  file "$BUSYBOX" "$EARLY_MICROCODE" "$OUT/tiny-main.cpio.zst" "$OUT/initramfs"
  echo
  du -h "$OUT/tiny-main.cpio.zst" "$OUT/initramfs"
} > "$OUT/INITRAMFS-MANIFEST.txt"
echo "Built initramfs: $(stat -c '%s' "$OUT/initramfs") bytes"
