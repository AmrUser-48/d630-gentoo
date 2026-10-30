#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 <clean-runtime-rootfs> <output.squashfs>" >&2
  exit 2
}
[[ $# -eq 2 ]] || usage
[[ "$EUID" -eq 0 ]] || { echo "Run as root: sudo $0 ROOTFS OUTPUT.squashfs" >&2; exit 1; }
MINIMAL_RUNTIME="${MINIMAL_RUNTIME:-false}"
[[ "$MINIMAL_RUNTIME" == true || "$MINIMAL_RUNTIME" == false ]] || {
  echo "MINIMAL_RUNTIME must be true or false." >&2
  exit 2
}
command -v rsync >/dev/null || { echo "Required command missing: rsync" >&2; exit 1; }
command -v mksquashfs >/dev/null || { echo "Required command missing: mksquashfs (squashfs-tools)" >&2; exit 1; }

src="$(realpath "$1")"
output="$(realpath -m "$2")"
[[ -d "$src/etc" && -d "$src/usr" ]] || {
  echo "Input does not look like a Linux rootfs: $src" >&2
  exit 1
}
[[ "$output" != "$src" && "$output" != "$src/"* ]] || {
  echo "Output must not be inside the source rootfs." >&2
  exit 1
}
mkdir -p "$(dirname "$output")"
stage="$(mktemp -d "${TMPDIR:-/var/tmp}/d630-squashfs.XXXXXXXX")"
tmp_output=""
tmp_filelist=""
cleanup() {
  for mountpoint in run sys proc dev; do
    if mountpoint -q "$stage/$mountpoint" 2>/dev/null; then
      umount -R "$stage/$mountpoint" 2>/dev/null || true
    fi
  done
  [[ -z "$tmp_output" ]] || rm -f "$tmp_output"
  [[ -z "$tmp_filelist" ]] || rm -f "$tmp_filelist"
  rm -rf "$stage"
}
trap cleanup EXIT

echo "Copying clean runtime root to staging: $src -> $stage"
rsync -aHAX --numeric-ids --one-file-system --delete \
  --exclude='/dev/***' \
  --exclude='/proc/***' \
  --exclude='/sys/***' \
  --exclude='/run/***' \
  --exclude='/tmp/***' \
  --exclude='/var/tmp/portage/***' \
  --exclude='/var/cache/***' \
  --exclude='/var/db/repos/gentoo/***' \
  --exclude='/var/log/portage/***' \
  --exclude='/var/log/emerge.log' \
  --exclude='/var/log/gentoo-build-set.log' \
  --exclude='/usr/share/doc/***' \
  --exclude='/usr/share/info/***' \
  --exclude='/usr/share/gtk-doc/***' \
  --exclude='/usr/share/help/***' \
  --exclude='/usr/share/gnome/help/***' \
  --exclude='/usr/include/***' \
  --exclude='/usr/lib*/pkgconfig/***' \
  --exclude='/usr/lib*/cmake/***' \
  --exclude='/usr/share/aclocal/***' \
  --exclude='/usr/share/gettext/***' \
  --exclude='/usr/src/debug/***' \
  --exclude='/usr/lib/debug/***' \
  --exclude='/usr/lib64/debug/***' \
  "$src/" "$stage/"

if awk -F: '$3 == 1000 { found = 1 } END { exit !found }' "$stage/etc/passwd"; then
  echo "UID 1000 is assigned in the runtime root; refusing to normalize host-owned files." >&2
  exit 1
fi
if awk -F: '$3 == 1000 { found = 1 } END { exit !found }' "$stage/etc/group"; then
  echo "GID 1000 is assigned in the runtime root; refusing to normalize host-owned files." >&2
  exit 1
fi
find "$stage" -xdev -uid 1000 -exec chown -h 0 {} +
find "$stage" -xdev -gid 1000 -exec chgrp -h 0 {} +
chown 0:0 "$stage/var"
chmod 0755 "$stage/var"
if find "$stage" -xdev \( -uid 1000 -o -gid 1000 \) -print -quit | grep -q .; then
  echo "Runtime staging tree still contains host UID/GID 1000 ownership." >&2
  exit 1
fi

if [[ "$MINIMAL_RUNTIME" == true ]]; then
  package_db="$src/var/db/pkg"
  if find "$package_db/llvm-core" -mindepth 1 -maxdepth 1 -type d \
      \( -name 'llvm-*' -o -name 'clang-*' \) -print -quit 2>/dev/null | grep -q .; then
    echo "LLVM/Clang package records are present in the input root; refusing to build this runtime image." >&2
    exit 1
  fi

  remove_package_contents() {
    local package_dir="$1" keep_gcc_runtime="${2:-false}" entry path
    [[ -f "$package_dir/CONTENTS" ]] || return 0
    while read -r entry path _; do
      [[ "$path" == /* && "$path" != "/" && "$path" != *"/../"* ]] || continue
      if [[ "$keep_gcc_runtime" == true ]]; then
        case "$path" in
          /usr/lib/gcc/*/*/libgcc_s.so.[0-9]*|\
          /usr/lib/gcc/*/*/libstdc++.so.[0-9]*|\
          /usr/lib/gcc/*/*/libatomic.so.[0-9]*) continue
          ;;
        esac
      fi
      case "$entry" in
        obj|sym) rm -f -- "$stage$path" ;;
        dir) rmdir --ignore-fail-on-non-empty -- "$stage$path" 2>/dev/null || true ;;
      esac
    done < "$package_dir/CONTENTS"
  }
  remove_package_payload() {
    local atom="$1" keep_gcc_runtime="${2:-false}" category package package_dir
    category="${atom%%/*}"
    package="${atom#*/}"
    for package_dir in "$package_db/$category/$package"-[0-9]*; do
      remove_package_contents "$package_dir" "$keep_gcc_runtime"
    done
  }

  echo "Removing Portage, language runtimes, development tools, and compiler binaries."
  for atom in \
    sys-apps/portage sys-apps/man-db app-portage/gemato app-portage/getuto app-portage/portage-utils \
    app-admin/eselect app-admin/perl-cleaner sys-apps/locale-gen \
    dev-lang/perl \
    dev-build/make \
    sys-devel/binutils sys-devel/binutils-config sys-devel/gcc-config \
    sys-devel/gettext sys-devel/gnuconfig sys-devel/patch \
    dev-libs/gobject-introspection-common; do
    remove_package_payload "$atom"
  done
  for family in dev-perl dev-util perl-core app-eselect; do
    for package_dir in "$package_db/$family"/*; do
      [[ -f "$package_dir/CONTENTS" ]] || continue
      remove_package_contents "$package_dir"
    done
  done
  remove_package_payload sys-devel/gcc true

  rm -rf "$stage/etc/portage" "$stage/usr/lib/portage" "$stage/usr/lib64/portage" \
    "$stage/usr/share/portage" \
    "$stage/usr/lib/perl5" "$stage/usr/lib64/perl5" \
    "$stage/usr/share/perl5" "$stage/usr/lib64/gobject-introspection" \
    "$stage/usr/share/gobject-introspection-1.0" "$stage/var/lib/portage" \
    "$stage/var/db/pkg" "$stage/var/db/repos" "$stage/var/log/portage"
  rm -f "$stage/usr/bin"/{g-ir-*,eu-*,sqlite3,perl*}
  find "$stage/usr/lib/gcc" -mindepth 3 -maxdepth 3 -type d -name 32 -prune -exec rm -rf {} + 2>/dev/null || true
  rm -rf "$stage/usr/libexec/gcc" "$stage/usr/x86_64-pc-linux-gnu" \
    "$stage/usr/share/gcc-data" "$stage/usr/share/binutils-data"
  find "$stage/usr/lib/gcc" \( -type f -o -type l \) -print0 | while IFS= read -r -d '' path; do
    case "${path##*/}" in
      libgcc_s.so.[0-9]*|libstdc++.so.[0-9]*|libatomic.so.[0-9]*) ;;
      *) rm -f -- "$path" ;;
    esac
  done
  find "$stage/usr/lib/gcc" -depth -type d -empty -delete 2>/dev/null || true
  rm -f "$stage/usr/bin"/{gcc,g++,gcc-*,g++-*,gcc-ar,gcc-nm,gcc-ranlib,gcov,gcov-*,gcov-dump,gcov-tool,lto-dump,cc,c++,cpp,ar,as,ld,ld.bfd,nm,objcopy,objdump,ranlib,strip,addr2line,c++filt,elfedit,gprof,readelf,size,strings}
  find "$stage/usr/bin" -maxdepth 1 -name 'x86_64-pc-linux-gnu-*' -delete
  if [[ -d "$stage/usr/lib/netifrc" && ! -e "$stage/lib/netifrc" && ! -L "$stage/lib/netifrc" ]]; then
    ln -s ../usr/lib/netifrc "$stage/lib/netifrc"
  fi

  chroot "$stage" /usr/bin/python3 -c 'import bz2, json, lzma, sqlite3, ssl, sys; print(sys.version)' || {
    echo "Minimal runtime Python 3 interpreter or standard-library modules are broken." >&2
    exit 1
  }
  rm -f "$stage/usr/share/hwdata/oui.txt"

  for path in \
    "$stage/etc/portage" "$stage/var/db/pkg" "$stage/var/lib/portage" \
    "$stage/usr/share/portage" \
    "$stage/usr/lib64/perl5" \
    "$stage/usr/lib64/gobject-introspection" "$stage/usr/share/gobject-introspection-1.0" \
    "$stage/usr/bin"/{emerge,emerge-webrsync,ebuild,emaint,portageq,gemato,getuto,quickpkg,qatom,qcheck,qdepends,qfile,qgrep,qkeyword,qlist,qlop,qmanifest,qmerge,qpkg,qsearch,qsize,qtegrity,quse,qwhich,qxpak,gcc,g++,gcc-*,g++-*,gcc-ar,gcc-nm,gcc-ranlib,gcov,gcov-*,gcov-dump,gcov-tool,lto-dump,cc,c++,cpp,ld,ld.bfd,as,ar,nm,objcopy,objdump,ranlib,strip,addr2line,c++filt,elfedit,gprof,readelf,size,strings,gcc-config,binutils-config,make,g-ir-*,eu-*,sqlite3,perl*}; do
    [[ ! -e "$path" && ! -L "$path" ]] || {
      echo "Minimal runtime still contains forbidden build/package-manager payload: ${path#"$stage"}" >&2
      exit 1
    }
  done
  for path in "$stage"/usr/bin/{clang*,llvm*} "$stage"/usr/lib*/{libLLVM*,libclang*,llvm-*}; do
    [[ ! -e "$path" && ! -L "$path" ]] || {
      echo "Minimal runtime still contains LLVM/Clang payload: ${path#"$stage"}" >&2
      exit 1
    }
  done
