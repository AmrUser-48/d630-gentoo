#!/bin/sh
set -eu

test -s README.md
test -s d630-tiny/README.md
test -s d630-gentoo/README.md
test -s kernels/README.md
test -s d630-gentoo/config/package.list
test -s d630-gentoo/config/initramfs-package.list
! test -e tinyos
! test -e grub2
! test -e initramfs
! test -e config/kernel

test -s d630-gentoo/config/package.list
test -s config/make.conf
test -s kernels/README.md
test -s d630-gentoo/initramfs/init
test -s d630-gentoo/boot/iso/loopback.cfg
test -s d630-gentoo/config/kernel-cmdline.txt
test -s config/portage/make.conf
test -s config/portage/binrepos.conf/gentoobinhost.conf
grep -Fq 'https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/' config/portage/binrepos.conf/gentoobinhost.conf
grep -Fq 'verify-signature = true' config/portage/binrepos.conf/gentoobinhost.conf
grep -Fq 'FEATURES="parallel-fetch buildpkg getbinpkg"' config/portage/make.conf
grep -Fq 'FEATURES="parallel-fetch buildpkg getbinpkg"' config/make.conf
grep -Fq -- '--with-bdeps=n' config/portage/make.conf
grep -Fq 'NINJAOPTS="-j4"' config/portage/make.conf
grep -Fq 'NINJAOPTS="-j4"' config/make.conf
grep -Fq 'NINJAOPTS="-j%s"' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'EMERGE_DEFAULT_OPTS="--ask --verbose --jobs=1 --load-average=4 --with-bdeps=n --usepkg"' config/portage/make.conf
test -s config/portage/profile/package.use.force
grep -Fq 'LLVM_TARGETS: -AArch64 -AMDGPU' config/portage/profile/package.use.force
grep -Fq 'profile/package.use.force/zz-d630-llvm' .github/workflows/gentoo-interactive-build.yml
test -s config/portage/package.use/00-core2-cpu
test -s config/portage/package.use/10-d630-hardware
test -s config/portage/package.use/20-repositories
test -s config/portage/package.accept_keywords/20-guru
test -s d630-gentoo/config/runtime/d630-firstboot
grep -Fq 'app-eselect/eselect-repository git' config/portage/package.use/20-repositories
grep -Fq 'app-misc/lf ~amd64' config/portage/package.accept_keywords/20-guru

grep -Fq 'media-libs/mesa -llvm -vulkan VIDEO_CARDS: -* intel' config/portage/package.use/10-d630-hardware
grep -Fq 'dev-util/mesa_clc LLVM_SLOT: -* 22' config/portage/package.use/10-d630-hardware
grep -Fq 'dev-util/mesa_clc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-runtimes/libclc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-core/llvm LLVM_TARGETS: -* X86 SPIRV' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-core/clang LLVM_TARGETS: -* X86 SPIRV' config/portage/package.use/10-d630-hardware
grep -Fq 'llvm-runtimes/libclc VIDEO_CARDS: -*' config/portage/package.use/10-d630-hardware
grep -Fq 'x11-base/xorg-drivers VIDEO_CARDS: -* intel' config/portage/package.use/10-d630-hardware
grep -Fq 'x11-base/xorg-drivers INPUT_DEVICES: -* evdev joystick libinput synaptics' config/portage/package.use/10-d630-hardware
test -s d630-gentoo/config/xorg/99-synaptics.conf
grep -Fq 'x11-base/xorg-server -minimal' config/portage/package.use/10-d630-hardware
grep -Fxq 'x11-base/xorg-drivers' d630-gentoo/config/package.list

