#!/bin/sh
set -eu

test -s README.md
test -s config/package.list
test -s config/make.conf
test -s config/kernel-notes.md
test -s initramfs/init
test -s iso/boot/grub/loopback.cfg
test -s config/kernel-cmdline.txt

grep -q 'march=core2' config/make.conf
grep -q 'x11-base/xorg-server' config/package.list
grep -q 'x11-wm/openbox' config/package.list
grep -qi 'squashfs' config/kernel-notes.md
grep -q 'CONFIG_OVERLAY_FS=y' config/kernel-notes.md
grep -q 'CONFIG_BLK_DEV_LOOP=y' config/kernel-notes.md
grep -q 'd630.persistence=auto' iso/boot/grub/loopback.cfg
grep -q 'd630.persistence=volatile' iso/boot/grub/loopback.cfg
sh -n initramfs/init
sh -n scripts/create-persistence-image.sh

echo "d630-gentoo source scaffold: validation passed"
