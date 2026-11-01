# D630 desktop configuration skeleton

These files provide the curated XTerm and Openbox defaults installed into the Gentoo live runtime. They are adapted from the pinned `AmrUser-48/deb12dots` configuration, with Debian-only services and unavailable applications excluded.

## Files

- `skel/.Xresources`: self-contained XTerm resources with the Gruvbox Dark palette and Terminus font names.
- `skel/.config/openbox/rc.xml`: Openbox workspace, window-management and application shortcuts.
- `skel/.config/openbox/autostart`: loads X resources when available, sets keyboard repeat, starts optional xdotool screen-edge actions, and starts PipeWire/WirePlumber.

The runtime installer copies these defaults into `/etc/skel` for the live user. Openbox application shortcuts for optional tools are removed during image assembly when the corresponding executable is absent from the imported binary-package set.

## Runtime dependencies

The Openbox profile requires Xorg, Openbox, XTerm, scrcpy, NetworkManager, nmtui, PipeWire, WirePlumber and ALSA utilities. The CLI shortcuts for `lf`, `links`, `htop`, `nvim` and `mc` are retained only when their binaries are present. The xdotool screen-edge actions and X resource loading are also conditional.

Audio uses PipeWire/WirePlumber with direct ALSA utilities. No MPD server, ncmpcpp client or mpv player is configured.

## Xresources checks

After starting X, verify the resource database and font availability:

```sh
xrdb -query | grep -E 'XTerm|Xft'
xlsfonts '*terminus*'
xterm
```

## Scope

This is a configuration baseline, not proof of graphical operation. Xorg, Openbox, fonts, input and Crocus acceleration still require a graphical QEMU test and validation on the physical D630.
