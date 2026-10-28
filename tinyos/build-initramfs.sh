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
echo "initramfs-build: required archive members verified"
cat "$EARLY_MICROCODE" "$OUT/tiny-main.cpio.zst" > "$OUT/initramfs"
test -s "$OUT/initramfs"
{
  echo "D630 Tiny standalone initramfs"
  echo "Init: /init (BusyBox static interactive console shell)"
  echo "Main archive: newc CPIO + Zstandard level 3"
  echo "Early microcode: original uncompressed CPIO from the pinned D630 kernel release"
  echo "Firmware: Intel PRO/Wireless 3945ABG; license notices retained where provided"
  echo "Root model: RAM-only; no Gentoo root, SquashFS, OpenRC or systemd"
  if [[ -n "$NETWORK_ROOT" ]]; then
    echo "Networking: iw, WPA supplicant, BusyBox DHCP, rfkill, curl, and CA certificates"
  else
    echo "Networking: not included in this minimal shell variant"
  fi
  echo
  file "$BUSYBOX" "$EARLY_MICROCODE" "$OUT/tiny-main.cpio.zst" "$OUT/initramfs"
  echo
  du -h "$OUT/tiny-main.cpio.zst" "$OUT/initramfs"
} > "$OUT/INITRAMFS-MANIFEST.txt"
echo "Built initramfs: $(stat -c '%s' "$OUT/initramfs") bytes"
