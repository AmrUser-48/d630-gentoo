#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 NETWORKMANAGER_CONNECTION_NAME OUTPUT_DIRECTORY" >&2
  exit 2
fi

connection=$1
output_dir=$2

command -v nmcli >/dev/null || {
  echo "NetworkManager's nmcli is required on the host." >&2
  exit 1
}
command -v wpa_passphrase >/dev/null || {
  echo "wpa_passphrase is required on the host (usually from wpa_supplicant)." >&2
  exit 1
}
mkdir -p -- "$output_dir"
output_dir=$(cd -P -- "$output_dir" && pwd)
chmod 0700 "$output_dir"
destination="$output_dir/wifi.conf"
[[ ! -e "$destination" ]] || {
  echo "Refusing to overwrite existing Wi-Fi profile: $destination" >&2
  exit 1
}
if git -C "$output_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Refusing to write a Wi-Fi secret inside a Git working tree." >&2
  exit 1
fi

mapfile -t profile < <(
  nmcli --show-secrets --get-values \
    802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk \
    connection show "$connection"
)
[[ ${#profile[@]} -eq 3 ]] || {
  echo "Could not read the Wi-Fi profile. Check the connection name and that it is a Wi-Fi profile." >&2
  exit 1
}

ssid=${profile[0]}
key_mgmt=${profile[1]}
password=${profile[2]}
[[ -n "$ssid" && "$key_mgmt" == wpa-psk && ${#password} -ge 8 && ${#password} -le 63 ]] || {
  unset password profile
  echo "The profile must be WPA/WPA2-Personal with a saved 8-63 character passphrase." >&2
  exit 1
}

umask 077
temporary=$(mktemp "$output_dir/.wifi-profile.XXXXXX")
cleanup() {
  unset password profile
  rm -f -- "$temporary" "$temporary.raw"
}
trap cleanup EXIT

if ! printf '%s\n' "$password" | wpa_passphrase "$ssid" > "$temporary.raw"; then
  unset password profile
  echo "Could not convert the saved passphrase to wpa_supplicant format." >&2
  exit 1
fi
unset password profile
sed '/^[[:space:]]*#psk=/d' "$temporary.raw" > "$temporary"
rm -f -- "$temporary.raw"
mv -- "$temporary" "$destination"
trap - EXIT

echo "Saved Wi-Fi profile: $destination"
echo "It contains a reusable network key. Keep it private and delete it when no longer needed."
