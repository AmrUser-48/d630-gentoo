#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 12 ]]; then
  echo "Usage: $0 GENTOO_ROOT NETWORK_ROOT OUTPUT_ROOT BASHRC BASH_PROFILE LFRC LFCOLORS LFICONS LFPREVIEW REBUILD_SCRIPT EARLY_MICROCODE POWERLINE_FONTS_ROOT" >&2
  exit 2
fi

GENTOO_ROOT=$1
NETWORK_ROOT=$2
ROOT=$3
BASHRC=$4
BASH_PROFILE=$5
LFRC=$6
LFCOLORS=$7
LFICONS=$8
LFPREVIEW=$9
REBUILD_SCRIPT=${10}
EARLY_MICROCODE=${11}
POWERLINE_FONTS_ROOT=${12}
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
FIRMWARE_LIST="$SCRIPT_DIR/firmware-files.list"

for path in "$GENTOO_ROOT" "$NETWORK_ROOT" "$POWERLINE_FONTS_ROOT"; do
  [[ -d "$path" ]] || { echo "Required root not found: $path" >&2; exit 1; }
done
for file in "$BASHRC" "$BASH_PROFILE" "$LFRC" "$LFCOLORS" "$LFICONS" "$LFPREVIEW" "$REBUILD_SCRIPT" "$EARLY_MICROCODE" "$FIRMWARE_LIST" "$SCRIPT_DIR/gentoo-chroot"; do
  [[ -s "$file" ]] || { echo "Required shell configuration is missing: $file" >&2; exit 1; }
done

mkdir -p "$ROOT"
cp -a "$NETWORK_ROOT/." "$ROOT/"
ldd_path="$(chroot "$GENTOO_ROOT" /bin/sh -c 'command -v ldd')" || {
  echo "Gentoo root has no ldd command." >&2
  exit 1
}

