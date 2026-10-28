#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 GENTOO_ROOT OUTPUT_ROOT WIFI_CONNECT DHCP_SCRIPT" >&2
  exit 2
fi

GENTOO_ROOT=$1
ROOT=$2
WIFI_CONNECT=$3
DHCP_SCRIPT=$4

[[ -d "$GENTOO_ROOT" ]] || { echo "Gentoo package root not found: $GENTOO_ROOT" >&2; exit 1; }

for f in "$WIFI_CONNECT" "$DHCP_SCRIPT"; do
  [[ -s "$f" ]] || { echo "Missing required input: $f" >&2; exit 1; }
done

mkdir -p "$ROOT"
ldd_path="$(chroot "$GENTOO_ROOT" /bin/sh -c 'command -v ldd')" || {
  echo "Gentoo root has no ldd command." >&2
  exit 1
}
ldconfig_path="$(chroot "$GENTOO_ROOT" /bin/sh -c 'command -v ldconfig')" || {
  echo "Gentoo root has no ldconfig command." >&2
  exit 1
}

for app in iw wpa_supplicant wpa_passphrase wpa_cli curl; do
  binary="$(chroot "$GENTOO_ROOT" /bin/sh -c 'command -v "$1"' sh "$app")" || {
    echo "Required Gentoo network package binary not found: $app" >&2
    exit 1
  }
  [[ "$binary" == /* && -x "$GENTOO_ROOT$binary" ]] || {
    echo "Invalid or missing Gentoo binary path for $app: $binary" >&2
    exit 1
  }
  (cd "$GENTOO_ROOT" && cp -L --parents "${binary#/}" "$ROOT")

  dependencies="$(chroot "$GENTOO_ROOT" "$ldd_path" "$binary")" || {
    echo "Could not inspect Gentoo library dependencies for $binary" >&2
    exit 1
  }
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
done

ca_bundle="$GENTOO_ROOT/etc/ssl/certs/ca-certificates.crt"
[[ -s "$ca_bundle" ]] || {
  echo "Gentoo CA certificate bundle is missing; install app-misc/ca-certificates." >&2
  exit 1
}
install -D -m 0644 "$ca_bundle" "$ROOT/etc/ssl/certs/ca-certificates.crt"
ln -sfn certs/ca-certificates.crt "$ROOT/etc/ssl/cert.pem"
cat > "$ROOT/etc/nsswitch.conf" <<'NSSWITCH'
passwd: files
group: files
shadow: files
hosts: files dns
NSSWITCH
printf '127.0.0.1 localhost\n::1 localhost\n' > "$ROOT/etc/hosts"
for module in libnss_dns.so.2 libnss_files.so.2; do
  library="$(chroot "$GENTOO_ROOT" "$ldconfig_path" -p |
    awk -v name="$module" '$1 == name {print $NF; exit}')"
  [[ -n "$library" && -s "$GENTOO_ROOT$library" ]] || {
    echo "Required Gentoo glibc name-service module missing: $module" >&2
    exit 1
  }
  (cd "$GENTOO_ROOT" && cp -L --parents "${library#/}" "$ROOT")
  dependencies="$(chroot "$GENTOO_ROOT" "$ldd_path" "$library")" || {
    echo "Could not inspect Gentoo library dependencies for $library" >&2
    exit 1
  }
  if grep -Fq 'not found' <<< "$dependencies"; then
    printf '%s\n' "$dependencies" >&2
    echo "Unresolved Gentoo library dependency for $library" >&2
    exit 1
  fi
  while IFS= read -r dependency; do
    [[ -s "$GENTOO_ROOT$dependency" ]] || {
      echo "Gentoo library dependency is missing: $dependency" >&2
      exit 1
    }
    (cd "$GENTOO_ROOT" && cp -L --parents "${dependency#/}" "$ROOT")
  done < <(awk '/=>/ && $3 ~ /^\// {print $3} $1 ~ /^\// {print $1}' \
    <<< "$dependencies" | sort -u)
done

regdb_found=false
for firmware_dir in lib/firmware usr/lib/firmware; do
  for firmware in regulatory.db regulatory.db.p7s; do
    source="$GENTOO_ROOT/$firmware_dir/$firmware"
    if [[ -s "$source" ]]; then
      install -D -m 0644 "$source" "$ROOT/lib/firmware/$firmware"
      [[ "$firmware" != regulatory.db ]] || regdb_found=true
    fi
  done
done
[[ "$regdb_found" == true ]] || {
  echo "Gentoo wireless-regdb package did not provide regulatory.db." >&2
  exit 1
}
mkdir -p "$ROOT/etc"
: > "$ROOT/etc/resolv.conf"
install -D -m 0755 "$WIFI_CONNECT" "$ROOT/usr/sbin/wifi-connect"
install -D -m 0755 "$DHCP_SCRIPT" "$ROOT/usr/share/udhcpc/default.script"
mkdir -p "$ROOT/usr/share/d630-tiny"
cat > "$ROOT/usr/share/d630-tiny/network-tools.txt" <<'TOOLS'
Gentoo binaries: iw, wpa_supplicant, wpa_passphrase, wpa_cli, curl
DHCP: BusyBox udhcpc with /usr/share/udhcpc/default.script
Downloads: curl with Gentoo CA certificates and resolver modules
TOOLS
