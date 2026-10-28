# D630 Tiny Linux

D630 Tiny Linux is an experimental, text-mode Linux environment for the Dell Latitude D630. It boots the existing Linux 6.18.56 kernel with one external initramfs and runs from RAM.

This is a **standalone shell environment, not a complete Gentoo installation**. It has no Portage package manager. Changes made during a session disappear at reboot unless you save a rebuilt initramfs to persistent storage.

**Current status:** the published image has been tested in QEMU. QEMU success does not guarantee that every feature works on physical D630 hardware. The existing `/d630-gentoo/` boot files are separate; keep them as a fallback.

## Start here

| What you want to do | Go to |
| --- | --- |
| **Boot Mini on the physical laptop** | [Install and boot on the D630](#1-boot-tiny-on-the-physical-d630) |
| Try Tiny safely in a virtual machine | [Run it in QEMU](#2-try-it-in-qemu) |
| Learn the shell and root access | [Use the shell](#3-use-the-shell-and-administrative-commands) |
| Connect to Wi-Fi or QEMU networking | [Connect to the internet](#4-connect-to-the-internet) |
| Add a standalone program | [Run a standalone program or script](#5-run-a-standalone-program-or-script) |
| Understand Gentoo packages and the separate desktop build | [Add Gentoo packages or a desktop](#6-add-gentoo-packages-or-a-desktop) |
| Enter a Gentoo installation already on disk | [Use an installed Gentoo system](#7-use-an-installed-gentoo-system) |
| Keep changes after reboot | [Save changes](#8-save-changes) |

## 1. Boot Tiny on the physical D630

These steps boot Tiny on the actual laptop. No rebuild is needed.

### 1. Find the boot partition

The boot files go on the same GRUB-readable partition that already contains `/d630-gentoo/`. On this D630, that is labelled `Res_syst`. Find its mount point:

```sh
lsblk -o NAME,LABEL,FSTYPE,MOUNTPOINTS
```

Use the mount point shown for `Res_syst`. It must be mounted and writable by your normal user. Replace `/MOUNT/POINT` below with that mount point.

### 2. Create the directory and download the boot files

Run these commands as your normal user. They create `/d630-tiny/` and download the kernel, initramfs, and GRUB boot script directly there. No `sudo` is needed for the downloads.

```sh
mkdir -p /MOUNT/POINT/d630-tiny
curl -fL https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/kernel -o /MOUNT/POINT/d630-tiny/kernel
curl -fL https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/initramfs -o /MOUNT/POINT/d630-tiny/initramfs
curl -fL https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/d630-tiny.cfg -o /MOUNT/POINT/d630-tiny/tiny.cfg
```

The resulting files are:

```text
/d630-tiny/kernel
/d630-tiny/initramfs
/d630-tiny/tiny.cfg
```

### 3. Add the GRUB entry

Open the existing custom GRUB file:

```sh
sudoedit /etc/grub.d/40_custom
```

Remove any older **D630 Tiny Linux** block previously added from `d630-tiny.cfg`, then add this entry once:

```grub
menuentry 'D630 Tiny Linux (Gentoo Mini)' {
    search --no-floppy --file --set=root /d630-tiny/tiny.cfg
    configfile /d630-tiny/tiny.cfg
}
```

Save the file and update GRUB:

```sh
sudo update-grub
sudo reboot
```

Select **D630 Tiny Linux (Gentoo Mini)**. The menu entry loads `/d630-tiny/tiny.cfg`, which boots the kernel and initramfs from that same directory. Keep the existing Gentoo entry as a fallback; do not overwrite anything in `/d630-gentoo/`.

After boot, Tiny starts in a text shell as `gmini`. To connect using the laptop's Wi-Fi, run:

```sh
doas wifi-connect
```

This is the text-mode Mini OS, not the graphical desktop.

## 2. Try it in QEMU

QEMU runs Tiny in a virtual machine, so you can try the shell without changing your computer's boot configuration. The commands below run in the **host or Codespace terminal**, not inside Tiny.

### Download the current release

Open the [latest public release](https://github.com/AmrUser-48/d630-gentoo/releases/latest), or download the files needed for testing:

```sh
release_dir="$HOME/d630-tiny-release"
mkdir -p "$release_dir"

for asset in kernel initramfs SHA256SUMS; do
  curl -fL "https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/$asset" \
    -o "$release_dir/$asset"
done
```

### Install QEMU and boot Tiny

On a Debian- or Ubuntu-based host or Codespace, install QEMU:

```sh
sudo apt-get update
sudo apt-get install -y curl qemu-system-x86
```

From the repository's root directory, run the launcher:

```sh
./tinyos/run-qemu.sh --assets-dir "$HOME/d630-tiny-release"
```

The launcher checks the kernel and initramfs against `SHA256SUMS` before booting. Tiny starts its shell automatically as the passwordless `gmini` user; no username or password prompt is needed.

To close QEMU, press **Ctrl-A**, release the keys, then press **X**.

QEMU provides an emulated USB Ethernet adapter. It can test basic networking, but it does not emulate the D630's physical Intel Wi-Fi card.

## 3. Use the shell and administrative commands

Tiny's normal account is `gmini`. It has no password. To open a root shell, run:

```sh
doas /bin/bash
```

Check that the shell has root privileges:

```sh
id -u
```

The result should be `0`. Type `exit` to leave the root shell and return to `gmini`.

For a single administrative command, use `doas` before the command instead:

```sh
doas wifi-connect
```

Open the file manager with:

```sh
lf
```

Press `q` to quit. Other included tools include:

| Command | Purpose |
| --- | --- |
| `curl` | Download files from the internet |
| `wifi-connect` | Configure a Wi-Fi connection |
| `rdmsr` | Read CPU model-specific registers |
| `wrmsr` | Write CPU model-specific registers |
| `setfont` | Change the Linux console font |
| `gentoo-chroot` | Enter an existing, mounted Gentoo installation |
| `rebuild-initramfs` | Save the current Tiny filesystem as a new initramfs |

Writing model-specific registers can destabilize the computer. Do not use `wrmsr` unless you understand the exact register and value. Tiny does not write to model-specific registers automatically.

## 4. Connect to the internet

### Wi-Fi on the physical D630

At the `gmini` prompt, run:

```sh
doas wifi-connect
```

Follow the prompts to select a network and enter its passphrase. The D630's Intel 3945ABG adapter supports legacy 802.11a/b/g and WPA/WPA2-PSK. It may not connect to access points that require newer bands or security modes.

Test the connection by downloading a small page:

```sh
curl -fL https://example.com/ -o /tmp/example.html
```

The downloaded file is temporary and will be erased at reboot.

### Networking in QEMU

QEMU uses an emulated USB Ethernet adapter, not the D630's Wi-Fi card. Find the guest's interface name:

```sh
for p in /sys/class/net/*; do
  [ -e "$p/device" ] && echo "${p##*/}"
done
```

Use the interface name printed by that command in place of `INTERFACE`:

```sh
doas udhcpc -q -i INTERFACE -s /usr/share/udhcpc/default.script
curl -fL https://example.com/ -o /tmp/example.html
```

If the download succeeds, DHCP and HTTPS access are working in the virtual machine.

## 5. Run a standalone program or script

Tiny has no package manager. You can try a standalone Linux program or shell script in the RAM filesystem, then preserve it by rebuilding the initramfs.

Download a program from a source you trust. Replace the example URL with the publisher's actual download URL:

```sh
curl -fL 'https://example.com/tool' -o /tmp/tool
```

Copy it into `/usr/local/bin` as root:

```sh
doas /bin/bash
mkdir -p /usr/local/bin
cp /tmp/tool /usr/local/bin/tool
chmod 755 /usr/local/bin/tool
exit
```

Run it:

```sh
/usr/local/bin/tool
```

This works only if the file is a Linux executable for the computer's CPU architecture and it is either statically linked or all required shared libraries are already in Tiny. A source archive, Windows program, or Debian `.deb` is not a ready-to-run executable for this environment.

A shell script can also be placed in `/usr/local/bin`, but it must use an interpreter and commands already present. For example, a script beginning with `#!/bin/sh` can use the included BusyBox shell.

## 6. Add Gentoo packages or a desktop

### Why copying one binary is not enough

Packages such as Xorg, Mesa, and Openbox need more than one executable. They can depend on shared libraries, drivers, modules, configuration files, and other runtime data. Copying an `openbox` binary or a Debian `.deb` into Tiny does not create a working desktop.

To include Gentoo packages in a **new image**, make changes in the Gentoo build environment or its repository workflow:

1. Add the required package atoms to the build's Gentoo package list and select the USE flags needed for the D630.
2. Install them into the build root. A binary-package-only build works only when the configured binhost has compatible packages. Source compilation must be explicitly allowed when required packages are missing.
3. Update the image-staging step to include the programs and their complete runtime files. A graphical stack usually needs Xorg modules, Mesa drivers, libraries, X11 data and configuration, and a window-manager/session startup configuration.
4. Build a new image, verify that the required files are present, and boot-test it before using it on the physical D630.

The current Tiny staging scripts copy a defined set of programs and shared libraries; they do not automatically package every file belonging to an arbitrary Gentoo package. The `rebuild-initramfs` helper saves changes made in a running Tiny session. It does not run Portage or convert Gentoo binary packages into an initramfs.

### Graphical desktop: a separate image

The current public **D630 Tiny Linux** release is text-only. It does **not** include a published `gui-initram` image or the `d630-gui.cfg` GRUB entry. Do not expect Xorg, Mesa, or Openbox to appear by copying files into `gmini`.

A graphical desktop is a separate build path and does not expand the RAM-only `gmini` image. The planned desktop runtime includes a Gentoo root, Xorg, the Mesa Crocus driver for the D630's GM965 graphics, `xinit`, `xterm`, and Openbox. The repository has a [D630 Gentoo runtime SquashFS workflow](../.github/workflows/build-d630-runtime-squashfs.yml), but check its run and published assets before assuming a desktop image is ready to install.

When a dedicated GUI release is published, follow that release's own notes and verify that all required assets are present. A desktop image may require first-boot user setup and a console login followed by `startx`. QEMU success alone does not prove that the physical D630 display or graphics acceleration works.

## 7. Use an installed Gentoo system

This is optional and only for users who already have Gentoo installed on disk. It does not add Gentoo or Portage to Tiny.

Mount the installed Gentoo root filesystem at `/mnt/gentoo`, then run:

```sh
doas gentoo-chroot /mnt/gentoo
```

You are now working inside the Gentoo installation on disk. Commands and package changes affect that installation, not the running Tiny image. Type `exit` to leave the chroot.

The helper checks that the target looks like a Gentoo root, bind-mounts `/dev`, `/proc`, `/sys`, and `/run` for the session, and unmounts those bind mounts when the shell exits. It does not create a Gentoo installation.

## 8. Save changes

Changes in Tiny live in RAM and disappear at reboot. To keep them, save a rebuilt initramfs to a writable USB drive or another persistent filesystem.

Mount the drive and create a destination directory. In this example, the USB drive is mounted at `/mnt/usb`:

```sh
doas mkdir -p /mnt/usb/d630-tiny
doas rebuild-initramfs /mnt/usb/d630-tiny/initramfs
```

Replace `/mnt/usb` with the actual mount point. The destination must be on persistent storage, not the RAM root. The helper repacks the current filesystem, retains the original early Intel microcode archive, skips other mounted filesystems, and writes the new image to the destination. The currently running session is not changed.

To use the rebuilt image on the next boot, copy it to the boot partition **from the installed Gentoo system**, not from the running Tiny session. Back up the current image first. These commands assume the boot partition is mounted at `/boot` and the USB drive at `/mnt/usb`:

```sh
doas cp /boot/d630-tiny/initramfs /boot/d630-tiny/initramfs.backup
doas cp /mnt/usb/d630-tiny/initramfs /boot/d630-tiny/initramfs
```

Reboot and select D630 Tiny Linux from GRUB. If the rebuilt image does not boot, restore the backup or use the original Gentoo boot entry.

## What's included

The combined initramfs contains:

- A statically linked BusyBox environment and a minimal `/init` with `/dev`, `/proc`, `/sys`, `/run`, and `/tmp` set up at boot.
- A passwordless `gmini` account, Gentoo-built Bash, `lf`, and a Gentoo banner displayed by BusyBox `login` from `/etc/motd`.
- Network utilities, DHCP, `curl`, passwordless `doas`, and `wifi-connect`.
- `rdmsr` and `wrmsr` from a pinned Gentoo binary-package shard.
- `setfont` and a small Terminus Powerline font subset for the Linux console and X11 font servers.
- Intel 3945ABG Wi-Fi firmware and requested i915/tigon firmware files, with upstream license notices.
- Helpers to rebuild the initramfs to external storage and enter an already-mounted Gentoo root.

The existing early Intel microcode CPIO archive is prepended unchanged. The main filesystem archive is Zstandard-compressed at level 3. The kernel itself is not rebuilt by this experiment.

The `lf` configuration, colors, and icons are adapted from [`AmrUser-48/deb12dots`](https://github.com/AmrUser-48/deb12dots) at commit `6da2f0e`. The banner is plain MOTD text because the ANSI Shadow font is not included in Gentoo's figlet package.

## Build and verification

The [GitHub Actions workflow](https://github.com/AmrUser-48/d630-gentoo/actions/workflows/build-d630-tiny-initramfs.yml) downloads the pinned kernel and firmware release, checks SHA-256 values and required kernel options, stages the requested firmware and selected fonts with license notices, and builds the combined initramfs.

The workflow validates CPIO contents and symlinks, then boots the actual kernel and initramfs in QEMU to test login, the MOTD, setup tools, firmware presence, DHCP, HTTPS downloads, chroot input validation, and rebuilding to a separate filesystem.

## Troubleshooting and limitations

- **QEMU does not connect to the physical Wi-Fi card.** It uses an emulated USB Ethernet adapter. Test the Intel 3945ABG adapter on the actual D630.
- **Changes disappear after reboot.** This is expected. Save a new initramfs to persistent storage if you want to keep them.
- **A downloaded program will not start.** Check that it is a Linux executable for the correct CPU architecture and that its required shared libraries are present.
- **A desktop does not start.** The current published Tiny image is text-only; use a separate GUI build when its required assets are published.
- **The system boots in QEMU.** This verifies the tested virtual environment only. It does not guarantee physical Wi-Fi, graphics acceleration, or every D630 hardware feature will work.

See the [latest release page](https://github.com/AmrUser-48/d630-gentoo/releases/latest) for the current downloadable assets.
