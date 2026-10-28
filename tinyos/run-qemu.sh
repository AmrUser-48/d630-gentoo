#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--internet] [--assets-dir DIRECTORY]" >&2
  exit 2
}

internet=false
assets_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --internet)
      [[ "$internet" == false ]] || usage
      internet=true
      shift
      ;;
    --assets-dir)
      [[ -z "$assets_dir" && $# -ge 2 ]] || usage
      assets_dir=$2
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

tag=$(gh release view --repo AmrUser-48/d630-gentoo --json tagName --jq .tagName)
initramfs_asset=initramfs
if [[ "$internet" == true ]]; then
  initramfs_asset=initramfs-internet
fi

if [[ -z "$assets_dir" ]]; then
  cache_root=${XDG_CACHE_HOME:-"$HOME/.cache"}
  assets_dir="$cache_root/d630-tiny/$tag"
  mkdir -p "$assets_dir"
  release_assets=$(gh release view "$tag" --repo AmrUser-48/d630-gentoo --json assets --jq '.assets[].name')
  if ! grep -Fxq "$initramfs_asset" <<< "$release_assets"; then
    echo "Release $tag does not include '$initramfs_asset'." >&2
    if [[ "$internet" == true ]]; then
      echo "The internet-enabled initramfs has not been published yet; use the standard initramfs or wait for the build workflow." >&2
    fi
    exit 1
  fi
  gh release download "$tag" \
    --repo AmrUser-48/d630-gentoo \
    --dir "$assets_dir" \
    --pattern kernel \
    --pattern "$initramfs_asset" \
    --pattern SHA256SUMS
fi

for asset in kernel "$initramfs_asset" SHA256SUMS; do
  [[ -s "$assets_dir/$asset" ]] || {
    echo "Missing required release asset: $assets_dir/$asset" >&2
    exit 1
  }
done

awk -v asset="$initramfs_asset" '$2 == "output/kernel" || $2 == "output/" asset {
  sub("output/", "", $2)
  print
}' "$assets_dir/SHA256SUMS" | (cd "$assets_dir" && sha256sum -c -)

qemu_args=(
  -machine pc -accel tcg -cpu core2duo -m 512 -smp 2 \
  -kernel "$assets_dir/kernel" \
  -initrd "$assets_dir/$initramfs_asset" \
  -append 'console=ttyS0,115200n8 loglevel=4' \
  -nographic -monitor none
)
if [[ "$initramfs_asset" == initramfs-internet ]]; then
  qemu_args+=(-usb -device usb-net,netdev=net0 -netdev user,id=net0)
fi

exec qemu-system-x86_64 "${qemu_args[@]}"