fi

if [[ "$MINIMAL_RUNTIME" == true ]]; then
  echo "Removing manuals, documentation trees, locale sources, and unused translations."
  rm -rf \
    "$stage/usr/share/man" \
    "$stage/usr/share/info" \
    "$stage/usr/share/doc" \
    "$stage/usr/share/gtk-doc" \
    "$stage/usr/share/help" \
    "$stage/usr/share/gnome/help" \
    "$stage/usr/share/i18n" \
    "$stage/var/cache/man"

  # Keep English message catalogs only. Compiled libc locale data is separately
  # generated from config/locale.gen, which selects en_US.UTF-8 only.
  if [[ -d "$stage/usr/share/locale" ]]; then
    find "$stage/usr/share/locale" -mindepth 1 -maxdepth 1 -type d \
      ! -name en ! -name en_US ! -name C -exec rm -rf {} +
  fi
  if [[ -d "$stage/usr/lib/locale" ]]; then
    find "$stage/usr/lib/locale" -mindepth 1 -maxdepth 1 -type d \
      ! -name C.utf8 ! -name C.UTF-8 ! -name en_US.utf8 ! -name en_US.UTF-8 \
      -exec rm -rf {} +
  fi

  # Do not ship the dotfiles repository's plugin developer docs, test trees,
  # build caches or man-page index in the user runtime.
  find "$stage/home" -type d \
    \( -name .git -o -name tests -o -name test -o -name screenshots -o -name __pycache__ \) \
    -prune -exec rm -rf {} + 2>/dev/null || true
  find "$stage/home" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.swp' -o -name '*.swo' \) -delete 2>/dev/null || true
