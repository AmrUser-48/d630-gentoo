# Current D630 Gentoo SquashFS TODO

Date: 2026-10-29  
Target: three-file boot with the Openbox runtime SquashFS and kernel `6.18.56-d630-gentoo`.

## Confirmed working

- Kernel + external initramfs boot and locate `/d630-gentoo/squashfs`.
- Initramfs mounts SquashFS read-only, creates the volatile OverlayFS, and switches to the Gentoo root.
- OpenRC reaches runlevel 3; D-Bus and elogind start; elogind creates `seat0`; the `gentoo` account logs in and obtains a session.
- Current SquashFS is about 198.43 MiB, below the 300 MiB target.

## Priority 1 — verify graphical startup with a real virtual terminal

- [ ] Retest from QEMU through VNC with VGA enabled and kernel argument `console=tty0`. The failed `startx` attempt was made after a serial-only boot (`console=ttyS0`, QEMU display disabled); Xorg failed at `parse_vt_settings: Cannot open /dev/tty0 (Permission denied)`. That does **not** establish an SFS defect because the serial login is not a local virtual-terminal session.
- [ ] Log in from the VNC console and run `startx`. Save and inspect `/home/gentoo/.local/share/xorg/Xorg.0.log` if it fails. The initial “`.Xauthority` does not exist” message is not the fatal error.
- [ ] Confirm `/home/gentoo/.xinitrc` contains `exec openbox-session` and that Openbox actually starts.
- [ ] If Xorg still cannot acquire the VT/seat, check the active local login session, PAM/elogind integration, and D-Bus. Keep the intended non-setuid Xorg + elogind setup; do not blindly enable Xorg's `suid` USE flag.
- [ ] Treat QEMU Openbox startup as a userspace smoke test only. Validate Intel GM965/Crocus acceleration separately on the physical D630; QEMU's virtual display does not test the laptop GPU.

## Priority 2 — fix or account for boot warnings

- [ ] Find which file in the generated root sets `net.core.default_qdisc` (check `/etc/sysctl.conf` and `/etc/sysctl.d/`). The current kernel reports that sysctl key as unavailable. Remove the stale setting or apply it conditionally; it is nonfatal but makes every boot noisy.
- [ ] Investigate the OpenRC warning that `/lib/modules/6.18.56-d630-gentoo/modules.devname` is missing. Inspect the actual `/lib/modules/6.18.56-d630-gentoo` tree and the build's `KERNEL-MODULES.txt`/manifest. If the matching kernel modules were not included, rebuild the SFS with the matching kernel bundle so the module tree and D630 firmware are included; run `depmod` as part of image preparation. Verify required modules such as `iwl3945` and any modular graphics, audio, input, and Bluetooth drivers. If the tree exists and only `modules.devname` is absent, establish whether any required module metadata is actually missing before changing the build. This warning is nonfatal in the QEMU boot.
- [ ] The duplicate inherited audit-session-ID warning from elogind is nonfatal. Revisit it only if the new local-VT graphical session shows session/logind problems.

## Priority 3 — separate VM setup issues from SFS defects

- [ ] NetworkManager reported `offline` in the current QEMU run. The test command did not explicitly configure a virtual NIC; add a QEMU user-mode NIC (for example, `-nic user,model=e1000`) when testing guest networking. Do not treat that message alone as an SFS network failure.
- [ ] Recheck the SquashFS checksum and compressed size after any rebuild. Keep the image below 300 MiB.

## Acceptance criteria

- [ ] VNC/QEMU local-console login succeeds and `startx` launches Openbox without a VT/seat error.
- [ ] Matching kernel modules and firmware required by the D630 are available in the runtime root (or are explicitly built into the kernel / supplied by the initramfs).
- [ ] Unsupported sysctl configuration is removed or guarded; remaining warnings are documented and understood.
- [ ] Physical D630 testing separately confirms Intel graphics, Wi-Fi, Bluetooth, audio, and input hardware.

## Newly identified — QEMU VNC video adapter is unsupported by the D630 kernel config

- [ ] Xorg now fails to find/open a usable video device during QEMU VNC testing. This is likely separate from the earlier serial-console `/dev/tty0` failure.
- [ ] The current `config/kernel/d630-base.fragment` explicitly disables `CONFIG_DRM_BOCHS`, `CONFIG_DRM_VIRTIO_GPU`, `CONFIG_DRM_QXL`, and `CONFIG_DRM_VMWGFX`; `CONFIG_DRM_SIMPLEDRM=y` does not guarantee a DRM card with QEMU direct-kernel boot. QEMU's `-vga std` adapter uses the Bochs VBE interface, so the current D630-focused kernel may expose no usable `/dev/dri/card*` device to Xorg.
- [ ] Confirm in the guest: `ls -l /dev/dri /dev/fb* 2>&1; grep -E '\\(EE\\)|No devices|modeset|drm|vesa|intel' /home/gentoo/.local/share/xorg/Xorg.0.log`.
- [ ] For a reliable QEMU graphics test, build a separate test kernel with `CONFIG_DRM_BOCHS=y` and use QEMU `-vga std` (then verify `/dev/dri/card0` exists). Keep the physical D630 kernel profile unchanged unless there is a separate hardware reason to enable extra virtual-GPU drivers.
- [ ] Alternative to test before a kernel rebuild: add Gentoo package `x11-drivers/xf86-video-vesa` to a test SFS and verify whether it can drive QEMU's standard VGA under this direct-kernel boot. Do not assume this works until Xorg log confirms it.
- [ ] Once QEMU has a supported video device, retest `startx` and Openbox. This is a QEMU adapter/driver compatibility issue until proven otherwise; do not label it a general D630 Intel-GPU failure.