test -s d630-gentoo/config/package-sets/runner-tools.list
test -s d630-gentoo/config/package-sets/cli.list
test -s d630-gentoo/config/package-sets/tiny-console.list
test -s d630-gentoo/config/package-sets/gui-initram.list
grep -Fxq 'media-libs/alsa-lib' d630-gentoo/config/package-sets/gui-initram.list
grep -Fxq 'media-libs/alsa-ucm-conf' d630-gentoo/config/package-sets/gui-initram.list
grep -Fxq 'media-sound/alsa-utils' d630-gentoo/config/package-sets/gui-initram.list
grep -Fq 'CONFIG_SND_HDA_INTEL=y' kernels/profiles/40-d630-builtin.config
grep -Fq 'CONFIG_SND_HDA_CODEC_SIGMATEL=y' kernels/profiles/40-d630-builtin.config
test -s config/portage/package.use/50-tiny-console
test -s d630-gentoo/config/package-sets/development.list
test -s d630-gentoo/config/package-sets/desktop.list
test -s d630-gentoo/config/package-sets/multimedia.list
test -s d630-gentoo/config/package-sets/daily-driver.list
test -s scripts/gentoo-build-set
test -s .github/workflows/gentoo-interactive-build.yml
test -s .github/workflows/publish-gentoo-binpkgs.yml
test -s scripts/package-binpkgs-release.sh
test -s scripts/install-binpkgs-release.sh
test -s scripts/snapshot-gentoo-session.sh
test -s scripts/save-runner-state-encrypted.sh
! test -e scripts/publish-pending-state-save.sh
test -s d630-gentoo/scripts/build-squashfs.sh
test -s d630-gentoo/scripts/build-squashfs-inplace.sh
test -s d630-gentoo/scripts/build-state-squashfs.sh
test -s .github/workflows/build-d630-state-boot-bundle.yml
grep -Fq 'workflow_call:' .github/workflows/build-d630-kernel.yml
bash -n d630-gentoo/scripts/build-squashfs-inplace.sh
bash -n d630-gentoo/scripts/build-state-squashfs.sh
test -s d630-gentoo/scripts/build-runtime-squashfs.sh
test -s d630-gentoo/scripts/install-runtime-dotfiles.sh
bash -n d630-gentoo/scripts/install-runtime-dotfiles.sh
grep -Fq 'app-misc/tealdeer' d630-gentoo/config/package-sets/cli.list
grep -Fq 'app-editors/neovim' d630-gentoo/config/package-sets/cli.list
grep -Fq 'sys-process/htop' d630-gentoo/config/package-sets/cli.list
grep -Fq 'grep -vx '\''sys-apps/man-db'\''' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'sys-apps\/man-db$/d' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'c1:12345:respawn:/sbin/agetty --autologin gentoo --noclear tty1 linux' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'NOPASSWD: ALL' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq "sed -i '/command -v lesspipe/,+2d' \"\$SKEL/.aaliases\"" d630-gentoo/scripts/install-runtime-dotfiles.sh
grep -Fq '6da2f0e0e8b90d61ac3f37e9c3b832edaddf7298' d630-gentoo/scripts/install-runtime-dotfiles.sh
grep -Fq 'Removing manuals, documentation trees, locale sources, and unused translations.' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'Required runtime application is absent from the final SquashFS' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'if [[ "$RUNTIME_PROFILE" == openbox || "$RUNTIME_PROFILE" == desktop || "$RUNTIME_PROFILE" == daily-driver || "$RUNTIME_PROFILE" == gui-initram ]]; then' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'Install Mesa from an imported binary package only' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'the openbox SquashFS profile requires an imported binary-package release containing Mesa' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'RUNTIME_ATOMS="$(awk '\''$0 != "media-libs/mesa"'\''' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq -- '--getbinpkg --usepkgonly --onlydeps' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq -- '--getbinpkg=n --usepkgonly' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'chown "0:$PORTAGE_GID" "$ROOT/var/tmp/portage"' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'command -v usermod && command -v openssl && command -v visudo' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'useradd -M -U -u 1000 -s /bin/bash gentoo' d630-gentoo/config/runtime/d630-firstboot
grep -Fq 'awk -F: '\''$1 != "gentoo" { print $1 }'\'' /etc/group | paste -sd, -' d630-gentoo/config/runtime/d630-firstboot
grep -Fq 's0:12345:respawn:/sbin/agetty -L 115200 ttyS0 vt100' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq "rc-update del netmount default" d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'install -m 0755 "$GITHUB_WORKSPACE/d630-gentoo/config/runtime/d630-firstboot"' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'find "$stage" -xdev -uid 1000 -exec chown -h 0 {} +' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'chown 0:0 "$stage/var"' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'chroot "$ROOT" chmod 4755 /usr/bin/sudo' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'chmod 0755 "$ROOT/etc/sudoers.d"' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'chown -R gentoo:gentoo /home/gentoo' d630-gentoo/config/runtime/d630-firstboot
grep -Fq 'openssl passwd -6 gentoo' d630-gentoo/config/runtime/d630-firstboot
grep -Fq 'find "$ROOT" -xdev -uid 1000 -exec chown -h 0 {} +' d630-gentoo/scripts/build-state-squashfs.sh
grep -Fq 'umask 0002; export LC_ALL=C; source /etc/portage/make.conf; export FEATURES=' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq '\${FEATURES} -userpriv' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'the installed Mesa binpkg has USE=llvm' d630-gentoo/scripts/build-runtime-squashfs.sh

