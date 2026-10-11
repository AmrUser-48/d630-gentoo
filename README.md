# d630-gentoo

A minimal Gentoo-based live rescue desktop for the Dell Latitude D630. The initial source scaffold defines the target and package plan; it is **not yet a bootable ISO**.

## Target

- x86_64, legacy BIOS boot
- Intel Core 2 Duo T7250 / Core 2 family tuning
- Intel GM965 / GMA X3100 graphics
- Intel PRO/Wireless 3945ABG Wi-Fi, Bluetooth, USB and Intel HDA audio
- NTFS and Btrfs support for rescue and installation tasks
- Xorg with Openbox, dwm and herbstluftwm; xterm as a small fallback terminal, Alacritty as an optional terminal

## Build rules

- Compile target: `-O2 -march=core2 -mtune=core2`. Do not use `-march=native`: GitHub Actions build hosts are not the target laptop.
- Build in a separate Gentoo environment; do not include Portage, compilers, headers, build trees or package caches in the final runtime image.
- Planned image design: SquashFS root plus initramfs and a RAM-backed OverlayFS writable layer.
- Keep a small, reliable xterm fallback. Alacritty and the Intel Xorg DDX are optional candidates to validate against the selected Gentoo profile and Mesa stack.
- Keep required firmware in the image and verify licensing/redistribution terms before publishing it.

## Source layout

- `config/package.list`: initial runtime package candidates, not a resolved dependency closure.
- `config/make.conf`: Core 2 compiler settings and conservative initial USE flags.
- `config/kernel-notes.md`: hardware and live-image kernel requirements.
- `scripts/validate-sources.sh`: basic scaffold checks.
- `.github/workflows/validate.yml`: validates source files only; it does not build an ISO.

## Planned implementation stages

1. Validate package atoms, USE flags and profile choices against the current Gentoo tree.
2. Bootstrap a build-only Gentoo environment in GitHub Actions.
3. Install the selected runtime packages into a separate staging root.
4. Build and configure the kernel and initramfs; add SquashFS and OverlayFS startup.
5. Remove build-only content, generate a legacy-BIOS bootable ISO, and test it in a VM.
6. Test on the D630; consider a raw disk image and optional persistence only after the ISO works.

The initial workflow deliberately does not attempt a long Gentoo build yet.
