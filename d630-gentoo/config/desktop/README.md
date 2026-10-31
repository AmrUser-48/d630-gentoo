# D630 desktop configuration skeleton

These are curated starter configs for the Gentoo/Openbox runtime. They are adapted from
[`AmrUser-48/deb12dots`](https://github.com/AmrUser-48/deb12dots), current source commit
`3797941932fab66eee98df364dc830c9559b0832`. They are not a wholesale copy of the Debian
configuration.

## Files

- `skel/.Xresources`: self-contained XTerm resources using the Gruvbox Dark palette and
  Terminus PCF XLFD fonts. It deliberately avoids UXTerm-only resource names and relative
  `#include` paths.
- `skel/.config/openbox/rc.xml`: a small Openbox keybinding and workspace baseline.
- `skel/.config/openbox/autostart`: loads Xresources, sets keyboard repeat and optionally
  enables the two xdotool screen-edge actions.

The runtime dotfiles installer copies these templates into `/etc/skel`. They are therefore
defaults for a newly initialized live user, not an automatic overwrite of an existing home
directory.

## Runtime dependencies

The templates assume the Openbox profile has:

- `x11-wm/openbox`, `x11-terms/xterm`, `x11-apps/xrdb`, `x11-apps/xset`;
- `x11-misc/xdotool` for the optional screen-edge actions;
- `app-misc/lf`, `www-client/links` and `sys-process/htop` for the terminal shortcuts;
- `media-fonts/terminus-font` with PCF Unicode fonts enabled.

The Openbox configuration intentionally does not launch Thunar, XFCE, Rofi, Polybar, Feh,
MPD helpers or local scripts that are not part of the minimal profile. Add those shortcuts
only when the corresponding applications are included in a selected package set.

## Xresources checks

After starting X, verify the resource database and font availability:

```sh
xrdb -query | grep -E 'XTerm|Xft'
xlsfonts '*terminus*'
xterm
```

The file uses a single XTerm resource namespace because the runtime starts `xterm`, not
`uxterm`. The font menu contains several sizes; the base font is 14-pixel Terminus.

## Scope

This is a conservative configuration baseline, not proof of graphical operation. Xorg,
Openbox, font matching, touchpad behavior and Crocus acceleration still require runtime
validation in QEMU and on the physical D630.