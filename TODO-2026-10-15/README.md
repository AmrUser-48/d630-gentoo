# TODO — Gentoo Core2 minimal SquashFS
**Date:** 2026-10-15  
**Repository:** `AmrUser-48/d630-gentoo`

## Goal for today

Continue the existing Gentoo Stage 3 rebuild optimized for the Intel Core 2 system, then assemble and test a minimal SquashFS system using the rebuilt binary packages.

## 1. Restore and continue the existing build

- Restore the saved runner state: `runner-state-20261015T100327Z`.
- The restored state already contains packages partly or fully recompiled for Core 2. **Continue from this state; do not start a fresh Stage 3 build.**
- Recover the remaining rebuild queue (approximately 100 packages) from the restored state, Portage logs, and available build records.
- Determine which packages have already completed successfully and resume only the remaining work. Do not guess or replace the queue with a generic package set.
- Keep the generated binary packages from the existing state.

## 2. Finish the minimal system packages

After resuming the Stage 3 system-package rebuild, compile these target packages:

1. `x11-base/xorg-server` / required Xorg components
2. `x11-wm/openbox`
3. `app-misc/fbterm`
4. `app-misc/mc`

Resolve dependencies through the existing Gentoo configuration and continue in practical batches. Preserve successful binary packages so they can be reused.

## 3. Save and collect binary packages

- Collect the Core 2 binary packages from the restored state's Portage binpkg cache.
- Verify that packages needed by the minimal system and their dependencies are available.
- Keep the binpkgs as build outputs; do not discard them while trimming the filesystem.

## 4. Build and test the minimal SquashFS

- Construct a trimmed root filesystem from the existing build state and its binary packages.
- First test target: **Mesa + Xorg + Openbox**, with the runtime dependencies needed to run them.
- Include `fbterm` and `mc` in the minimal system.
- Produce the SquashFS image and test the minimal environment today.

## Constraints

- Preserve and reuse the saved Core 2 build state.
- Do not recompile packages that are already successfully rebuilt unless a dependency or configuration change requires it.
- Do not launch a new generic build or invent a replacement package list.
- Prioritize actual compilation, binpkg preservation, image creation, and testing over verbose terminal output.


## 5. Trim the existing Core 2 Stage 3 safely

**Do this only after the current emerge finishes and the target packages are installed.** The restored `/opt/gentoo` tree is the build/source state: never depclean it or delete its cache in place. Make a separate runtime copy, clean that copy, and leave the original tree and its binpkgs intact.

The checked-in `scripts/build-runtime-squashfs.sh` downloads a *fresh* official Stage 3. Do not use that workflow for this particular state-based build. The commands below use the already-restored Core 2 tree. They also avoid making an extra full staging copy during SquashFS creation, which saves disk space on the runner.

### 5.1 Check available disk space and completed targets

Run as root on the restored runner after compilation has stopped:

```bash
BUILD=/opt/gentoo
WORK=/tmp/d630-minroot-20261015
ROOT=$WORK/root
OUT=$WORK/output

test -x "$BUILD/bin/bash" && test -d "$BUILD/var/db/pkg" || {
  echo "Wrong or incomplete build root: $BUILD" >&2
  exit 1
}
df -h /opt /tmp
du -sh "$BUILD" "$BUILD/var/cache/binpkgs"
find "$BUILD/var/cache/binpkgs" -type f \( -name '*.gpkg.tar' -o -name '*.tbz2' \) | wc -l
```

Do not start the copy if the work filesystem lacks room for the runtime copy and the final image. Keep the binpkgs in the source state until the package release/archive has been published and verified. The final SquashFS must not contain `/var/cache/binpkgs`.

Check that the following packages are installed in the source tree before trimming: `app-i18n/fbterm`, `app-misc/mc`, `media-libs/mesa`, `x11-base/xorg-server`, `x11-base/xorg-drivers`, `x11-apps/xinit`, `x11-wm/openbox`. If any target is still compiling or missing, stop here and finish it first.

Verify them against Portage's installed-package database instead of relying on an old build log:

```bash
for atom in app-i18n/fbterm app-misc/mc media-libs/mesa \
  x11-base/xorg-server x11-base/xorg-drivers x11-apps/xinit x11-wm/openbox; do
  chroot "$BUILD" /usr/bin/portageq has_version / "$atom" || {
    echo "Missing installed target: $atom" >&2
    exit 1
  }
done
```

