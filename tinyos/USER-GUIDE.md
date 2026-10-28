# D630 Tiny Linux — User Guide

This guide is for people who are new to D630 Tiny Linux, Gentoo, or initramfs-based systems. It covers trying the image in QEMU, using the shell, networking, installing Tiny on a D630, and preserving changes.

D630 Tiny Linux is a small, text-mode environment for the Dell Latitude D630. It boots an existing kernel and one external initramfs, then runs from RAM. It is **not** a full Gentoo installation: it has no Portage package manager, and files changed during a session are lost at reboot unless you rebuild and save the initramfs.

## Choose what you want to do

| Goal | Start here |
| --- | --- |
| Try Tiny without changing your computer | [Run it in QEMU](#1-try-it-in-qemu) |
| Connect to the internet | [Networking](#4-connect-to-the-internet) |
| Use a shell, file manager, or small program | [Using the environment](#5-use-the-shell-and-included-tools) |
| Boot Tiny on the physical D630 | [Install alongside Gentoo](#8-install-tiny-on-the-d630) |
| Keep changes after reboot | [Save your changes](#9-save-changes) |
| Add Xorg, Mesa, Openbox, or other Gentoo packages | [Adding packages and a desktop](#6-add-programs-or-gentoo-packages) |

## 1. Try it in QEMU

QEMU runs Tiny in a virtual machine. These commands run in the **Codespace or host terminal**, not inside the Tiny guest.

### Download the release files

No GitHub login is needed to download a public release.

```sh
release_dir="$HOME/d630-tiny-release"
mkdir -p "$release_dir"

for asset in kernel initramfs SHA256SUMS d630-tiny.cfg; do
  curl -fL "https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/$asset" \
    -o "$release_dir/$asset"
done
```

The files are saved in `~/d630-tiny-release`.

### Install QEMU and boot Tiny

On an Ubuntu- or Debian-based environment, install QEMU:

```sh
sudo apt-get update
sudo apt-get install -y qemu-system-x86
```

From the repository directory, launch the test image:

```sh
cd /workspaces/d630-gentoo
./tinyos/run-qemu.sh --assets-dir "$HOME/d630-tiny-release"
```

The launcher checks the kernel and initramfs against `SHA256SUMS` before starting QEMU. The image uses the passwordless `gmini` account and opens its shell without requiring you to enter a username or password.

To close QEMU, press **Ctrl-A**, release the keys, then press **X**.

QEMU has an emulated USB Ethernet adapter. It is useful for basic network tests, but it does not emulate the D630's physical Intel Wi-Fi card.

## 2. Understand the prompt and privileges

The normal Tiny account is `gmini`. It has no password. To open a root shell, run:

```sh
doas /bin/bash
```

Check that the shell is running as root:

```sh
id -u
```

The result should be `0`. Type `exit` to leave the root shell and return to `gmini`.

For a single administrative command, put `doas` before the command instead of opening a root shell:

```sh
doas wifi-connect
```

The root account is not intended for direct login. Use `doas` from `gmini`.

## 3. Use the shell and included tools

Open the file manager:

```sh
lf
```

Press `q` to quit it. Other useful commands include:

| Command | Purpose |
| --- | --- |
| `curl` | Download files from the internet |
| `wifi-connect` | Configure a Wi-Fi connection |
| `rdmsr` | Read CPU model-specific registers |
| `setfont` | Change the Linux console font |
| `gentoo-chroot` | Enter an existing, mounted Gentoo installation |
| `rebuild-initramfs` | Save the current Tiny filesystem as a new initramfs |

The image includes `wrmsr` as well as `rdmsr`. Writing model-specific registers can destabilize the system; do not use `wrmsr` unless you understand the exact register and value.

## 4. Connect to the internet

### Wi-Fi on the physical D630

At the `gmini` prompt, run:

```sh
doas wifi-connect
```

Follow the prompts to select a network and enter its passphrase. The D630's Intel 3945ABG adapter supports legacy 802.11a/b/g and WPA/WPA2-PSK. It may not connect to access points that require newer bands or security modes.

Test the connection by downloading a small web page:

```sh
curl -fL https://example.com/ -o /tmp/example.html
```

The downloaded file is temporary and will be erased at reboot.

### Networking in QEMU

QEMU supplies an emulated USB Ethernet adapter, not the D630's Wi-Fi card. Find the guest interface name:

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

## 5. Add a standalone program or script

Tiny has no package manager. You can try a standalone Linux program or a shell script in the RAM filesystem, then preserve it by rebuilding the initramfs.

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

A shell script can also be placed in `/usr/local/bin`, but it must use an interpreter and commands that are already present. For example, a script beginning with `#!/bin/sh` can use the included BusyBox shell.

## 6. Add programs or Gentoo packages

### Why copying one binary is not enough

Packages such as Xorg, Mesa, and Openbox need more than a single executable. They can depend on shared libraries, drivers, modules, configuration files, and other runtime data. Copying an `openbox` binary or a Debian `.deb` into Tiny does not create a working desktop.

To include Gentoo packages in a **new image**, make the changes in the Gentoo build environment or its repository workflow:

1. Add the required package atoms to the build's Gentoo package list and select the USE flags needed for the D630.
2. Install them into the build root. A binary-package-only build works only when the configured binhost has compatible packages. Source compilation must be explicitly allowed when required packages are missing.
3. Update the image-staging step to include the programs and their complete runtime files. A graphical stack usually needs Xorg modules, Mesa drivers, libraries, X11 data/configuration, and a window-manager/session startup configuration.
4. Build a new image and verify that its required files are present. Boot-test it before using it on the physical D630.

The current Tiny staging scripts copy a defined set of programs and shared libraries; they do not automatically package every file belonging to an arbitrary Gentoo package. The `rebuild-initramfs` command described below saves changes already made in a running Tiny session. It does not run Portage or convert Gentoo binary packages into an initramfs.

### Graphical desktop: a separate image

The current public **D630 Tiny Linux** release is the text-mode, single-initramfs image. It does **not** include a published `gui-initram` image or the `d630-gui.cfg` GRUB entry. Do not expect Xorg, Mesa, or Openbox to appear by copying files into `gmini`.

A graphical desktop is a separate image/build path. The repository has a [D630 Gentoo runtime SquashFS workflow](../.github/workflows/build-d630-runtime-squashfs.yml), but check its run and published assets before assuming a desktop image is ready to install.

When a dedicated GUI initramfs release is published, use that release's own notes and verify that it contains all required files. The intended GUI flow is to download its kernel, GUI initramfs, GRUB configuration, and checksum file; copy the kernel and initramfs into a separate `/d630-gui/` directory on a GRUB-readable partition; add the provided GRUB entry; then boot it. A desktop image may require first-boot user setup and a console login followed by `startx`. QEMU success alone does not prove that the physical D630 display or graphics acceleration works.

## 7. Enter an existing Gentoo installation

This is optional and only for users who already have Gentoo installed on a disk. It does not add Gentoo or Portage to Tiny.

Mount the installed Gentoo root filesystem at `/mnt/gentoo`, then run:

```sh
doas gentoo-chroot /mnt/gentoo
```

You are now working inside the Gentoo installation on disk. Commands and package changes affect that installation, not the running Tiny image. Type `exit` to leave the chroot.

The helper checks that the target looks like a Gentoo root, bind-mounts `/dev`, `/proc`, `/sys`, and `/run` for the session, and unmounts those bind mounts when the shell exits. It does not create a Gentoo installation.

## 8. Install Tiny on the D630

This procedure adds a separate GRUB entry and keeps the existing Gentoo boot files intact.

### Prepare the USB drive

On a computer with internet access, download `kernel`, `initramfs`, and `d630-tiny.cfg` from the [latest public release](https://github.com/AmrUser-48/d630-gentoo/releases/latest). Put the files in a directory named `d630-tiny-release` on a USB drive.

### Copy the files to the boot partition

Boot the installed Gentoo system and make sure its GRUB-readable boot partition is mounted at `/boot`. Mount the USB drive; the commands below assume it is available at `/mnt/usb`.

Run these commands as root on the installed system:

```sh
mkdir -p /boot/d630-tiny
cp /mnt/usb/d630-tiny-release/kernel /boot/d630-tiny/kernel
cp /mnt/usb/d630-tiny-release/initramfs /boot/d630-tiny/initramfs
```

Open `/etc/grub.d/40_custom` in a text editor and append the contents of `/mnt/usb/d630-tiny-release/d630-tiny.cfg`. Then regenerate the GRUB menu:

```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

The destination path for GRUB's configuration varies by system. Use the path configured by your installation; Debian-based systems commonly provide `update-grub` as a wrapper.

Reboot and choose **D630 Tiny Linux** from GRUB. Keep the original Gentoo boot entry as your fallback. Do not overwrite your existing Gentoo kernel or initramfs.

## 9. Save changes

Changes in Tiny live in RAM and disappear at reboot. To keep them, save a rebuilt initramfs to a writable USB drive or another persistent filesystem.

Mount the drive and create a destination directory. In this example, the USB drive is mounted at `/mnt/usb`:

```sh
doas mkdir -p /mnt/usb/d630-tiny
doas rebuild-initramfs /mnt/usb/d630-tiny/initramfs
```

Replace `/mnt/usb` with the actual mount point. The destination must be on persistent storage, not the RAM root. The helper repacks the current filesystem, retains the original early Intel microcode archive, skips other mounted filesystems, and writes the new image to the destination. The currently running session is not changed.

To install the rebuilt image for the next boot, back up the current initramfs before copying the new one. These example commands assume the boot partition is mounted at `/boot` and the USB drive at `/mnt/usb`:

```sh
doas cp /boot/d630-tiny/initramfs /boot/d630-tiny/initramfs.backup
doas cp /mnt/usb/d630-tiny/initramfs /boot/d630-tiny/initramfs
```

Reboot and select D630 Tiny Linux from GRUB. If the rebuilt image does not boot, restore the backup or use your original Gentoo boot entry.

## 10. Troubleshooting and limitations

- **QEMU does not connect to the physical Wi-Fi card.** It uses an emulated USB Ethernet adapter. Test the Intel 3945ABG adapter on the actual D630.
- **Changes disappear after reboot.** This is expected. Save a new initramfs to persistent storage if you want to keep them.
- **A downloaded program will not start.** Check that it is a Linux executable for the correct CPU architecture and that its required shared libraries are present.
- **A desktop does not start.** The current Tiny image is text-only; use a separate GUI build when its required assets are published.
- **The system boots in QEMU.** This verifies the tested virtual environment only. It does not guarantee physical Wi-Fi, graphics acceleration, or every D630 hardware feature will work.

For build details and the current release, see the [project README](README.md) and the [latest release page](https://github.com/AmrUser-48/d630-gentoo/releases/latest).
