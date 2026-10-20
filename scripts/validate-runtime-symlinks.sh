#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "d630-root-symlinks: ERROR: $*" >&2; exit 2; }
[[ $# -eq 1 ]] || die "usage: $0 <runtime-root>"
ROOT="$(realpath "$1")"
[[ -x "$ROOT/bin/bash" ]] || die "runtime root has no runnable /bin/bash"
for tool in chroot mount umount mountpoint; do
  command -v "$tool" >/dev/null || die "missing host tool: $tool"
done

declare -A mounted_here=()
cleanup() {
  for mp in run sys proc dev; do
    if [[ ${mounted_here[$mp]:-0} == 1 ]] && mountpoint -q "$ROOT/$mp"; then
      umount -R "$ROOT/$mp" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

# Resolve links from inside the image's own root namespace, not the host root.
# Temporary runtime mount targets (/dev, /proc, /sys, /run and /tmp) are allowed.
for mp in dev proc sys run; do
  mkdir -p "$ROOT/$mp"
  if ! mountpoint -q "$ROOT/$mp"; then
    mount --rbind "/$mp" "$ROOT/$mp" || die "cannot bind-mount /$mp for symlink validation"
    mount --make-rslave "$ROOT/$mp"
    mounted_here["$mp"]=1
  fi
done

chroot "$ROOT" /bin/bash --noprofile --norc -c '
set -uo pipefail
broken=0
checked=0
while IFS= read -r -d "" link; do
  target="$(readlink -- "$link")" || {
    printf "UNREADABLE-SYMLINK: %s\n" "$link" >&2
    ((broken++))
    continue
  }
  case "$target" in
    /dev/*|/proc/*|/sys/*|/run/*|/tmp/*) continue ;;
  esac
  ((checked++))
  if [[ ! -e "$link" ]]; then
    printf "DANGLING-SYMLINK: %s -> %s\n" "$link" "$target" >&2
    ((broken++))
  fi
done < <(find / -xdev -type l -print0 2>/dev/null)
printf "Runtime symlink audit: checked %d links; found %d dangling/unreadable links.\n" "$checked" "$broken"
(( broken == 0 ))
' || die "runtime root contains invalid persistent symlinks"

for mp in run sys proc dev; do
  if [[ ${mounted_here[$mp]:-0} == 1 ]] && mountpoint -q "$ROOT/$mp"; then
    umount -R "$ROOT/$mp" || die "failed to unmount $ROOT/$mp after symlink audit"
    unset 'mounted_here[$mp]'
  fi
done
trap - EXIT