fi

# Static archives, libtool metadata, and Python bytecode caches are not used by
# installed runtime executables. Keep runtime shared libraries.
find "$stage/usr" -type f \( -name '*.a' -o -name '*.la' -o -name '*.pyc' \) -delete 2>/dev/null || true
find "$stage" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true

# Refresh the man-db index inside staging, while leaving /usr/share/man intact.
if [[ "$MINIMAL_RUNTIME" != true && -x "$stage/usr/bin/mandb" ]]; then
  mkdir -p "$stage/var/cache/man"
  for mountpoint in dev proc sys run; do
    mkdir -p "$stage/$mountpoint"
    mount --rbind "/$mountpoint" "$stage/$mountpoint"
    mount --make-rslave "$stage/$mountpoint"
  done
  chroot "$stage" /usr/bin/mandb --create || {
    echo "WARNING: mandb index regeneration failed; man pages themselves are preserved." >&2
  }
  for mountpoint in run sys proc dev; do
    umount -R "$stage/$mountpoint" 2>/dev/null || true
  done
fi

tmp_output="$output.tmp.$$"
rm -f "$tmp_output"
echo "Creating SquashFS using zstd compression (kernel must enable SQUASHFS_ZSTD)..."
mksquashfs "$stage" "$tmp_output" -noappend -comp zstd -b 1M -Xcompression-level 15
mv -f "$tmp_output" "$output"
tmp_output=""

