# D630 Tiny Linux

D630 Tiny Linux is an experimental, text-mode Linux environment for the Dell Latitude D630. It boots the existing Linux 6.18.56 kernel with one external initramfs and runs from RAM.

This is a **standalone shell environment, not a complete Gentoo installation**. It has no Portage package manager. Changes made during a session disappear at reboot unless you save a rebuilt initramfs to persistent storage.

**Current status:** the published image has been tested in QEMU. QEMU success does not guarantee that every feature works on physical D630 hardware. The existing `/d630-gentoo/` boot files are separate; keep them as a fallback.

## 1. Boot Tiny on the physical D630

Use the already-mounted, GRUB-readable partition whose root contains the existing `/d630-gentoo/` directory. The commands below detect its mount point automatically; they do not assume a filesystem label or a machine-specific path. Run them as your normal user.

```sh
cd "$(findmnt -rn -o TARGET | while IFS= read -r m; do
    p="${m%/}/d630-gentoo"
    if [ -d "$p" ] && [ "$(findmnt -rn -T "$p" -o TARGET)" = "$m" ]; then
        printf '%s\n' "$m"
        break
    fi
done)" &&
mkdir -vp d630-tiny &&
cd d630-tiny &&
curl -fLO https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/kernel &&
curl -fLO https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/initramfs &&
curl -fLO https://raw.githubusercontent.com/AmrUser-48/d630-gentoo/main/grub2/d630-tiny.cfg &&
mv d630-tiny.cfg tiny.cfg
```

This creates `/d630-tiny/` at the root of that partition and downloads `kernel`, `initramfs`, and `tiny.cfg` there. If the directory cannot be found or the partition is not writable, the command chain stops rather than downloading the files to an unrelated location.

### Add the GRUB entry

On a Debian-based system using the standard GRUB setup, append the entry to `/etc/grub.d/40_custom`. Run this **once only**; do not append a duplicate entry if it is already present.

```sh
echo "menuentry 'D630 Tiny Linux (Gentoo Mini)' {
    search --no-floppy --file --set=root /d630-tiny/tiny.cfg
    configfile /d630-tiny/tiny.cfg
}" | sudo tee -a /etc/grub.d/40_custom
sudo update-grub
```

This adds the menu entry and regenerates GRUB's menu; it does **not** reboot the laptop. If your system uses a different custom GRUB configuration file, add the same menu entry to the file your existing GRUB setup actually reads. Keep the existing Gentoo entry as a fallback; do not overwrite anything in `/d630-gentoo/`.

After boot, Tiny starts in a text shell as `gmini`. To connect using the laptop's Wi-Fi, run:

```sh
doas wifi-connect
```

This is the text-mode Mini OS, not the graphical desktop.

The normal Terminus Powerline console font is selected during startup. To start a framebuffer terminal on another virtual console, run:

```sh
doas openvt -c 2 -s -- fbterm -n "xos4 Terminess Powerline" -- /bin/login -f gmini
```

This needs a working `/dev/fb0` framebuffer; the shipped kernel provides Intel i915 framebuffer emulation. Switch back with **Alt-F1**. Inside FbTerm, **Ctrl-Alt-C** opens another FbTerm window and **Ctrl-Alt-1** through **Ctrl-Alt-9** switch windows. If the framebuffer is unavailable, the original text console remains usable.

### Update the installed kernel and initramfs

Run this from your normal Linux installation, not from Tiny: Tiny runs from RAM, so changes made inside it disappear when you reboot. Make sure the partition containing `/d630-tiny/kernel` and `/d630-tiny/initramfs` is mounted and writable. This downloads the latest matching kernel/initramfs pair, verifies both against the release checksums, saves a backup of the current pair and GRUB config, then replaces the installed files.

```sh
sudo bash <<'UPDATE'
set -euo pipefail

boot_dir=""
while IFS= read -r mountpoint; do
  candidate="${mountpoint%/}/d630-tiny"
  if [[ -f "$candidate/kernel" &&
        -f "$candidate/initramfs" &&
        -f "$candidate/tiny.cfg" &&
        "$(findmnt -rn -T "$candidate" -o TARGET)" == "$mountpoint" ]]; then
    boot_dir=$candidate
    break
  fi
done < <(findmnt -rn -o TARGET)

[[ -n "$boot_dir" ]] || {
  echo "Could not find a mounted partition containing /d630-tiny/kernel, initramfs, and tiny.cfg." >&2
  exit 1
}

stage=$(mktemp -d "$boot_dir/.update.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
base_url=https://github.com/AmrUser-48/d630-gentoo/releases/latest/download

for asset in kernel initramfs SHA256SUMS; do
  curl -fL "$base_url/$asset" -o "$stage/$asset"
done

awk '
  $2 == "output/kernel" || $2 == "output/initramfs" {
    sub("output/", "", $2)
    print
    found[$2] = 1
  }
  END {
    if (!found["kernel"] || !found["initramfs"]) exit 1
  }
' "$stage/SHA256SUMS" | (cd "$stage" && sha256sum -c -)

backup_dir=$(mktemp -d "$boot_dir/.backup-$(date +%Y%m%d-%H%M%S).XXXXXX")
cp -p "$boot_dir/kernel" "$boot_dir/initramfs" "$boot_dir/tiny.cfg" "$backup_dir/"
mv -f -- "$stage/kernel" "$boot_dir/kernel"
mv -f -- "$stage/initramfs" "$boot_dir/initramfs"
sync

echo "Updated kernel and initramfs in $boot_dir"
echo "Previous files saved in $backup_dir"
echo "Reboot and choose D630 Tiny Linux from GRUB to use the update."
UPDATE
```

