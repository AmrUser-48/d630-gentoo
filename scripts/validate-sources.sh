#!/bin/sh
set -eu

test -s README.md
test -s config/package.list
test -s config/make.conf
test -s config/kernel-notes.md

grep -q 'march=core2' config/make.conf
grep -q 'x11-base/xorg-server' config/package.list
grep -q 'x11-wm/openbox' config/package.list
grep -q 'SquashFS' config/kernel-notes.md

echo "d630-gentoo source scaffold: validation passed"
