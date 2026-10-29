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
test -s config/runtime/d630-firstboot
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
test -s config/xorg/99-synaptics.conf
grep -Fq 'x11-base/xorg-server -minimal' config/portage/package.use/10-d630-hardware
grep -Fxq 'x11-base/xorg-drivers' config/package.list

test -s config/package-sets/runner-tools.list
test -s config/package-sets/cli.list
test -s config/package-sets/tiny-console.list
test -s config/portage/package.use/50-tiny-console
test -s config/package-sets/development.list
test -s config/package-sets/desktop.list
test -s config/package-sets/multimedia.list
test -s config/package-sets/daily-driver.list
test -s scripts/gentoo-build-set
test -s .github/workflows/gentoo-interactive-build.yml
test -s .github/workflows/publish-gentoo-binpkgs.yml
test -s scripts/package-binpkgs-release.sh
test -s scripts/install-binpkgs-release.sh
test -s scripts/snapshot-gentoo-session.sh
test -s scripts/save-runner-state-encrypted.sh
! test -e scripts/publish-pending-state-save.sh
test -s scripts/build-squashfs.sh
test -s scripts/build-squashfs-inplace.sh
test -s scripts/build-state-squashfs.sh
test -s .github/workflows/build-d630-state-boot-bundle.yml
grep -Fq 'workflow_call:' .github/workflows/build-d630-kernel.yml
bash -n scripts/build-squashfs-inplace.sh
bash -n scripts/build-state-squashfs.sh
test -s scripts/build-runtime-squashfs.sh
test -s scripts/install-runtime-dotfiles.sh
bash -n scripts/install-runtime-dotfiles.sh
grep -Fq 'app-misc/tealdeer' config/package-sets/cli.list
grep -Fq 'app-editors/neovim' config/package-sets/cli.list
grep -Fq 'sys-process/htop' config/package-sets/cli.list
grep -Fq 'grep -vx '\''sys-apps/man-db'\''' scripts/build-runtime-squashfs.sh
grep -Fq 'sys-apps\\/man-db$/d' scripts/build-runtime-squashfs.sh
grep -Fq 'command_args="--autologin gentoo --noclear tty1 linux"' scripts/build-runtime-squashfs.sh
grep -Fq 'NOPASSWD: ALL' scripts/build-runtime-squashfs.sh
grep -Fq '6da2f0e0e8b90d61ac3f37e9c3b832edaddf7298' scripts/install-runtime-dotfiles.sh
grep -Fq 'Removing manuals, documentation trees, locale sources, and unused translations.' scripts/build-squashfs.sh
grep -Fq 'Required runtime application is absent from the final SquashFS' scripts/build-squashfs.sh
grep -Fq 'if [[ "$RUNTIME_PROFILE" == openbox || "$RUNTIME_PROFILE" == desktop || "$RUNTIME_PROFILE" == daily-driver || "$RUNTIME_PROFILE" == gui-initram ]]; then' scripts/build-runtime-squashfs.sh
grep -Fq 'Install Mesa from an imported binary package only' scripts/build-runtime-squashfs.sh
grep -Fq 'the openbox SquashFS profile requires an imported binary-package release containing Mesa' scripts/build-runtime-squashfs.sh
grep -Fq 'RUNTIME_ATOMS="$(awk '\''$0 != "media-libs/mesa"'\''' scripts/build-runtime-squashfs.sh
grep -Fq -- '--getbinpkg --usepkgonly --onlydeps' scripts/build-runtime-squashfs.sh
grep -Fq -- '--getbinpkg=n --usepkgonly' scripts/build-runtime-squashfs.sh
grep -Fq 'chown "0:$PORTAGE_GID" "$ROOT/var/tmp/portage"' scripts/build-runtime-squashfs.sh
grep -Fq 'command -v usermod && command -v openssl && command -v visudo' scripts/build-runtime-squashfs.sh
grep -Fq 'useradd -M -U -u 1000 -s /bin/bash gentoo' config/runtime/d630-firstboot
grep -Fq 'awk -F: '\''$1 != "gentoo" { print $1 }'\'' /etc/group | paste -sd, -' config/runtime/d630-firstboot
grep -Fq 's0:12345:respawn:/sbin/agetty -L 115200 ttyS0 vt100' scripts/build-runtime-squashfs.sh
grep -Fq "rc-update del netmount default" scripts/build-runtime-squashfs.sh
grep -Fq 'install -m 0755 "$GITHUB_WORKSPACE/config/runtime/d630-firstboot"' scripts/build-runtime-squashfs.sh
grep -Fq 'find "$stage" -xdev -uid 1000 -exec chown -h 0 {} +' scripts/build-squashfs.sh
grep -Fq 'chown 0:0 "$stage/var"' scripts/build-squashfs.sh
grep -Fq 'chroot "$ROOT" chmod 4755 /usr/bin/sudo' scripts/build-runtime-squashfs.sh
grep -Fq 'chmod 0755 "$ROOT/etc/sudoers.d"' scripts/build-runtime-squashfs.sh
grep -Fq 'chown -R gentoo:gentoo /home/gentoo' config/runtime/d630-firstboot
grep -Fq 'openssl passwd -6 gentoo' config/runtime/d630-firstboot
grep -Fq 'find "$ROOT" -xdev -uid 1000 -exec chown -h 0 {} +' scripts/build-state-squashfs.sh
grep -Fq 'umask 0002; export LC_ALL=C; source /etc/portage/make.conf; export FEATURES=' scripts/build-runtime-squashfs.sh
grep -Fq '\${FEATURES} -userpriv' scripts/build-runtime-squashfs.sh
grep -Fq 'the installed Mesa binpkg has USE=llvm' scripts/build-runtime-squashfs.sh

