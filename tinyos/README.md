# D630 Tiny Linux

D630 Tiny Linux is an experimental, text-mode Linux environment for the Dell Latitude D630. It boots the existing Linux 6.18.56 kernel with one external initramfs and runs entirely in RAM.

**New to the project?** Start with the [First-time User Guide](USER-GUIDE.md). It explains how to try the image in QEMU, use the shell, connect to a network, install Tiny alongside Gentoo, and save changes.

**Status:** the current image has been tested in QEMU. A successful QEMU boot does not guarantee that every function works on physical D630 hardware. The existing `/d630-gentoo/` boot files remain separate and should be kept as a fallback.

## Quick start

### Download the latest build

Open the [latest release](https://github.com/AmrUser-48/d630-gentoo/releases/latest), or download the main files directly:

| File | Purpose |
| --- | --- |
| [`kernel`](https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/kernel) | Existing D630 Linux kernel |
| [`initramfs`](https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/initramfs) | Combined, RAM-only user environment |
| [`d630-tiny.cfg`](https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/d630-tiny.cfg) | GRUB menu entry for installation |
| [`SHA256SUMS`](https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/SHA256SUMS) | Build checksums |

### Test in QEMU

On Debian or Ubuntu, install the tools and clone the repository:

```bash
sudo apt update
sudo apt install curl git qemu-system-x86
git clone https://github.com/AmrUser-48/d630-gentoo.git
cd d630-gentoo
```

Download the public release assets. No GitHub login is required:

```bash
release_dir="$HOME/d630-tiny-release"
mkdir -p "$release_dir"
for asset in kernel initramfs SHA256SUMS; do
  curl -fL "https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/$asset" \
    -o "$release_dir/$asset"
done
```

Start the virtual machine:

```bash
./tinyos/run-qemu.sh --assets-dir "$HOME/d630-tiny-release"
```

The launcher verifies the downloaded kernel and initramfs against their SHA-256 checksums, then boots them with an emulated USB Ethernet adapter. To close QEMU, press **Ctrl-A**, release the keys, then press **X**.

### Install alongside the existing Gentoo system

1. Download `kernel`, `initramfs`, and `d630-tiny.cfg` from the links above.
2. On a GRUB-readable partition, create a new `/d630-tiny/` directory and copy `kernel` and `initramfs` into it. **Do not overwrite or remove `/d630-gentoo/`.**
3. Add the contents of `d630-tiny.cfg` to `/etc/grub.d/40_custom`.
4. Regenerate the GRUB configuration using the command appropriate for the host system (for example, `sudo update-grub` on Debian).
5. Select **D630 Tiny Linux** from the GRUB menu. Keep the existing Gentoo entry as your fallback.

For the full installation steps, networking commands, chroot instructions, and guidance on preserving changes, see the [First-time User Guide](USER-GUIDE.md).

## What is included

The combined initramfs contains:

- A statically linked BusyBox environment and a minimal `/init`, with `/dev`, `/proc`, `/sys`, `/run`, and `/tmp` set up at boot.
- A passwordless local account named `gmini`, Gentoo-built Bash, `lf`, and a Gentoo banner displayed by BusyBox `login` from `/etc/motd`.
- Network utilities, DHCP, `curl`, passwordless `doas`, and `wifi-connect`.
- `rdmsr` and `wrmsr` from a pinned Gentoo binary-package shard.
- `setfont` and a small Terminus Powerline font subset for the Linux console and X11 font servers.
- Intel 3945ABG Wi-Fi firmware and the requested i915/tigon firmware files, with upstream license notices.
- Helpers to rebuild the initramfs to external storage and to enter an already-mounted Gentoo root.

The existing early Intel microcode CPIO archive is prepended unchanged. The main filesystem archive is Zstandard-compressed at level 3. The kernel itself is not rebuilt by this experiment.

The `lf` configuration, colors, and icons are adapted from [`AmrUser-48/deb12dots`](https://github.com/AmrUser-48/deb12dots) at commit `6da2f0e`. The banner is plain MOTD text because the ANSI Shadow font is not included in Gentoo's figlet package.

## First steps after boot

Log in as `gmini`. The account has no password.

### Connect to Wi-Fi

Run:

```bash
doas wifi-connect
```

The D630's Intel 3945ABG driver is built into the kernel. The card supports legacy 802.11a/b/g and WPA/WPA2-PSK; compatibility depends on the access point's band and security settings.

To download a file:

```bash
curl -fL URL -o /tmp/file
```

The filesystem is RAM-only. Changes and downloaded files disappear on reboot.

### Network testing in QEMU

QEMU provides an emulated USB Ethernet adapter; it does not emulate the D630's Wi-Fi card. Find the adapter name and obtain a DHCP lease before testing HTTPS downloads:

```bash
for p in /sys/class/net/*; do
  [ -e "$p/device" ] && echo "${p##*/}"
done
doas udhcpc -q -i INTERFACE -s /usr/share/udhcpc/default.script
curl -fL https://example.com/ -o /tmp/test.html
```

Replace `INTERFACE` with the detected interface name.

### Use an existing Gentoo installation

Mount the Gentoo root filesystem, then run:

```bash
doas gentoo-chroot /mnt/gentoo
```

The helper checks for a Gentoo root and Bash, bind-mounts `/dev`, `/proc`, `/sys`, and `/run` for the session, and unmounts those bind mounts when the shell exits. It does not create or install a Gentoo system. Changes inside the chroot affect the mounted installation.

### Preserve changes by rebuilding the initramfs

Mount a writable USB drive or other storage partition, create its `d630-tiny/` directory, and write the rebuilt image there:

```bash
doas mkdir -p /mnt/usb/d630-tiny
doas rebuild-initramfs /mnt/usb/d630-tiny/initramfs
```

Replace `/mnt/usb` with the actual mount point. The helper repacks the current root, retains the original early-microcode archive, skips other mounted filesystems, and writes to the specified destination. It refuses to write into the RAM root. Back up the original initramfs before replacing any boot image.

The rebuilt image can be selected from GRUB on the next boot after it has been copied to the boot partition.

## Build and verification

The [GitHub Actions workflow](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-tiny-initramfs.yml) downloads the pinned kernel and firmware release, checks SHA-256 values and required kernel options, stages the requested firmware and selected fonts with license notices, and builds the combined initramfs.

The workflow validates the CPIO contents and symlinks, then uses the actual kernel and initramfs in QEMU to test login, the MOTD, setup tools, firmware presence, DHCP, HTTPS downloads, chroot input validation, and rebuilding to a separate filesystem.

## Scope and limitations

- This is a compact shell environment, **not** a graphical desktop or a complete Gentoo installation.
- It has no package manager and does not install Gentoo packages.
- `rdmsr` and `wrmsr` are available, but the startup process does not write to model-specific registers automatically.
- Most extra i915 firmware files target newer GPUs and are not used by the D630's GM965 graphics.
- QEMU testing covers the emulated USB network adapter, not the physical Intel 3945ABG Wi-Fi hardware.
