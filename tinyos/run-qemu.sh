#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--assets-dir DIRECTORY]" >&2
  exit 2
}

assets_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --assets-dir)
      [[ -z "$assets_dir" && $# -ge 2 && -n "$2" ]] || usage
      assets_dir=$2
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

command -v sha256sum >/dev/null
command -v qemu-system-x86_64 >/dev/null || {
  echo "qemu-system-x86_64 is required to boot the test image." >&2
  exit 1
}

if [[ -z "$assets_dir" ]]; then
  command -v gh >/dev/null || {
    echo "gh is required to download the latest test image." >&2
    exit 1
  }
  tag=$(gh release view --repo AmrUser-48/d630-gentoo --json tagName --jq .tagName)
  cache_root=${XDG_CACHE_HOME:-"$HOME/.cache"}
  assets_dir="$cache_root/d630-tiny/$tag"
  mkdir -p "$assets_dir"
  release_assets=$(gh release view "$tag" --repo AmrUser-48/d630-gentoo --json assets --jq '.assets[].name')
  if ! grep -Fxq initramfs <<< "$release_assets"; then
    echo "Release $tag does not include the combined initramfs yet." >&2
    exit 1
  fi
  if [[ ! -s "$assets_dir/kernel" || ! -s "$assets_dir/initramfs" || ! -s "$assets_dir/SHA256SUMS" ]]; then
    gh release download "$tag" \
      --repo AmrUser-48/d630-gentoo \
      --dir "$assets_dir" \
      --pattern kernel \
      --pattern initramfs \
      --pattern SHA256SUMS \
      --clobber
  fi
fi

for asset in kernel initramfs SHA256SUMS; do
  [[ -s "$assets_dir/$asset" ]] || {
    echo "Missing required release asset: $assets_dir/$asset" >&2
    exit 1
  }
done

awk '
  $2 == "output/kernel" || $2 == "output/initramfs" {
    sub("output/", "", $2)
    print
    found[$2] = 1
  }
  END {
    if (!found["kernel"] || !found["initramfs"]) exit 1
  }
' "$assets_dir/SHA256SUMS" | (cd "$assets_dir" && sha256sum -c -)

exec qemu-system-x86_64 \
  -machine pc -accel tcg -cpu core2duo -m 4000 -smp 2 \
  -usb -device usb-net,netdev=net0 -netdev user,id=net0 \
  -kernel "$assets_dir/kernel" \
  -initrd "$assets_dir/initramfs" \
  -append 'console=ttyS0,115200n8 loglevel=4' \
  -nographic -monitor none
