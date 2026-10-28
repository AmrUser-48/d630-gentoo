# D630 Tiny Linux — standalone initramfs prototype

This is a separate experiment using the already-published D630 Linux 6.18.56 kernel. It does not rebuild the kernel and does not modify the existing /d630-gentoo/ boot files.

## What is inside

- The exact existing kernel binary from release d630-kernel-6.18.56-run-39509781896.
- An external initramfs containing statically linked BusyBox, a tiny /init, minimal /dev, /proc, /sys, /run and /tmp setup, Intel 3945ABG Wi-Fi firmware and firmware license notices.
- The existing early Intel microcode CPIO archive, prepended unchanged.
- The main filesystem archive is Zstandard-compressed at level 3. The kernel itself keeps its already-built compression format; rebuilding the kernel is intentionally out of scope.

The standard `initramfs` asset is the minimal shell. The separate `initramfs-internet` variant adds Gentoo-built `iw`, `wpa_supplicant`, `curl`, CA certificates, and BusyBox DHCP setup. On the D630, run `wifi-connect` to join a WPA/WPA2 network, then use `curl -fL URL -o /tmp/file` to download files. The RAM-only filesystem means downloads disappear on reboot. This is not a package manager and does not install Gentoo packages.

The kernel has the D630's Intel 3945ABG Wi-Fi driver built in. It supports legacy 802.11a/b/g and WPA/WPA2-PSK networks; compatibility depends on the access point's band and security settings. QEMU's USB network adapter can test DHCP and HTTPS downloads, but does not emulate the D630 Wi-Fi card. In QEMU, run `udhcpc -q -i usb0 -s /usr/share/udhcpc/default.script` before using `curl`.

Run `./tinyos/run-qemu.sh --internet` to boot the internet-enabled release in QEMU with its emulated USB network adapter.

## Build and verification

GitHub Actions downloads the pinned kernel/firmware release, checks asset SHA-256 values and required kernel options, builds both initramfs variants, validates their CPIO contents and symlinks, then boots them with the actual kernel in QEMU. The internet-enabled image is tested through QEMU's emulated USB Ethernet adapter with DHCP and an HTTPS download.

## Install without replacing Gentoo

1. Download kernel, `initramfs-internet`, and `d630-tiny-internet.cfg` from the build release.
2. Copy the kernel and initramfs to a new `/d630-tiny/` directory on a GRUB-readable partition. Leave `/d630-gentoo/` untouched.
3. Add the contents of `d630-tiny-internet.cfg` to `/etc/grub.d/40_custom`, then regenerate GRUB's config.
4. Boot D630 Tiny Linux (internet-enabled shell), run `wifi-connect`, and use `curl` to download files. It is volatile: edits disappear on reboot.

The current Gentoo initramfs and kernel remain available as the fallback. Successful QEMU boot does not by itself prove boot on the physical D630.