test -s scripts/build-runtime-squashfs-local.sh
test -s .github/workflows/build-d630-runtime-squashfs.yml
grep -Fq 'contents: write' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'softprops/action-gh-release@v3' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'eselect repository enable guru' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'emaint sync -r guru' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'config/portage/package.accept_keywords/. "$root/etc/portage/package.accept_keywords/"' .github/workflows/gentoo-interactive-build.yml
grep -Fq 'uses: actions/upload-artifact@v4' .github/workflows/publish-gentoo-binpkgs.yml
grep -Fq 'name: Prepare existing Gentoo assets for SquashFS build' .github/workflows/publish-gentoo-binpkgs.yml
grep -Fq 'name: Download recovered Gentoo assets artifact' .github/workflows/build-d630-runtime-squashfs.yml
grep -Fq 'LOCAL_RELEASE_ASSETS_DIR' scripts/build-runtime-squashfs.sh
grep -Fq 'LOCAL_BINPKG_ARCHIVE' scripts/build-runtime-squashfs.sh
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
grep -q 'x11-base/xorg-server' config/package.list
grep -q 'x11-wm/openbox' config/package.list
grep -qi 'squashfs' config/kernel-notes.md
grep -q 'CONFIG_OVERLAY_FS=y' config/kernel-notes.md
grep -q 'CONFIG_BLK_DEV_LOOP=y' config/kernel-notes.md
grep -q 'd630.persistence=auto' iso/boot/grub/loopback.cfg
grep -q 'd630.persistence=volatile' iso/boot/grub/loopback.cfg
sh -n initramfs/init
sh -n scripts/create-persistence-image.sh
sh -n tinyos/init tinyos/wifi-connect
bash -n tinyos/export-wifi-profile.sh tinyos/build-setup-tools.sh tinyos/build-initramfs.sh
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
bash -n scripts/build-squashfs.sh
bash -n scripts/build-runtime-squashfs.sh
bash -n scripts/build-runtime-squashfs-local.sh
grep -Fq 'du -shx "$src" "$output"' scripts/build-squashfs.sh
grep -Fq 'usr/bin/init($| ->)' scripts/build-runtime-squashfs.sh
grep -Fq "MINIMAL_RUNTIME=true bash" scripts/build-runtime-squashfs.sh
grep -Fq -- "--exclude='/var/cache/***'" scripts/build-squashfs.sh
grep -Fq 'Removing Portage, language runtimes, development tools, and compiler binaries.' scripts/build-squashfs.sh
grep -Fq 'remove_package_payload sys-devel/gcc true' scripts/build-squashfs.sh
grep -Fq '"$stage/var/db/pkg"' scripts/build-squashfs.sh
grep -Fq 'rm -f "$stage/usr/bin"/{g-ir-*,eu-*,sqlite3,python*,perl*}' scripts/build-squashfs.sh
grep -Fq 'ln -s ../usr/lib/netifrc "$stage/lib/netifrc"' scripts/build-squashfs.sh
grep -Fq 'LLVM/Clang package records are present in the input root' scripts/build-squashfs.sh
grep -Fq 'dev-(build|lang|python|util)' scripts/build-runtime-squashfs.sh
grep -Fq 'LOCAL_BINPKG_ARCHIVE' scripts/build-runtime-squashfs.sh
grep -Fq 'OUTPUT_DIR' scripts/build-runtime-squashfs.sh
grep -Fq -- "--getbinpkg --usepkgonly" scripts/build-runtime-squashfs.sh
grep -Fq "net-wireless/wireless-regdb" scripts/build-runtime-squashfs.sh
grep -Fq -- '--ignore-default-opts --ask=n --verbose' scripts/gentoo-build-set
grep -Fq "emerge --ignore-default-opts --sync --quiet" .github/workflows/gentoo-interactive-build.yml
grep -q 'rootfs.squashfs' iso/boot/grub/loopback.cfg
grep -q 'gentoo-data.img' iso/boot/grub/loopback.cfg
! grep -q '@SHELL@' config/package-sets/daily-driver.list

test -s grub2/d630-gentoo.cfg
grep -Fq 'd630-gentoo/kernel' grub2/d630-gentoo.cfg
grep -Fq 'd630-gentoo/initramfs' grub2/d630-gentoo.cfg
! grep -Fq 'd630.boot_uuid=$d630_boot_uuid' grub2/d630-gentoo.cfg
grep -Fq '/d630-gentoo/squashfs' initramfs/init
! grep -Fq '$(blkid' initramfs/init

test -s config/kernel/d630-base.fragment
test -s config/kernel/d630-live.fragment
grep -Fq 'CONFIG_X86_64=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_BLK_DEV_INITRD=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_OVERLAY_FS=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_SQUASHFS_ZSTD=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_NTFS3_FS=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_IWL3945=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_USB_NET_RNDIS_HOST=y' config/kernel/d630-live.fragment
grep -Fq 'CONFIG_BT=y' config/kernel/d630-live.fragment

test -s scripts/validate-kernel-config.sh
bash scripts/validate-kernel-config.sh
echo "d630-gentoo source scaffold: validation passed"
