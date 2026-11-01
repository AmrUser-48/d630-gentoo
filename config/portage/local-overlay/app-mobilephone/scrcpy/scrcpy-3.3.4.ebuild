# D630 scrcpy 3.3.4 fork: SDL2 client and matching keyboard-gamepad server.
# The client is built against Gentoo's system SDL2/FFmpeg; only the server is prebuilt.
EAPI=8

inherit meson xdg

D630_SCRCPY_COMMIT="bd32f66b224e5fcac9fed3da98700f4e6c523e84"
D630_RELEASE_TAG="v3.3.4-debian12-core2-keyboard-gamepad"
D630_SERVER_ARCHIVE="scrcpy-3.3.4-debian12-core2-keyboard-gamepad-x86_64.tar.gz"

DESCRIPTION="Display and control Android devices (D630 SDL2 keyboard-gamepad fork)"
HOMEPAGE="https://github.com/AmrUser-48/scrcpy"
SRC_URI="
  https://github.com/AmrUser-48/scrcpy/archive/${D630_SCRCPY_COMMIT}.tar.gz -> ${P}.tar.gz
  https://github.com/AmrUser-48/scrcpy/releases/download/${D630_RELEASE_TAG}/${D630_SERVER_ARCHIVE} -> ${P}-server-bundle.tar.gz
"
S="${WORKDIR}/${PN}-${D630_SCRCPY_COMMIT}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="X wayland"

DEPEND="
  media-libs/libsdl2[X?,wayland?]
  media-video/ffmpeg:=
  virtual/libusb:1
"
RDEPEND="
  ${DEPEND}
  dev-util/android-tools
"

DOCS=( {FAQ,README}.md doc/. )

src_prepare() {
  default
  rm doc/{build,develop,macos,windows}.md || die
}

src_configure() {
  local server_path
  server_path="$(find "${WORKDIR}" -type f -name scrcpy-server -print -quit)"
  [[ -s "${server_path}" ]] || die "matching pinned scrcpy-server is missing"
  local emesonargs=(
    -Dprebuilt_server="${server_path}"
  )
  meson_src_configure
}