copy_binary() {
  local app=$1 target=$2 binary dependencies library
  binary="$(chroot "$GENTOO_ROOT" /bin/sh -c 'command -v "$1"' sh "$app")" || {
    echo "Required Gentoo setup package binary not found: $app" >&2
    exit 1
  }
  [[ "$binary" == /* && -x "$GENTOO_ROOT$binary" ]] || {
    echo "Invalid or missing Gentoo binary path for $app: $binary" >&2
    exit 1
  }
  install -D -m 0755 "$GENTOO_ROOT$binary" "$ROOT$target"

  if dependencies="$(chroot "$GENTOO_ROOT" "$ldd_path" "$binary" 2>&1)"; then
    :
  elif grep -Fq 'not a dynamic executable' <<< "$dependencies"; then
    dependencies=""
  else
    printf '%s\n' "$dependencies" >&2
    echo "Could not inspect Gentoo library dependencies for $binary" >&2
    exit 1
  fi
  if grep -Fq 'not found' <<< "$dependencies"; then
    printf '%s\n' "$dependencies" >&2
    echo "Unresolved shared-library dependency for $binary" >&2
    exit 1
  fi
  while IFS= read -r library; do
    [[ -s "$GENTOO_ROOT$library" ]] || {
      echo "Gentoo library dependency is missing: $library" >&2
      exit 1
    }
    (cd "$GENTOO_ROOT" && cp -L --parents "${library#/}" "$ROOT")
    # GCC keeps some runtime libraries in its private lib directory. The
    # initramfs has no Gentoo ld.so cache/config, so expose those by SONAME
    # in the standard system library directory as well.
    case "$library" in
      /usr/lib/gcc/*|/usr/lib64/gcc/*|/lib/gcc/*|/lib64/gcc/*)
        install -D -m 0644 "$GENTOO_ROOT$library" "$ROOT/usr/lib64/$(basename "$library")"
        ;;
    esac
  done < <(awk '/=>/ && $3 ~ /^\// {print $3} $1 ~ /^\// {print $1}' \
    <<< "$dependencies" | sort -u)
}

copy_binary bash /bin/bash
copy_binary lf /usr/bin/lf
copy_binary doas /usr/bin/doas
copy_binary file /usr/bin/file
copy_binary cpio /usr/bin/cpio
copy_binary zstd /usr/bin/zstd
copy_binary rdmsr /usr/sbin/rdmsr
copy_binary wrmsr /usr/sbin/wrmsr
copy_binary setfont /usr/bin/setfont
copy_binary openvt /usr/bin/openvt
copy_binary fbterm /usr/bin/fbterm
copy_binary fc-match /usr/bin/fc-match
copy_binary fc-cache /usr/bin/fc-cache
chmod 4755 "$ROOT/usr/bin/doas"

magic_db="$GENTOO_ROOT/usr/share/misc/magic.mgc"
[[ -s "$magic_db" ]] || {
  echo "Gentoo file package magic database is missing." >&2
  exit 1
}
install -D -m 0644 "$magic_db" "$ROOT/usr/share/misc/magic.mgc"

terminfo="$GENTOO_ROOT/usr/share/terminfo"
[[ -d "$terminfo" ]] || {
  echo "Gentoo terminal definitions are missing." >&2
  exit 1
}
mkdir -p "$ROOT/usr/share"
cp -a "$terminfo" "$ROOT/usr/share/"

config_dir=etc/fonts
[[ -d "$GENTOO_ROOT/$config_dir" && -s "$GENTOO_ROOT/$config_dir/fonts.conf" ]] || {
  echo "Gentoo fontconfig configuration is missing: /etc/fonts/fonts.conf" >&2
  exit 1
}
mkdir -p "$ROOT/etc"
cp -a "$GENTOO_ROOT/etc/fonts" "$ROOT/etc/"

mkdir -p "$ROOT/etc/d630-tiny" "$ROOT/home/gmini"
install -D -m 0755 "$REBUILD_SCRIPT" "$ROOT/usr/sbin/rebuild-initramfs"
install -D -m 0755 "$SCRIPT_DIR/gentoo-chroot" "$ROOT/usr/sbin/gentoo-chroot"
install -D -m 0644 "$EARLY_MICROCODE" "$ROOT/usr/share/d630-tiny/early-microcode.cpio"
install -D -m 0644 "$FIRMWARE_LIST" "$ROOT/usr/share/d630-tiny/firmware-files.list"

firmware_count=0
while IFS= read -r firmware || [[ -n "$firmware" ]]; do
  [[ -z "$firmware" || "$firmware" == \#* ]] && continue
  [[ "$firmware" =~ ^(i915|tigon)/[A-Za-z0-9._-]+$ ]] || {
    echo "Invalid firmware path in $FIRMWARE_LIST: $firmware" >&2
    exit 1
  }
  source="$GENTOO_ROOT/lib/firmware/$firmware"
  [[ -s "$source" ]] || source="$GENTOO_ROOT/usr/lib/firmware/$firmware"
  [[ -s "$source" ]] || {
    echo "Requested firmware is missing from sys-kernel/linux-firmware: $firmware" >&2
    exit 1
  }
  install -D -m 0644 "$source" "$ROOT/lib/firmware/$firmware"
  ((firmware_count += 1))
done < "$FIRMWARE_LIST"
[[ "$firmware_count" -eq 40 ]] || {
  echo "Expected 40 requested i915/tigon firmware files, found $firmware_count." >&2
  exit 1
}

firmware_docs=$(find "$GENTOO_ROOT/usr/share/doc" -maxdepth 1 -type d -name 'linux-firmware-*' -print -quit)
[[ -n "$firmware_docs" && -d "$firmware_docs/LICENSES" ]] || {
  echo "Linux firmware license notices are missing from the Gentoo staging root." >&2
  exit 1
}
firmware_whence="$firmware_docs/WHENCE"
[[ -s "$firmware_whence" ]] || firmware_whence="$firmware_docs/WHENCE.bz2"
[[ -s "$firmware_whence" && -n "$(find "$firmware_docs/LICENSES" -type f -print -quit)" ]] || {
  echo "Linux firmware WHENCE or LICENSES files are missing from the Gentoo staging root." >&2
  exit 1
}
mkdir -p "$ROOT/usr/share/licenses/linux-firmware"
cp -a "$firmware_whence" "$firmware_docs/LICENSES" "$ROOT/usr/share/licenses/linux-firmware/"

for font in ter-powerline-x16n.pcf.gz ter-powerline-x16b.pcf.gz; do
  [[ -s "$POWERLINE_FONTS_ROOT/PCF/$font" ]] || {
    echo "Required Terminus Powerline PCF font is missing: $font" >&2
    exit 1
  }
  install -D -m 0644 "$POWERLINE_FONTS_ROOT/PCF/$font" "$ROOT/usr/share/fonts/misc/$font"
done
for font in ter-powerline-v16n.psf.gz ter-powerline-v16b.psf.gz; do
  [[ -s "$POWERLINE_FONTS_ROOT/PSF/$font" ]] || {
    echo "Required Terminus Powerline console font is missing: $font" >&2
    exit 1
  }
  install -D -m 0644 "$POWERLINE_FONTS_ROOT/PSF/$font" "$ROOT/usr/share/consolefonts/$font"
done
# Prebuild fontconfig's cache inside the staged root. At runtime gmini cannot
# write the system cache, and without this cache fc-match may return a fallback.
mkdir -p "$ROOT/var/cache/fontconfig"
if ! chroot "$ROOT" /usr/bin/fc-cache -f; then
  echo "Could not build fontconfig cache for the staged Powerline fonts." >&2
  exit 1
fi
font_match="$(chroot "$ROOT" /usr/bin/fc-match -f '%{family} %{style}' 'xos4 Terminess Powerline')"
printf 'Staged Powerline font match: %s\n' "$font_match"
[[ "$font_match" == *"Terminess Powerline Regular"* ]] || {
  echo "Staged fontconfig did not select the expected Terminus Powerline font." >&2
  exit 1
}
rm -f "$ROOT/usr/bin/fc-cache"
[[ -s "$POWERLINE_FONTS_ROOT/LICENSE.txt" ]] || {
  echo "Terminus Powerline font license is missing." >&2
  exit 1
}
install -D -m 0644 "$POWERLINE_FONTS_ROOT/LICENSE.txt" "$ROOT/usr/share/licenses/terminus-powerline/LICENSE.txt"
cat > "$ROOT/etc/motd" <<'MOTD'
 ██████╗ ███████╗███╗   ██╗████████╗ ██████╗  ██████╗
██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔═══██╗
██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║   ██║██║   ██║
██║   ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║██║   ██║
╚██████╔╝███████╗██║ ╚████║   ██║   ╚██████╔╝╚██████╔╝
 ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  ╚═════╝
MOTD
printf '\nGentoo Mini | D630 setup environment\n' >> "$ROOT/etc/motd"
cat > "$ROOT/etc/passwd" <<'PASSWD'
root:x:0:0:root:/root:/bin/sh
gmini:x:1000:1000:Gentoo Mini:/home/gmini:/bin/bash
PASSWD
cat > "$ROOT/etc/group" <<'GROUP'
root:x:0:
wheel:x:10:root
users:x:100:
gmini:x:1000:
shadow:x:42:
GROUP
cat > "$ROOT/etc/shadow" <<'SHADOW'
root:*:19700:0:99999:7:::
gmini::19700:0:99999:7:::
SHADOW
chmod 0640 "$ROOT/etc/shadow"
cat > "$ROOT/etc/profile" <<'PROFILE'
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export TERM=${TERM:-linux}
PROFILE
cat > "$ROOT/etc/doas.conf" <<'DOAS'
permit nopass gmini as root
DOAS
chmod 0600 "$ROOT/etc/doas.conf"
install -m 0644 "$BASHRC" "$ROOT/home/gmini/.bashrc"
install -m 0644 "$BASH_PROFILE" "$ROOT/home/gmini/.bash_profile"
install -D -m 0644 "$LFRC" "$ROOT/home/gmini/.config/lf/lfrc"
install -D -m 0644 "$LFCOLORS" "$ROOT/home/gmini/.config/lf/colors"
install -D -m 0644 "$LFICONS" "$ROOT/home/gmini/.config/lf/icons"
cat > "$ROOT/home/gmini/.fbtermrc" <<'FBTERM'
font-names=xos4 Terminess Powerline
font-size=16
FBTERM
install -D -m 0755 "$LFPREVIEW" "$ROOT/usr/sbin/lf-preview"
printf 'Gentoo Mini setup environment\n' > "$ROOT/etc/d630-tiny/setup-mode"

for file in "$ROOT/bin/bash" "$ROOT/usr/bin/lf" "$ROOT/usr/bin/doas" "$ROOT/usr/bin/file" \
  "$ROOT/usr/bin/cpio" "$ROOT/usr/bin/zstd" "$ROOT/usr/sbin/rdmsr" "$ROOT/usr/sbin/wrmsr" \
  "$ROOT/usr/bin/setfont" "$ROOT/usr/bin/openvt" "$ROOT/usr/bin/fbterm" \
  "$ROOT/usr/bin/fc-match" \
  "$ROOT/usr/sbin/gentoo-chroot" "$ROOT/usr/sbin/rebuild-initramfs" \
  "$ROOT/usr/share/fonts/misc/ter-powerline-x16n.pcf.gz" \
  "$ROOT/usr/share/fonts/misc/ter-powerline-x16b.pcf.gz" \
  "$ROOT/usr/share/consolefonts/ter-powerline-v16n.psf.gz" \
  "$ROOT/usr/share/consolefonts/ter-powerline-v16b.psf.gz" \
  "$ROOT/usr/share/licenses/terminus-powerline/LICENSE.txt" \
  "$ROOT/usr/share/d630-tiny/firmware-files.list" \
  "$ROOT/usr/share/d630-tiny/early-microcode.cpio" \
  "$ROOT/etc/passwd" "$ROOT/etc/group" "$ROOT/etc/shadow" \
  "$ROOT/etc/doas.conf" "$ROOT/etc/motd" "$ROOT/usr/sbin/lf-preview" "$ROOT/home/gmini/.fbtermrc" "$ROOT/home/gmini/.bashrc" \
  "$ROOT/home/gmini/.bash_profile" "$ROOT/home/gmini/.config/lf/lfrc" \
  "$ROOT/home/gmini/.config/lf/colors" "$ROOT/home/gmini/.config/lf/icons" \
  "$ROOT/etc/d630-tiny/setup-mode"; do
  [[ -s "$file" ]] || { echo "Setup image file is missing: $file" >&2; exit 1; }
done
[[ "$(wc -l < "$FIRMWARE_LIST")" -eq 40 ]] || {
  echo "Firmware manifest must contain exactly 40 files." >&2
  exit 1
}
[[ -d "$ROOT/usr/share/licenses/linux-firmware/LICENSES" ]] &&
  { [[ -s "$ROOT/usr/share/licenses/linux-firmware/WHENCE" ]] ||
    [[ -s "$ROOT/usr/share/licenses/linux-firmware/WHENCE.bz2" ]]; } || {
  echo "Firmware license notices were not staged." >&2
  exit 1
}
[[ "$(stat -c '%a' "$ROOT/usr/bin/doas")" == 4755 ]] || {
  echo "Gentoo doas must be installed setuid root in the setup image." >&2
  exit 1
}
