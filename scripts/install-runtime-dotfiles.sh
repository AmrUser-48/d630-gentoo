#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "d630-dotfiles: ERROR: $*" >&2; exit 2; }
[[ $# -eq 2 ]] || die "usage: $0 <runtime-root> <work-directory>"
ROOT="$(realpath "$1")"
WORK="$(realpath -m "$2")"
[[ -d "$ROOT/etc" ]] || die "runtime root is not a root filesystem: $ROOT"
mkdir -p "$WORK" "$ROOT/etc/skel/.config"
readonly DOTFILES_REF="6da2f0e0e8b90d61ac3f37e9c3b832edaddf7298"
ARCHIVE="$WORK/deb12dots-$DOTFILES_REF.tar.gz"
SRC="$WORK/deb12dots-$DOTFILES_REF"
SKEL="$ROOT/etc/skel"

echo "Installing pinned deb12dots configuration ($DOTFILES_REF)"
curl -fL --retry 3 --retry-all-errors \
  "https://codeload.github.com/AmrUser-48/deb12dots/tar.gz/$DOTFILES_REF" \
  -o "$ARCHIVE"
tar -xzf "$ARCHIVE" -C "$WORK"
[[ -d "$SRC" ]] || die "pinned dotfiles archive did not contain $SRC"

for name in .bashrc .zshrc .zprofile .aaliases .inputrc .Xresources .Xmodmap; do
  [[ -f "$SRC/$name" ]] || die "required dotfile is missing: $name"
  install -m 0644 "$SRC/$name" "$SKEL/$name"
done

for name in lf nvim Xresources; do
  [[ -d "$SRC/.config/$name" ]] || die "required configuration directory is missing: .config/$name"
  cp -a "$SRC/.config/$name" "$SKEL/.config/"
done
mkdir -p "$SKEL/.trash"

# Debian-specific aliases and optional media/clipboard applications are not part
# of this compact Gentoo profile. Keep the shell startup clean on this target.
sed -i \
  -e "/^alias fd='fdfind'$/d" \
  -e "/^alias bat=/d" \
  -e "/^alias ac='sudo apt /d" \
  -e "/^alias sox=/d" \
  -e "/^alias soxi=/d" \
  -e "/^alias play=/d" \
  -e "/^alias brown=/d" \
  -e "/^alias plotting=/d" \
  -e "/^alias tsd=/d" \
  -e "/^alias gamepademulator=/d" \
  -e "/^alias tethering-on=/d" \
  -e "/^alias ydb=/d" \
  -e "/^alias ydp7=/d" \
  -e "/^alias yd4p=/d" \
  -e "/^alias mpp=/d" \
  -e "/^alias ppaste=/d" \
  -e "/^alias xcalib_c=/d" \
  -e "/^alias rncmpcpp=/d" \
  -e "/^alias ai=/d" \
  "$SKEL/.aaliases" "$SKEL/.bashrc"

# Make lf work with the installed XDG opener, fix the config path typo, and
# remove a misspelled option which lf would otherwise reject.
sed -i \
  -e 's/map o \&mimeopen \$f/map o \&xdg-open $f/' \
  -e 's/map O \$mimeopen --ask \$f/map O $xdg-open $f/' \
  -e 's/\$OPENER \$f/xdg-open "$f"/g' \
  -e 's/"\$HOME\.config\/lf\/lfrc"/"\$HOME\/.config\/lf\/lfrc"/g' \
  -e '/^set prewiew!/d' \
  "$SKEL/.config/lf/lfrc"

# Both interactive shells source this shared alias file.
grep -Fq 'LF_ICONS' "$SKEL/.aaliases" ||
  printf '\n[ -r "$HOME/.config/lf/icons" ] && . "$HOME/.config/lf/icons"\n' >> "$SKEL/.aaliases"

# The vendored Neovim plugins are already in deb12dots; remove only development
# baggage. Preserve license/copyright notices and every runtime Lua/Vim file.
find "$SKEL/.config/nvim" -type d \
  \( -name .git -o -name .github -o -name tests -o -name test -o -name screenshots \) \
  -prune -exec rm -rf {} +
find "$SKEL/.config/nvim" -type d \( -name __pycache__ \) -prune -exec rm -rf {} +
find "$SKEL/.config/nvim" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.swp' -o -name '*.swo' \) -delete
find "$SKEL/.config/nvim" -type f \( -name 'README' -o -name 'README.*' -o -name 'CONTRIBUTING*' -o -name 'CHANGELOG*' \) -delete
find "$SKEL/.config/nvim" -type d \( -name doc -o -name docs \) -prune -exec rm -rf {} +

# Default editors and opener are inherited by login shells through env-update.
cat > "$ROOT/etc/env.d/99-runtime-user" <<'EOF'
EDITOR="nvim"
VISUAL="nvim"
PAGER="less"
OPENER="xdg-open"
EOF

# The pinned dotfiles were originally written for Debian, where lesspipe emits
# shell code when invoked without a filename. Gentoo's lesspipe can instead emit
# a usage message; eval'ing that text breaks every interactive Bash login.
sed -i '/command -v lesspipe/,+2d' "$SKEL/.aaliases"

echo "Installed dotfiles into /etc/skel; Neovim and lf configs are self-contained."
