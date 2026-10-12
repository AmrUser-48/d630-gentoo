#!/bin/sh
set -eu

test -s README.md
test -s config/package.list
test -s config/make.conf
test -s config/kernel-notes.md
test -s initramfs/init
test -s iso/boot/grub/loopback.cfg
test -s config/kernel-cmdline.txt
test -s config/portage/make.conf
test -s config/portage/package.use/00-core2-cpu
test -s config/portage/package.use/10-d630-hardware
test -s config/package-sets/runner-tools.list
test -s config/package-sets/cli.list
test -s config/package-sets/development.list
test -s config/package-sets/desktop.list
test -s config/package-sets/multimedia.list
test -s config/package-sets/daily-driver.list
test -s scripts/gentoo-build-set
test -s .github/workflows/gentoo-interactive-build.yml

grep -q 'march=core2' config/make.conf
grep -q -- '-march=core2 -mtune=core2' config/portage/make.conf
grep -q 'cpu_flags_x86_ssse3' config/portage/package.use/00-core2-cpu
! grep -Eq 'cpu_flags_x86_(mmxext|sse4_1|sse4_2|aes|avx|popcnt)' config/portage/package.use/00-core2-cpu
! grep -Eq 'cpu_flags_x86_(sse4_1|sse4_2|aes|avx|popcnt)' config/portage/package.use/00-core2-cpu
grep -q 'x11-base/xorg-server' config/package.list
grep -q 'x11-wm/openbox' config/package.list
grep -qi 'squashfs' config/kernel-notes.md
grep -q 'CONFIG_OVERLAY_FS=y' config/kernel-notes.md
grep -q 'CONFIG_BLK_DEV_LOOP=y' config/kernel-notes.md
grep -q 'd630.persistence=auto' iso/boot/grub/loopback.cfg
grep -q 'd630.persistence=volatile' iso/boot/grub/loopback.cfg
sh -n initramfs/init
sh -n scripts/create-persistence-image.sh
bash -n scripts/gentoo-build-set
grep -q 'rootfs.squashfs' iso/boot/grub/loopback.cfg
grep -q 'gentoo-data.img' iso/boot/grub/loopback.cfg
! grep -q '@SHELL@' config/package-sets/daily-driver.list

echo "d630-gentoo source scaffold: validation passed"
