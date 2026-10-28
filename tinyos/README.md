# D630 Tiny Linux — standalone initramfs prototype

This is a separate experiment using the already-published D630 Linux 6.18.56 kernel. It does not rebuild the kernel and does not modify the existing /d630-gentoo/ boot files.

## What is inside

- The exact existing kernel binary from release d630-kernel-6.18.56-run-39509781896.
- An external initramfs containing statically linked BusyBox, a tiny /init, minimal /dev, /proc, /sys, /run and /tmp setup, Intel 3945ABG Wi-Fi firmware and firmware license notices.
- The existing early Intel microcode CPIO archive, prepended unchanged.
- The main filesystem archive is Zstandard-compressed at level 3. The kernel itself keeps its already-built compression format; rebuilding the kernel is intentionally out of scope.

The standard `initramfs` asset is the minimal shell. The separate `initramfs-internet` variant adds Gentoo-built `iw`, `wpa_supplicant`, `curl`, CA certificates, and BusyBox DHCP setup. On the D630, run `wifi-connect` to join a WPA/WPA2 network, then use `curl -fL URL -o /tmp/file` to download files. The RAM-only filesystem means downloads disappear on reboot. This is not a package manager and does not install Gentoo packages.

The separate `initramfs-setup` variant logs in as the passwordless local account `gmini`, using Gentoo-built Bash and the `lf` terminal file manager. BusyBox `login` displays the Gentoo banner in `/etc/motd`; the startup logo is no longer hard-coded in `/init`. The ANSI Shadow font is not included in Gentoo's figlet package, so the banner is stored directly as MOTD text. The adapted `lfrc`, colors, and icons come from `AmrUser-48/deb12dots` at commit `6da2f0e`. `.bashrc` adds a colored prompt, common aliases, and the `lfcd` shortcut. Use passwordless `doas wifi-connect` for Wi-Fi and `doas` for local administration. All changes remain in RAM and disappear on reboot.

The kernel has the D630's Intel 3945ABG Wi-Fi driver built in. It supports legacy 802.11a/b/g and WPA/WPA2-PSK networks; compatibility depends on the access point's band and security settings. QEMU's USB network adapter can test DHCP and HTTPS downloads, but does not emulate the D630 Wi-Fi card. In QEMU, find the adapter with `for p in /sys/class/net/*; do [ -e "$p/device" ] && echo "${p##*/}"; done`, then run `udhcpc -q -i INTERFACE -s /usr/share/udhcpc/default.script` before using `curl`.

Run `./tinyos/run-qemu.sh --internet` for the network-only image or `./tinyos/run-qemu.sh --setup` for the Gentoo Mini Bash/lf environment. Both use an emulated USB network adapter in QEMU.

## Build and verification

GitHub Actions downloads the pinned kernel/firmware release, checks asset SHA-256 values and required kernel options, builds all three initramfs variants, validates their CPIO contents and symlinks, then boots them with the actual kernel in QEMU. The network and setup variants are tested through QEMU's emulated USB Ethernet adapter with DHCP and an HTTPS download; the setup variant also verifies gmini login, Bash, and lf.

## Install without replacing Gentoo

1. Download kernel and the desired initramfs and matching GRUB entry from the build release (for example `initramfs-setup` and `d630-tiny-setup.cfg`).
2. Copy the kernel and initramfs to a new `/d630-tiny/` directory on a GRUB-readable partition. Leave `/d630-gentoo/` untouched.
3. Add the contents of the matching `d630-tiny-*.cfg` to `/etc/grub.d/40_custom`, then regenerate GRUB's config.
4. Boot the selected D630 Tiny image. The setup variant logs in as `gmini`; run `doas wifi-connect` to connect over Wi-Fi. It is volatile: edits disappear on reboot.

The current Gentoo initramfs and kernel remain available as the fallback. Successful QEMU boot does not by itself prove boot on the physical D630.
