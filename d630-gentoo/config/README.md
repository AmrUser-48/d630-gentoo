# D630 Gentoo boot userspace and firmware

## BusyBox

The files in `busybox/` are Kconfig **allnoconfig fragments**, not complete Gentoo savedconfig files. The static fragment enables only the applets used by [initramfs/init](../initramfs/init): `ash`, `cat`, `chmod`, `cp`, `find -type`, `mkdir`, `mount` with loop and mount flags, `switch_root`, `umount`, and `wc`. Shell built-ins provide `case`, `read`, `printf`, tests, and arithmetic.

Generate a complete configuration from the BusyBox source tree matching the selected Gentoo ebuild version:

```sh
KCONFIG_ALLCONFIG=/path/to/d630-static.config make allnoconfig
```

Then install the generated `.config` as `/etc/portage/savedconfig/sys-apps/busybox` and build with Gentoo USE flags `savedconfig static make-symlinks`. Do not copy the fragment directly into the savedconfig path: Gentoo's ebuild runs `oldconfig` on a complete config, and missing symbols may otherwise receive upstream defaults.

[busybox/d630-dynamic.config](busybox/d630-dynamic.config) has the same applet set with static linking disabled. Generate it the same way, save the resulting full `.config`, and build with `savedconfig make-symlinks -static`. Dynamic BusyBox depends on the target libc and is not suitable as a standalone initramfs shell.

The current kernel/initramfs workflow uses the runner's `busybox-static` package, not Gentoo's BusyBox ebuild; these fragments are ready for a future Portage-built initramfs and do not change that workflow.

## Firmware selection and stripping

[firmware.keep](firmware.keep) is the final SquashFS allowlist, with paths relative to `/lib/firmware`. The build removes every other regular file and symlink from the **staging copy only**; the restored Gentoo root and binary-package cache are not modified.

The allowlist retains Intel 3945ABG firmware, the wireless regulatory database and signature, and the two Core 2 microcode blobs supplied by the matching kernel bundle. Gentoo's `linux-firmware` savedconfig selects the root-level `iwlwifi-3945-2.ucode` alias; Gentoo's firmware-copy patch also includes its nested `intel/iwlwifi/iwlwifi-3945-2.ucode` target. The existing runtime package set selects `net-wireless/wireless-regdb`, which installs `regulatory.db` and `regulatory.db.p7s`. The kernel workflow independently embeds the iwlwifi blob in the initramfs and prepends Intel microcode in the early cpio archive.

The D630 GM965/GMA X3100 uses the in-kernel `i915` driver and does not need newer Intel graphics firmware. No Bluetooth firmware is selected because the D630 adapter has not yet been identified.