test -s d630-gentoo/scripts/build-runtime-squashfs-local.sh
test -s .github/workflows/build-d630-runtime-squashfs.yml
grep -Fq 'contents: write' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'softprops/action-gh-release@v3' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'eselect repository enable guru' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'emaint sync -r guru' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'config/portage/package.accept_keywords/. "$root/etc/portage/package.accept_keywords/"' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'uses: actions/upload-artifact@v4' .github/workflows/publish-gentoo-binpkgs.yml
grep -Fq 'name: Prepare existing Gentoo assets for SquashFS build' .github/workflows/publish-gentoo-binpkgs.yml
grep -Fq 'name: Download recovered Gentoo assets artifact' .github/workflows/build-d630-runtime-squashfs.yml
grep -Fq 'LOCAL_RELEASE_ASSETS_DIR' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'LOCAL_BINPKG_ARCHIVE' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'Archive format: gpg-aes256-encrypted-zstd-tar' scripts/save-runner-state-encrypted.sh
grep -Fq 'save-gentoo-state --resume' scripts/save-runner-state-encrypted.sh
grep -Fq 'Remote release tag does not match the local snapshot.' scripts/save-runner-state-encrypted.sh
grep -Fq 'Remote release assets do not exactly match this snapshot.' scripts/save-runner-state-encrypted.sh
grep -Fq 'STATE_ENCRYPTION_PASSPHRASE' .github/workflows/restore-gentoo-runner-state.yml
grep -Fq 'gpg --batch --yes --pinentry-mode loopback' .github/workflows/restore-gentoo-runner-state.yml
! grep -Fq 'softprops/action-gh-release@v3' .github/workflows/publish-gentoo-binpkgs.yml
! grep -Fq 'softprops/action-gh-release@v3' .github/workflows/build-d630-runtime-squashfs.yml

grep -q 'march=core2' config/make.conf
grep -q -- '-march=core2 -mtune=core2' config/portage/make.conf
grep -q 'CPU_FLAGS_X86: mmx sse sse2 sse3 ssse3' config/portage/package.use/00-core2-cpu
! grep -Eq 'CPU_FLAGS_X86:.*(mmxext|sse4_1|sse4_2|aes|avx|popcnt)' config/portage/package.use/00-core2-cpu
! grep -Eq 'cpu_flags_x86_(sse4_1|sse4_2|aes|avx|popcnt)' config/portage/package.use/00-core2-cpu
grep -q 'x11-base/xorg-server' d630-gentoo/config/package.list
grep -q 'x11-wm/openbox' d630-gentoo/config/package.list
grep -qi 'squashfs' kernels/README.md
grep -Fxq 'CONFIG_OVERLAY_FS=y' kernels/profiles/40-d630-builtin.config
grep -Fxq 'CONFIG_BLK_DEV_LOOP=y' kernels/profiles/40-d630-builtin.config
grep -q 'd630.persistence=auto' d630-gentoo/boot/iso/loopback.cfg
grep -q 'd630.persistence=volatile' d630-gentoo/boot/iso/loopback.cfg
sh -n d630-gentoo/initramfs/init
sh -n d630-gentoo/scripts/create-persistence-image.sh
sh -n d630-tiny/init d630-tiny/wifi-connect
bash -n d630-tiny/export-wifi-profile.sh d630-tiny/build-setup-tools.sh d630-tiny/build-initramfs.sh
bash -n scripts/gentoo-build-set
bash -n scripts/package-binpkgs-release.sh
bash -n scripts/install-binpkgs-release.sh
bash -n scripts/snapshot-gentoo-session.sh
bash -n scripts/save-runner-state-encrypted.sh

# bash -n does not parse Python embedded in quoted heredocs. Compile those
# snippets too, so malformed embedded Python in the single state-save script is caught.
python3 - <<'PY'
from pathlib import Path
import re