### 5.2 Create a runtime-only working copy

```bash
mkdir -p "$ROOT" "$OUT"
rsync -aHAX --numeric-ids --one-file-system --delete \
  --exclude='/dev/***' \
  --exclude='/proc/***' \
  --exclude='/sys/***' \
  --exclude='/run/***' \
  --exclude='/tmp/***' \
  --exclude='/var/tmp/portage/***' \
  --exclude='/var/cache/binpkgs/***' \
  --exclude='/var/cache/distfiles/***' \
  --exclude='/var/cache/edb/dep/***' \
  --exclude='/var/log/portage/***' \
  --exclude='/var/log/emerge.log' \
  --exclude='/var/log/gentoo-build-set.log' \
  --exclude='/usr/src/***' \
  "$BUILD/" "$ROOT/"
```

This copy deliberately retains Portage's installed-package database and Gentoo repository long enough to calculate dependencies. It omits the bulky binpkgs, source downloads, active build temporary files, logs, and pseudo-filesystems. The original `$BUILD` remains untouched.

Mount the virtual filesystems in the copy for chroot operations:

```bash
for MP in dev proc sys run; do
  mkdir -p "$ROOT/$MP"
  mount --rbind "/$MP" "$ROOT/$MP"
  mount --make-rslave "$ROOT/$MP"
done
```

### 5.3 Define the runtime package set and depclean only the copy

Keep a small, explicit world set. It contains the boot/init and console essentials, the requested tools, the Xorg drivers/start command, Mesa, and the OpenRC logind services needed for a non-root X session. Save the original world list for reference:

```bash
mkdir -p "$ROOT/var/lib/portage"
if [[ -f "$ROOT/var/lib/portage/world" ]]; then
  cp -a "$ROOT/var/lib/portage/world" "$OUT/world-builder-original.txt"
fi
cat > "$ROOT/var/lib/portage/world" <<'EOF'
app-admin/sudo
app-i18n/fbterm
app-misc/mc
app-shells/bash
media-fonts/dejavu
media-libs/mesa
sys-apps/coreutils
sys-apps/dbus
sys-apps/kmod
sys-apps/openrc
sys-apps/portage
sys-apps/shadow
sys-apps/util-linux
sys-auth/elogind
sys-auth/pambase
x11-apps/xinit
x11-base/xorg-drivers
x11-base/xorg-server
x11-wm/openbox
EOF
```

Portage's `@system` set is still included automatically. First capture and inspect the removal plan; do **not** blindly accept a depclean plan:

```bash
chroot "$ROOT" /bin/bash -lc \
  'emerge --ignore-default-opts --pretend --verbose --depclean --with-bdeps=n' \
  > "$OUT/depclean-preview.txt" 2>&1
tail -n 80 "$OUT/depclean-preview.txt"
```

Review `$OUT/depclean-preview.txt`. If Portage reports unresolved dependencies, a missing target, or proposes removing OpenRC, the console/login tools, Mesa, Xorg, Xorg drivers, Xinit, Openbox, ObConf-Qt, fbterm, or mc, **stop and fix the set/dependencies before continuing**. If the plan is correct, execute it on the copy only:

```bash
chroot "$ROOT" /bin/bash -lc \
  'emerge --ignore-default-opts --ask=n --verbose --depclean --with-bdeps=n' \
  > "$OUT/depclean.log" 2>&1
tail -n 50 "$OUT/depclean.log"
```

Using `--with-bdeps=n` allows build-only dependencies such as unneeded compiler components to be removed when no retained runtime package needs them. Do not run a full `@world` update or rebuild in this copy. Keep Portage and `/var/db/pkg` for this first bootable test; removing them can be a later size-reduction experiment after the image boots. Do not include `x11-misc/obconf-qt` or its Qt 6 runtime dependency closure in this first runtime package set. ObConf-Qt is deferred to a later desktop-image revision; binpkgs produced during the current build may still be retained in the builder cache.

### 5.4 Configure PID 1, console login, and the Openbox start command

This image has two init stages:

