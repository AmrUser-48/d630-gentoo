# D630 Gentoo boot userspace and firmware

## BusyBox

The early userspace uses the static profile in [busybox/d630-static.config](busybox/d630-static.config). It covers the commands used by [initramfs/init](../initramfs/init): `ash`, `cat`, `chmod`, `cp`, `find -type`, `mkdir`, `mount` with loop and mount flags, `switch_root`, `umount`, and `wc`. Shell built-ins provide `case`, `read`, `printf`, tests, and arithmetic`.

The dynamic alternative is [busybox/d630-dynamic.config](busybox/d630-dynamic.config). It uses the same applet set but links against the target libc; it is not suitable for a standalone early initramfs. Gentoo's BusyBox ebuild also controls linkage through the package-local `static` USE flag. The active Portage profile enables `static`.

The runtime builder installs the static savedconfig at `/etc/portage/savedconfig/sys-apps/busybox`. To test the dynamic profile, replace that savedconfig with `d630-dynamic.config` and change `sys-apps/busybox savedconfig static make-symlinks` to `sys-apps/busybox savedconfig -static make-symlinks` in `config/portage/package.use/60-d630-firmware-busybox`.

## Firmware selection and stripping

[firmware.keep](firmware.keep) is the final SquashFS allowlist, with paths relative to `/lib/firmware`. The build removes every other regular file and symlink from the **staging copy only**; the restored Gentoo root and binary-package cache are not modified.

The allowlist retains Intel 3945ABG firmware, the wireless regulatory database and signature, and the two Core 2 microcode blobs supplied by the matching kernel bundle. Gentoo's `linux-firmware` savedconfig selects the three package-provided files before packaging. The kernel workflow independently embeds the iwlwifi blob in the initramfs and prepends Intel microcode in the early cpio archive.

The D630 GM965/GMA X3100 uses the in-kernel `i915` driver and does not need newer Intel graphics firmware. No Bluetooth firmware is selected because the D630 adapter has not yet been identified.
