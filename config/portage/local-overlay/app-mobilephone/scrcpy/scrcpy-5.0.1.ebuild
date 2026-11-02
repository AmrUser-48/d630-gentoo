# scrcpy 5.0.1 with the D630 keyboard-to-gamepad (-j) extension.
# Client is built against Gentoo system SDL3/FFmpeg; upstream matching server is prebuilt.
EAPI=8

inherit meson xdg

D630_SCRCPY_COMMIT="8b2ac5512d4301218cf8b458aaf1f74b9d35d82f"

DESCRIPTION="Display and control Android devices (D630 SDL3 keyboard-gamepad fork)"
HOMEPAGE="https://github.com/AmrUser-48/scrcpy"
SRC_URI="
  https://github.com/AmrUser-48/scrcpy/archive/${D630_SCRCPY_COMMIT}.tar.gz -> ${P}.tar.gz
  https://github.com/Genymobile/scrcpy/releases/download/v${PV}/scrcpy-server-v${PV} -> ${P}-server
"
S="${WORKDIR}/${PN}-${D630_SCRCPY_COMMIT}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="X wayland"

DEPEND="
  media-libs/libsdl3[X?,wayland?]
  media-video/ffmpeg:=
  virtual/libusb:1
"
RDEPEND="
  ${DEPEND}
  dev-util/android-tools
"

DOCS=( README.md doc/. )

src_unpack() {
  unpack "${P}.tar.gz"
  cp "${DISTDIR}/${P}-server" "${WORKDIR}/${P}-server" || die
}

src_prepare() {
  default
  rm -f doc/{build,develop,macos,windows}.md
}

src_configure() {
  local server_path="${WORKDIR}/${P}-server"
  [[ -s "${server_path}" ]] || die "matching pinned scrcpy-server is missing"

  local emesonargs=(
    -Dprebuilt_server="${server_path}"
    -Dvaapi=false
  )
  meson_src_configure
}