1. The early initramfs script at `initramfs/init` mounts the host filesystems, finds `/d630-gentoo/squashfs`, mounts SquashFS read-only, adds a temporary RAM OverlayFS, and calls `switch_root /mnt/newroot /sbin/init`.
2. **The SFS root's PID 1 is `/sbin/init`, using Gentoo OpenRC.** OpenRC then starts the services enabled in `/etc/runlevels`. Do not add systemd to this image.

Verify the OpenRC init exists and is executable:

```bash
chroot "$ROOT" /bin/bash -lc \
  'test -x /sbin/init && command -v rc-update && command -v rc-status'
```

For the console login and first-boot account creation, use the existing implementation in [`scripts/build-runtime-squashfs.sh`](https://github.com/AmrUser-48/d630-gentoo/blob/main/scripts/build-runtime-squashfs.sh), under **“Configure console login, first-boot user creation, and OpenRC”**. Apply that section's `d630-firstboot`, `agetty.tty1`, sudoers, hostname, hosts, and fstab setup to `$ROOT`; do not invent a second version of those service definitions. In particular, create the services before enabling them:

```bash
chroot "$ROOT" /bin/bash -lc 'rc-update add d630-firstboot sysinit'
chroot "$ROOT" /bin/bash -lc 'rc-update add agetty.tty1 default'
chroot "$ROOT" /bin/bash -lc 'rc-update add dbus default'
chroot "$ROOT" /bin/bash -lc 'rc-update add elogind default'
chroot "$ROOT" /bin/bash -lc 'rc-update show -v'
```

The last two services are important for this graphical profile: the repository's Xorg configuration uses elogind rather than making Xorg setuid-root. Confirm that `sys-apps/dbus` and `sys-auth/elogind` are installed and that both init scripts exist before enabling them. Do not silently switch to running Xorg as root if seat/session setup fails.

Set the default user session in the skeleton **before** first-boot account creation:

```bash
mkdir -p "$ROOT/etc/skel"
printf '%s\n' 'exec openbox-session' > "$ROOT/etc/skel/.xinitrc"
chmod 0644 "$ROOT/etc/skel/.xinitrc"
```

Include `x11-apps/xinit` so a local user can run `startx` from the text console. The user's `~/.xinitrc` launches `openbox-session`. If Xorg cannot acquire a seat, check that elogind and D-Bus are running and the account has an active local login session; the Xorg `suid` USE-flag is an alternative only if deliberately chosen for this legacy setup, not an automatic fallback.

The initramfs currently supports **volatile RAM persistence only**. Files changed or created during a boot—including the first-boot account and home directory—are lost at reboot. Persistent OverlayFS is a separate future task and must not be implied by this test image.

### 5.5 Remove build-only files from the copy and create SquashFS

After depclean, unmount the chroot mounts before packing:

```bash
for MP in run sys proc dev; do
  mountpoint -q "$ROOT/$MP" && umount -R "$ROOT/$MP"
done
```

Remove caches, repository checkouts, logs, debug symbols, development headers/metadata, static archives, and bytecode from the **runtime copy** only. Keep runtime shared libraries, `/usr/share/licenses`, man pages, the OpenRC service files, and `/var/db/pkg`:

```bash
# Preserve Gentoo's profile files so /etc/portage/make.profile stays valid.
test -d "$ROOT/var/db/repos/gentoo/profiles" || {
  echo "Missing Gentoo profiles; refusing to remove the repository target." >&2
  exit 1
}
find "$ROOT/var/db/repos/gentoo" -mindepth 1 -maxdepth 1 ! -name profiles -exec rm -rf -- {} +
rm -rf "$ROOT/var/tmp/portage" "$ROOT/var/cache/binpkgs" \
  "$ROOT/var/cache/distfiles" "$ROOT/var/cache/edb/dep" \
  "$ROOT/var/db/repos/guru" \
  "$ROOT/var/log/portage" "$ROOT/var/log/emerge.log" \
  "$ROOT/var/log/gentoo-build-set.log" "$ROOT/usr/src" \
  "$ROOT/usr/include" "$ROOT/usr/share/doc" "$ROOT/usr/share/info" \
  "$ROOT/usr/share/gtk-doc" "$ROOT/usr/share/help" \
  "$ROOT/usr/share/gnome/help" "$ROOT/usr/share/aclocal" \
  "$ROOT/usr/share/gettext" "$ROOT/usr/lib/debug" "$ROOT/usr/lib64/debug"
chroot "$ROOT" /bin/bash -lc 'test -e /etc/portage/make.profile'
find "$ROOT/usr" -type f \( -name '*.a' -o -name '*.la' -o -name '*.pyc' \) -delete
find "$ROOT/usr" -type d -name __pycache__ -prune -exec rm -rf {} +
find "$ROOT/usr" -type d \( -name pkgconfig -o -name cmake \) -prune -exec rm -rf {} +
mkdir -p "$ROOT/var/tmp/portage" "$ROOT/var/cache/binpkgs" "$ROOT/var/cache/distfiles"
```

Create the SFS **outside** the runtime root, so the image cannot include itself. The settings match this repository's existing SquashFS builder: Zstandard, 1 MiB blocks, compression level 15. The kernel must have SquashFS and Zstandard decompression enabled.

```bash
find "$ROOT/var/db/pkg" -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | sort \
  > "$OUT/INSTALLED-PACKAGES.txt"
rm -f "$OUT/squashfs" "$OUT/SQUASHFS-INFO.txt" "$OUT/INIT-PROBE.txt" "$OUT/SHA256SUMS"
mksquashfs "$ROOT" "$OUT/squashfs" -noappend -comp zstd -b 1M -Xcompression-level 15
unsquashfs -s "$OUT/squashfs" | tee "$OUT/SQUASHFS-INFO.txt"
unsquashfs -ll "$OUT/squashfs" | grep -E 'sbin/init($| ->)' | tee "$OUT/INIT-PROBE.txt"
sha256sum "$OUT/squashfs" > "$OUT/SHA256SUMS"
sha256sum --check "$OUT/SHA256SUMS"
du -sh "$ROOT" "$OUT/squashfs"
```

The `INIT-PROBE.txt` check must show an executable `/sbin/init` entry. Keep the kernel/initramfs pair that matches the early boot code and place the files at the paths expected by the GRUB entry. The current init script's default image path is **`/d630-gentoo/squashfs`**; its host-device scan supports NTFS3, exFAT, VFAT, ext4, and Btrfs. Its SquashFS mount is read-only and the overlay is temporary RAM. Do not use `d630.persistence` values other than `volatile` with this initramfs implementation.

Minimum kernel support for this boot path: devtmpfs, procfs, sysfs, tmpfs, OverlayFS, loop devices, SquashFS with Zstandard decompression, and built-in drivers/filesystem support for the partition holding `/d630-gentoo/squashfs`. If SquashFS uses Zstandard but the kernel lacks `CONFIG_SQUASHFS_ZSTD=y`, boot will fail before OpenRC starts.

## 6. First-boot test checklist

1. Confirm the produced `squashfs` and `SHA256SUMS` verify, and place the SFS at `/d630-gentoo/squashfs` on a partition supported by the initramfs.
2. Boot using the matching Core2 kernel and the initramfs in the format expected by that kernel/GRUB entry.
3. Verify the early init log finds and mounts SquashFS, then calls `switch_root`; OpenRC should become PID 1 and bring up `agetty.tty1`.
4. Complete the first-boot account prompt. Log in on tty1, confirm `mc` and `fbterm` are present, then test X from that user's console with `startx`. Confirm Mesa uses the Intel GM965/Crocus path rather than llvmpipe where applicable.
5. After any failed test, inspect the boot log and the root cause first. Do not blindly remove more packages or trim additional libraries until this baseline boots.

## References

- [Gentoo Portage `emerge --depclean` manual](https://github.com/gentoo/portage/blob/master/man/emerge.1): depclean calculates reachability from `@world`; preview and review the removal list.
- [Gentoo Handbook: Initscripts](https://wiki.gentoo.org/wiki/Handbook:Parts/Working/Initscripts/en) and [OpenRC guide](https://github.com/OpenRC/openrc/blob/master/user-guide.md): runlevels and `rc-update`.
- [Gentoo Startx guide](https://wiki.gentoo.org/wiki/Startx) and [Xorg USE-flag guidance](https://www.gentoo.org/support/news-items/2020-06-24-xorg-server-dropping-default-suid.html): starting X as a regular user and the logind requirement.
- [SquashFS `mksquashfs` manual](https://github.com/plougher/squashfs-tools/blob/master/Documentation/manpages/mksquashfs.1): supported compressors and block size.
