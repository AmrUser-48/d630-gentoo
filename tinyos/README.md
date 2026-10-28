# D630 Tiny Linux — single-initramfs prototype

This is a separate experiment using the already-published D630 Linux 6.18.56 kernel. It does not rebuild the kernel and does not modify the existing /d630-gentoo/ boot files.

## What is inside

- The exact existing kernel binary from release d630-kernel-6.18.56-run-39509781896.
- An external initramfs containing statically linked BusyBox, a tiny /init, minimal /dev, /proc, /sys, /run and /tmp setup, Intel 3945ABG Wi-Fi firmware and firmware license notices.
- The existing early Intel microcode CPIO archive, prepended unchanged.
- The main filesystem archive is Zstandard-compressed at level 3. The kernel itself keeps its already-built compression format; rebuilding the kernel is intentionally out of scope.

The single `initramfs` combines the Gentoo Mini setup environment and internet tools. It logs in as the passwordless local account `gmini`, using Gentoo-built Bash and `lf`. BusyBox `login` displays the Gentoo banner from `/etc/motd`; the startup logo is not hard-coded in `/init`. The ANSI Shadow font is not included in Gentoo's figlet package, so the banner is stored directly as MOTD text. The adapted `lfrc`, colors, and icons come from `AmrUser-48/deb12dots` at commit `6da2f0e`. `.bashrc` adds a colored prompt, common aliases, and the `lfcd` shortcut.

Use `doas wifi-connect` to join a WPA/WPA2 network, then `curl -fL URL -o /tmp/file` to download files. QEMU testing uses a USB network adapter and checks DHCP and HTTPS downloads; it does not emulate the D630 Wi-Fi card. The RAM-only filesystem means changes and downloads disappear on reboot. This is not a package manager and does not install Gentoo packages.

To keep changes made during a real-machine session, mount a writable USB/storage partition, create its `/d630-tiny/` directory, then run `doas rebuild-initramfs /mnt/usb/d630-tiny/initramfs` (replace `/mnt/usb` with your mount point). The helper repacks the current root, retains the original early-microcode archive, skips other mounted filesystems, and writes the new image to the explicit destination. It refuses to write into the RAM root. The existing GRUB entry then boots the rebuilt image on the next restart; keep a backup of the original initramfs before replacing it.

The kernel has the D630's Intel 3945ABG Wi-Fi driver built in. It supports legacy 802.11a/b/g and WPA/WPA2-PSK networks; compatibility depends on the access point's band and security settings. QEMU's USB network adapter can test DHCP and HTTPS downloads, but does not emulate the D630 Wi-Fi card. In QEMU, find the adapter with `for p in /sys/class/net/*; do [ -e "$p/device" ] && echo "${p##*/}"; done`, then run `udhcpc -q -i INTERFACE -s /usr/share/udhcpc/default.script` before using `curl`.

Run `./tinyos/run-qemu.sh` to download and boot the latest single initramfs in QEMU. The script attaches an emulated USB network adapter automatically. Install QEMU and authenticate the `gh` CLI first.

## Build and verification

GitHub Actions downloads the pinned kernel/firmware release, checks asset SHA-256 values and required kernel options, builds the combined initramfs, validates its CPIO contents and symlinks, then tests gmini login, MOTD, Bash, lf, doas, DHCP, HTTPS, and rebuilding to a separate filesystem using the actual kernel in QEMU.

## Install without replacing Gentoo

1. Download `kernel`, `initramfs`, and `d630-tiny.cfg` from the build release.
2. Copy the kernel and initramfs to a new `/d630-tiny/` directory on a GRUB-readable partition. Leave `/d630-gentoo/` untouched.
3. Add the contents of `d630-tiny.cfg` to `/etc/grub.d/40_custom`, then regenerate GRUB's config.
4. Boot D630 Tiny Linux. It logs in as `gmini`; run `doas wifi-connect` to connect over Wi-Fi. It is volatile: edits disappear on reboot.

The current Gentoo initramfs and kernel remain available as the fallback. Successful QEMU boot does not by itself prove boot on the physical D630.