Keep the backup until you have successfully booted the updated image. To roll back, copy the old `kernel`, `initramfs`, and `tiny.cfg` from the printed backup directory back into `/d630-tiny/`.

### Kernel boot-parameter cheat sheet

At the GRUB menu, highlight D630 Tiny and press **e**. Add or change parameters at the end of the line beginning with `linux`; press **Ctrl-X** or **F10** to boot. This edit applies only to that boot. To make it permanent, edit the `linux` line in `/d630-tiny/tiny.cfg`.

| Parameter | What it does |
| --- | --- |
| `quiet` | Hide most routine kernel messages; already enabled by the default menu. |
| `loglevel=7 ignore_loglevel` | Show detailed kernel messages during boot; useful for diagnosing hangs or missing hardware. |
| `nomodeset` | Diagnostic workaround for a blank or garbled display; may reduce graphics features. |
| `panic=10` | Reboot 10 seconds after a kernel panic instead of waiting indefinitely. |
| `console=ttyS0,115200n8` | Send the console to a serial port; useful for QEMU serial logs, generally not for the laptop's built-in display. |

For example, to see boot messages, temporarily change the line from `quiet loglevel=4` to `loglevel=7 ignore_loglevel`. Tiny runs from its initramfs and RAM; a `root=` parameter is not needed. Avoid `acpi=off` as a routine fix on the D630 because it disables laptop power-management features.

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

### Open another virtual console

Tiny starts one shell automatically. The kernel supports virtual terminals, but the initramfs does not start a shell on every VT. From the running Tiny shell, open another one with:

```sh
doas openvt -c 2 -s -- /bin/bash -l
```

`-c 2` selects VT 2 and `-s` switches to it. Use `-c 3`, `-c 4`, and so on for other consoles. Switch between them with **Alt-F1**, **Alt-F2**, etc. (some laptop/desktop setups require **Ctrl-Alt-Fn**). Exit the shell on the extra VT when you are done. Kernel boot parameters such as `console=` do not start extra virtual-terminal shells.

To start the framebuffer terminal instead, use the FbTerm command shown in the boot section above. The default FbTerm font is the normal-weight Terminus Powerline bitmap font, not the bold variant.

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
| `fbterm` | Run a framebuffer terminal (requires `/dev/fb0`; use `openvt` as shown above) |
| `openvt` | Start a command on another virtual console |
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

The script lists visible network names before prompting. Enter the SSID exactly as shown and its WPA/WPA2 passphrase. The D630's Intel 3945ABG adapter supports legacy 802.11a/b/g and WPA/WPA2-PSK; it cannot connect to WPA3-only or enterprise-authenticated networks.

Your active NetworkManager row identifies the connection as `-_-` on `wlan0`. From your normal Linux installation, download the host-side helper and export that saved WPA/WPA2-Personal profile without displaying or sending the key:

```sh
helper=$(mktemp)
curl -fL https://github.com/AmrUser-48/d630-gentoo/releases/latest/download/export-wifi-profile.sh -o "$helper"
bash "$helper" '-_-' "$HOME/.config/d630-tiny"
rm -f "$helper"
findmnt -no SOURCE,FSTYPE "$HOME"
```

Keep the printed device and filesystem type for the filesystem containing your home directory. The profile is written as `~/.config/d630-tiny/wifi.conf` with owner-only permissions; it is **not** part of the repository or release image. It contains a reusable network key, so do not copy it to a shared/FAT boot partition or share it. This helper supports saved WPA/WPA2-Personal passphrases; it does not support WPA3-only, enterprise, or unsaved profiles.

After Tiny boots, mount the normal Linux filesystem that contains your home directory (replace the device and filesystem type with the values you recorded; an encrypted filesystem must first be unlocked, which Tiny does not currently do):

```sh
doas mkdir -p /mnt/host
doas mount -t ext4 /dev/sda2 /mnt/host
doas wifi-connect --config /mnt/host/home/YOUR_HOST_USER/.config/d630-tiny/wifi.conf wlan0
doas umount /mnt/host
```

Use the actual host username, root partition, and filesystem type in place of the examples. The key stays on your normal Linux filesystem; it is copied into Tiny's RAM only when connecting. Once connected, remove the profile from the normal OS when you no longer need it:

```sh
rm "$HOME/.config/d630-tiny/wifi.conf"
rmdir "$HOME/.config/d630-tiny"
```

If it fails, run this and note whether it reports a missing interface, a hard radio block, WPA authentication timeout, or DHCP failure:

```sh
doas wifi-connect --diagnose
```

For the saved local profile, use `doas wifi-connect --config /path/to/wifi.conf wlan0`. Also keep the error and diagnostics printed by the failed attempt. Check the laptop's wireless switch/Fn key if the radio is hard-blocked. Review SSIDs or other identifying network names before sharing diagnostic output; the script does not print the Wi-Fi passphrase. These Wi-Fi changes require the updated initramfs before they are available on the laptop.

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
