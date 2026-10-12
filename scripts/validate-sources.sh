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
test -s config/portage/profile/package.use.force
grep -Fq 'LLVM_TARGETS: -AArch64 -AMDGPU' config/portage/profile/package.use.force
grep -Fq 'config/portage/profile/package.use.force "$root/etc/portage/profile/package.use.force"' .github/workflows/gentoo-interactive-build.yml
test -s config/portage/package.use/00-core2-cpu
test -s config/portage/package.use/10-d630-hardware

grep -Fq 'media-libs/mesa -llvm -vulkan VIDEO_CARDS: -* intel' config/portage/package.use/10-d630-hardware
grep -Fq 'dev-util/mesa_clc LLVM_SLOT: -* 22' config/portage/package.use/10-d630-hardware
grep -Fq 'dev-util/mesa_clc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-runtimes/libclc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-core/llvm LLVM_TARGETS: -* X86 SPIRV' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-core/clang LLVM_TARGETS: -* X86 SPIRV' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-runtimes/libclc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'x11-base/xorg-drivers VIDEO_CARDS: -* intel i915' config/portage/package.use/10-d630-hardware
grep -Fq 'x11-base/xorg-server -minimal' config/portage/package.use/10-d630-hardware
grep -Fxq 'x11-base/xorg-drivers' config/package.list

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
grep -q 'CPU_FLAGS_X86: mmx sse sse2 sse3 ssse3' config/portage/package.use/00-core2-cpu
! grep -Eq 'CPU_FLAGS_X86:.*(mmxext|sse4_1|sse4_2|aes|avx|popcnt)' config/portage/package.use/00-core2-cpu
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
