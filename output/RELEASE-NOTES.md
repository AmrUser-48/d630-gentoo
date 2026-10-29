D630 Gentoo runtime SquashFS — profile openbox

Place the release asset **squashfs** at **/d630-gentoo/squashfs**. Use the matching kernel bundle `d630-kernel-6.18.56-run-40813428910` for **/d630-gentoo/kernel** and **/d630-gentoo/initramfs**. This kernel also suppresses the x86 decompressor progress banner.

The focused runtime omits Portage, package metadata, Python/Perl, development tools, and compiler binaries. Versioned GCC runtime libraries are retained; LLVM and Clang are absent.

This live image uses a volatile RAM OverlayFS. Changes are lost on reboot. Every boot creates or refreshes the local **gentoo** account, assigns it to all system groups, and resets its password to **gentoo**. The account can use `sudo`; log in with `gentoo` / `gentoo`. The serial console is enabled for QEMU and headless recovery. This fixed test password is intended for local live-media testing, not network-exposed use.

The kernel and initramfs are separate deliverables. Supply their release tag to kernel_bundle_tag to add matching modules and firmware.
