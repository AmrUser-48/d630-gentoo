#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 GENTOO_ROOT NETWORK_ROOT OUTPUT_ROOT BASHRC BASH_PROFILE" >&2
  exit 2
fi

GENTOO_ROOT=$1
NETWORK_ROOT=$2
ROOT=$3
BASHRC=$4
BASH_PROFILE=$5

for path in "$GENTOO_ROOT" "$NETWORK_ROOT"; do
  [[ -d "$path" ]] || { echo "Required root not found: $path" >&2; exit 1; }
done
for file in "$BASHRC" "$BASH_PROFILE"; do
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
  done < <(awk '/=>/ && $3 ~ /^\// {print $3} $1 ~ /^\// {print $1}' \
    <<< "$dependencies" | sort -u)
}

copy_binary bash /bin/bash
copy_binary lf /usr/bin/lf
copy_binary doas /usr/bin/doas
chmod 4755 "$ROOT/usr/bin/doas"

terminfo="$GENTOO_ROOT/usr/share/terminfo"
[[ -d "$terminfo" ]] || {
  echo "Gentoo terminal definitions are missing." >&2
  exit 1
}
mkdir -p "$ROOT/usr/share"
cp -a "$terminfo" "$ROOT/usr/share/"

mkdir -p "$ROOT/etc/d630-tiny" "$ROOT/home/gmini"
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
printf 'Gentoo Mini setup environment\n' > "$ROOT/etc/d630-tiny/setup-mode"

for file in "$ROOT/bin/bash" "$ROOT/usr/bin/lf" "$ROOT/usr/bin/doas" \
  "$ROOT/etc/passwd" "$ROOT/etc/group" "$ROOT/etc/shadow" \
  "$ROOT/etc/doas.conf" "$ROOT/home/gmini/.bashrc" \
  "$ROOT/home/gmini/.bash_profile" "$ROOT/etc/d630-tiny/setup-mode"; do
  [[ -s "$file" ]] || { echo "Setup image file is missing: $file" >&2; exit 1; }
done
[[ "$(stat -c '%a' "$ROOT/usr/bin/doas")" == 4755 ]] || {
  echo "Gentoo doas must be installed setuid root in the setup image." >&2
  exit 1
}
