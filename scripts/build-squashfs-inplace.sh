#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "d630-squashfs-inplace: ERROR: $*" >&2; exit 2; }
[[ "$EUID" -eq 0 ]] || die "run as root"
[[ $# -eq 2 ]] || die "usage: $0 <disposable-runtime-root> <output.squashfs>"
src="$(realpath "$1")"
output="$(realpath -m "$2")"
[[ -d "$src/etc" && -d "$src/usr" ]] || die "not a Linux runtime root: $src"
[[ "$output" != "$src" && "$output" != "$src/"* ]] || die "output must be outside the runtime root"
command -v mksquashfs >/dev/null || die "missing mksquashfs"

mkdir -p "$(dirname "$output")"
tmp_output="$output.tmp.$$"
cleanup() { rm -f "$tmp_output"; }
trap cleanup EXIT

# This root is already a disposable runtime copy. Prune it directly to avoid
# creating another full-sized staging tree on the hosted runner.
for path in \
    "$src/usr/share/doc" "$src/usr/share/info" "$src/usr/share/gtk-doc" \
    "$src/usr/share/help" "$src/usr/share/gnome/help" "$src/usr/share/aclocal" \
    "$src/usr/share/gettext" "$src/usr/src/debug" "$src/usr/lib/debug" \
    "$src/usr/lib64/debug" "$src/usr/include" "$src/usr/lib/pkgconfig" \
    "$src/usr/lib64/pkgconfig" "$src/usr/lib/cmake" "$src/usr/lib64/cmake" \
    "$src/var/tmp/portage" "$src/var/cache/distfiles" "$src/var/cache/binpkgs" \
    "$src/var/cache/edb/dep" "$src/var/log/portage" "$src/var/log/emerge.log" \
    "$src/var/log/gentoo-build-set.log"; do
    rm -rf "$path"
done

find "$src/usr" -type f \( -name '*.a' -o -name '*.la' -o -name '*.pyc' \) -delete 2>/dev/null || true
find "$src/usr" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true

# Regenerate the offline man-db index before detaching the runtime root's
# pseudo-filesystems. Keep the man pages and /var/db/pkg package records.
if [[ -x "$src/usr/bin/mandb" ]]; then
    for mp in dev proc sys run; do
        mountpoint -q "$src/$mp" || { mount --rbind "/$mp" "$src/$mp"; mount --make-rslave "$src/$mp"; }
    done
    chroot "$src" /usr/bin/mandb --create || echo "WARNING: mandb index refresh failed" >&2
fi

for mp in run sys proc dev; do
    mountpoint -q "$src/$mp" && umount -R "$src/$mp" 2>/dev/null || true
done
for mp in dev proc sys run tmp; do
    mkdir -p "$src/$mp"
    find "$src/$mp" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
done
mkdir -p "$src/var/tmp/portage" "$src/var/cache/distfiles" "$src/var/cache/binpkgs"

bash "$(dirname -- "${BASH_SOURCE[0]}")/validate-runtime-symlinks.sh" "$src"

rm -f "$tmp_output"
echo "Packing disposable runtime root directly (no duplicate staging copy): $src"
mksquashfs "$src" "$tmp_output" -noappend -comp zstd -b 1M -Xcompression-level 15
[[ -s "$tmp_output" ]] || die "mksquashfs produced no output"
mv -f "$tmp_output" "$output"
echo "SquashFS ready: $output"
du -sh "$src" "$output"
echo "Preserved /usr/share/man, /usr/share/licenses, and /var/db/pkg."