if [[ "$MINIMAL_RUNTIME" == true ]]; then
  tmp_filelist="$(mktemp "${TMPDIR:-/var/tmp}/d630-squashfs-list.XXXXXXXX")"
  unsquashfs -ll "$output" > "$tmp_filelist"
  for path in usr/bin/python3 usr/bin/nvim usr/bin/lf usr/bin/fd usr/bin/tldr usr/bin/htop usr/bin/btop usr/bin/mc usr/bin/rg \
    usr/bin/zsh usr/bin/nano usr/bin/tmux usr/bin/startx usr/bin/xterm usr/bin/openbox-session; do
    grep -Eq "squashfs-root/${path}([[:space:]]|$)" "$tmp_filelist" || {
      echo "Required runtime application is absent from the final SquashFS: /${path}" >&2
      exit 1
    }
  done
  if grep -Eq 'squashfs-root/(etc/portage|var/db/pkg|usr/lib(64)?/portage|usr/share/man|usr/share/info|usr/share/doc|usr/share/gtk-doc|usr/share/help|usr/share/i18n|usr/include|var/cache/binpkgs|var/cache/distfiles|var/tmp/portage)(/|$)' "$tmp_filelist"; then
    echo "Forbidden build/documentation payload remains in the final minimal SquashFS." >&2
    grep -E 'squashfs-root/(etc/portage|var/db/pkg|usr/lib(64)?/portage|usr/share/man|usr/share/info|usr/share/doc|usr/share/gtk-doc|usr/share/help|usr/share/i18n|usr/include|var/cache/binpkgs|var/cache/distfiles|var/tmp/portage)(/|$)' "$tmp_filelist" | head -30 >&2
    exit 1
  fi
  if grep -Eq 'squashfs-root/usr/bin/(emerge|emerge-webrsync|ebuild|emaint|portageq|gcc|g\+\+|gcc-config|binutils-config|cc|c\+\+|cpp|make|ld|ld\.bfd)([[:space:]]|$)' "$tmp_filelist"; then
    echo "Portage or compiler executables remain in the final minimal SquashFS." >&2
    exit 1
  fi
  rm -f "$tmp_filelist"
  tmp_filelist=""
fi

echo
du -shx "$src" "$output"
if [[ "$MINIMAL_RUNTIME" == true ]]; then
  echo "Preserved runtime files, licenses, and required configuration; manuals and unused locale data removed."
else
  echo "Preserved: /usr/share/man and /usr/share/licenses."
fi
echo "Removed from the image staging copy: documentation/info trees, Portage build/download caches, ebuild repository checkout, headers and common development metadata."
if [[ "$MINIMAL_RUNTIME" == true ]]; then
  echo "Removed Portage, Perl, development tools, GCC/binutils compilers, and package metadata; retained Python 3."
  echo "Retained only GCC libgcc_s/libstdc++/libatomic runtime libraries; removed Fortran and sanitizer runtimes."
  echo "Removed hwdata/oui.txt; retained Mesa Crocus and its required Gallium runtime."
else
  echo "Preserved package metadata and the compiler toolchain."
fi
echo "Original rootfs was not modified: $src"