for filename in ("scripts/save-runner-state-encrypted.sh",):
    source = Path(filename).read_text(encoding="utf-8")
    snippets = re.findall(r"<<'PY'[ \t]*\r?\n(.*?)^[ \t]*PY[ \t]*$", source, re.S | re.M)
    if not snippets:
        raise SystemExit(f"No embedded Python heredocs found in {filename}")
    for index, snippet in enumerate(snippets, start=1):
        compile(snippet, f"{filename}:python-heredoc-{index}", "exec")
print("embedded Python syntax: passed")
PY
bash -n d630-gentoo/scripts/build-squashfs.sh
bash -n d630-gentoo/scripts/build-runtime-squashfs.sh
bash -n d630-gentoo/scripts/build-runtime-squashfs-local.sh
grep -Fq 'du -shx "$src" "$output"' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'usr/bin/init($| ->)' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq "MINIMAL_RUNTIME=true bash" d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq -- "--exclude='/var/cache/***'" d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'Removing Portage, language runtimes, development tools, and compiler binaries.' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'remove_package_payload sys-devel/gcc true' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'import bz2, json, lzma, sqlite3, ssl, sys' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'libgcc_s.so.[0-9]*|libstdc++.so.[0-9]*|libatomic.so.[0-9]*)' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'rm -f "$stage/usr/share/hwdata/oui.txt"' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'dev-lang/python' d630-gentoo/config/package-sets/gui-initram.list
grep -Fq '"$stage/var/db/pkg"' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'rm -f "$stage/usr/bin"/{g-ir-*,eu-*,sqlite3,perl*}' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'ln -s ../usr/lib/netifrc "$stage/lib/netifrc"' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'LLVM/Clang package records are present in the input root' d630-gentoo/scripts/build-squashfs.sh
grep -Fq 'dev-build/|dev-lang/perl-|dev-perl/|dev-util/|perl-core/' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'LOCAL_BINPKG_ARCHIVE' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq 'OUTPUT_DIR' d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq -- "--getbinpkg --usepkgonly" d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq "net-wireless/wireless-regdb" d630-gentoo/scripts/build-runtime-squashfs.sh
grep -Fq -- '--ignore-default-opts --ask=n --verbose' scripts/gentoo-build-set
grep -Fq "emerge --ignore-default-opts --sync --quiet" .github/workflows/gentoo-interactive-build.yml
grep -q 'rootfs.squashfs' d630-gentoo/boot/iso/loopback.cfg
grep -q 'gentoo-data.img' d630-gentoo/boot/iso/loopback.cfg
! grep -q '@SHELL@' d630-gentoo/config/package-sets/daily-driver.list

test -s d630-gentoo/boot/grub/three-file.cfg
grep -Fq 'd630-gentoo/kernel' d630-gentoo/boot/grub/three-file.cfg
grep -Fq 'd630-gentoo/initramfs' d630-gentoo/boot/grub/three-file.cfg
! grep -Fq 'd630.boot_uuid=$d630_boot_uuid' d630-gentoo/boot/grub/three-file.cfg
grep -Fq '/d630-gentoo/squashfs' d630-gentoo/initramfs/init
! grep -Fq '$(blkid' d630-gentoo/initramfs/init

test -s kernels/profiles/20-d630-base.config
test -s kernels/profiles/30-d630-live.config
test -s kernels/profiles/40-d630-builtin.config
grep -Fxq 'CONFIG_MODULES=y' kernels/profiles/20-d630-base.config
grep -Fxq 'CONFIG_DRM_I915=m' kernels/profiles/20-d630-base.config
grep -Fxq 'CONFIG_IWL3945=m' kernels/profiles/20-d630-base.config
grep -Fxq 'CONFIG_BLK_DEV_INITRD=y' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_DRM_I915=y' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_IWL3945=y' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_SQUASHFS=n' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_OVERLAY_FS=n' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_BLK_DEV_LOOP=n' kernels/profiles/30-d630-live.config
grep -Fxq 'CONFIG_SQUASHFS_ZSTD=y' kernels/profiles/40-d630-builtin.config
grep -Fxq 'CONFIG_IWL3945=y' kernels/profiles/40-d630-builtin.config
grep -Fxq 'CONFIG_USB_NET_RNDIS_HOST=y' kernels/profiles/40-d630-builtin.config
bash scripts/validate-kernel-profiles.sh

test -s scripts/validate-kernel-config.sh
bash scripts/validate-kernel-config.sh
echo "D630 Tiny + Gentoo OS sources and all three kernel profiles: validation passed"
