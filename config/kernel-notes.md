# Kernel requirements and D630 hardware notes

This is a requirements checklist, not a finished kernel configuration.

## Live boot and storage

- Legacy BIOS boot; no UEFI-only assumptions.
- Initramfs support and the tools needed to mount the live root.
- `devtmpfs`, procfs, sysfs, tmpfs, loop devices, SquashFS and OverlayFS.
- SATA/AHCI, libata, SCSI disk support and USB mass-storage support.
- ISO9660 and the filesystems used to access installed systems: ext2/3/4, VFAT, NTFS and Btrfs.
- Keep partitioning and filesystem utilities in the runtime image.

## D630 devices

- Intel GM965 / GMA X3100: retain `i915` support and a framebuffer fallback.
- Intel PRO/Wireless 3945ABG: enable the matching `iwl3945` driver and include its required firmware for the selected kernel version.
- Intel HDA audio: retain `snd-hda-intel` and required sound-core components.
- Retain USB input and joystick support if the final image size permits.
- Bluetooth support should remain available.

## Image size and reliability

- Do not remove all filesystem or graphics modules indiscriminately; a rescue image must be able to read target disks and display a usable desktop.
- Prune unrelated DVB, AMD and NVIDIA drivers only after checking dependencies and the actual kernel configuration.
- Prefer modules for hardware subsystems where that simplifies testing; built-in support is useful for boot-critical storage and live-root access.
- Check firmware licenses and redistribution terms before publishing binaries.
- Verify the final kernel config with `make olddefconfig`, inspect the resulting config, and test booting before further stripping.
