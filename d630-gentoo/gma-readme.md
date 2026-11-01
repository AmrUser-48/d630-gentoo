# Dell D630 GM965 / GMA X3100 graphics notes

Target: Dell Latitude D630, Intel Mobile GM965 (Crestline), GMA X3100, PCI VGA function `8086:2a02` (rev `0c`), secondary display function `8086:2a03`, Dell subsystem `1028:01f9`. Kernel driver: `i915`. CPU: Core 2 Duo T7250.

This guide records the known hardware, the Gentoo project policy, the historical Intel/Xorg/Mesa stack, and the diagnostics collected on the physical D630. It is not a claim that every optional path below has passed a physical-hardware test.

## 1. Graphics stack: keep the layers separate

| Layer | Component | Role |
|---|---|---|
| Kernel | `i915` DRM/KMS | PCI binding, modesetting, GEM memory management, GPU submission, DRM nodes |
| DRM userspace | `libdrm`, `libdrm_intel` | Userspace access to kernel DRM interfaces |
| Xorg DDX | `modesetting` or `intel` | X server display and 2D acceleration driver |
| Mesa | `crocus` or legacy `i965` | OpenGL implementation and DRI rendering driver |
| DRI protocol | DRI2 / DRI3 | X server/client buffer sharing and synchronization; not a GPU driver |
| Media API | VA-API / XvMC | Separate video decode interfaces; neither is required for OpenGL |
| Application | Chromium, FFmpeg, player | Chooses its own decode, upload and rendering paths |

Important distinctions:

- Kernel `i915` is not Gentoo's `VIDEO_CARDS=i915` flag.
- Xorg DDX `intel` is not Mesa's `i965` driver.
- DRI3 is not a codec and does not enable H.264 decoding.
- `i965_dri.so` (Mesa OpenGL) is not `i965_drv_video.so` (Intel VA-API).
- A loaded kernel module or advertised X extension does not prove that an application is using the corresponding acceleration path.

## 2. Hardware capability boundary

GM965 is **Gen4 / Crestline**, not GM45 (Gen4.5 / Cantiga).

| Capability | GM965 / X3100 |
|---|---|
| Kernel DRM/KMS | Supported by `i915` |
| OpenGL | Legacy Intel Gen4; physical D630 baseline observed at OpenGL 2.1 |
| Mesa Gallium driver | Crocus supports Gen4 through Gen7; validate on this device |
| Vulkan | No native Intel Vulkan driver for this GPU |
| VA-API | The current Intel `i965` VA driver does not list GM965 |
| H.264 fixed-function decode | No dedicated GM965 H.264 decoder |
| Older media blocks | Intel platform has older MPEG-2 / WMV9-era video functionality; Linux userspace exposure is limited and must be tested per API |
| XvMC | Legacy XvMC path is present in the Intel Xorg DDX; initialization alone does not prove a working hardware decode |

Do not confuse GM965 with GM45. Intel's legacy VA driver README identifies CTG / Cantiga (GMA 4500MHD, GM45) as the first supported VA-API platform for MPEG-2 decode; H.264 decode begins at Ironlake (Gen5). It does not list GM965 / Crestline.

The practical D630 browser case is therefore:
- H.264 MP4 decoding can work in software on the T7250.
- GPU compositing, rasterization and WebGL can still be hardware accelerated.
- Video decode and video presentation are separate. DRI3 or Mesa changes may improve buffer sharing/presentation, but cannot add an H.264 decoder to GM965.

## 3. Gentoo project policy

The current project default is **Xorg modesetting DDX + Mesa Crocus**. The legacy `xf86-video-intel` DDX is retained only as an explicit A/B test.

Relevant files:

- `d630-gentoo/config/xorg/README.md`
- `d630-gentoo/config/xorg/profiles/modesetting/10-d630-modesetting.conf.example`
- `d630-gentoo/config/xorg/profiles/intel-ddx/20-d630-intel-ddx.conf.example`
- `d630-gentoo/config/xorg/99-synaptics.conf`
- `docs/hardware-inventory.md`

### Gentoo selection

Use the repository's existing baseline:

```bash
VIDEO_CARDS="intel"
```

For Gen4+, the project selects the built-in Xorg `modesetting` DDX and the Intel Mesa path. Do not add `VIDEO_CARDS=i915` just because the kernel module is named `i915`: Gentoo's `video_cards_i915` flag selects the legacy Xorg Intel DDX package family. Keep package/USE choices aligned with the current ebuilds; inspect them before changing the profile:

```bash
emerge -pv x11-base/xorg-server x11-base/xorg-drivers media-libs/mesa
emerge --info | grep -E 'VIDEO_CARDS|INPUT_DEVICES|USE='
```

The Mesa build must contain the Crocus Gallium driver. Do not assume that a successful Mesa package build included Crocus: inspect the build options and installed DRI module.

### Recommended DDX: modesetting + glamor

Xorg normally auto-detects the built-in `modesetting` DDX. No custom Device section is normally required. The repository's optional diagnostic profile is:

```conf
Section "Device"
    Identifier "D630 Intel GM965 modesetting"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
EndSection
```

This is the preferred Gentoo starting point. Do not combine it with the Intel DDX Device section. The `AccelMethod` option above belongs to the modesetting driver; it is not SNA/UXA.

### Optional A/B test: legacy Intel DDX

The separate `x11-drivers/xf86-video-intel` DDX can be tested with:

```conf
Section "Device"
    Identifier "D630 Intel GM965 legacy DDX"
    Driver "intel"
    Option "AccelMethod" "sna"
EndSection
```

SNA is the modern acceleration architecture in this legacy DDX. UXA is its older alternative. Test UXA only as a controlled fallback if SNA shows a reproducible fault; do not enable both. Avoid hard-coded `BusID` unless the machine actually has multiple active display GPUs. Do not enable `TearFree` by default: it can consume additional memory and change performance/latency.

The Gentoo package's `video_cards_i915` setting is used to pull in this optional legacy DDX. The project's default `VIDEO_CARDS=intel` deliberately does not request it.

## 4. DRI2 and DRI3

DRI is the direct-rendering client/server infrastructure. DRI2 and DRI3 are protocol generations, not Mesa driver names.

- DRI2 shares buffers through the older X server/DRM path.
- DRI3 passes file descriptors for buffers/fences and is commonly used with Present for more efficient client/server buffer sharing.
- DRI3 can help buffer transport and presentation. It does not guarantee zero-copy video, hardware decode, or support for every buffer format.
- The Xorg server can advertise the DRI3 extension even when the active DDX does not establish a DRI3 rendering path.

### Critical diagnostic distinction

`xdpyinfo -queryExtensions | grep -i DRI3` proves only that the X server advertises the protocol extension. It does **not** prove that the selected DDX negotiated DRI3 for clients.

For `xf86-video-intel`, Debian's source package has DRI3 compiled in, but its packaged build defaults to maximum DRI level 2. Its Meson options show `dri3=true` and `default-dri=2`. Thus “DRI3 code compiled” and “DRI3 selected at runtime” are different facts.

For the legacy Intel DDX, test DRI3 explicitly (one change at a time):

```conf
Section "Device"
    Identifier "D630 Intel GM965 legacy DDX"
    Driver "intel"
    Option "AccelMethod" "sna"
    Option "DRI" "3"
EndSection
```

This is an A/B test, not the Gentoo default. If Xorg fails to start or rendering regresses, remove the test file or revert the changed option. The Intel DDX `DRI` option is overloaded: a boolean enables/disables direct rendering; a Mesa driver name (for example `crocus`) selects the DRI driver; a numeric value (`1`, `2` or `3`) sets the maximum DRI protocol level. These are different modes, not interchangeable settings. For the Gen4–Gen7.5 Crocus selection, Gentoo documents `Option "DRI" "crocus"`; for an explicit DRI3 protocol test use `Option "DRI" "3"`. Test only one variable at a time.

A 2023 upstream change explicitly enabled DRI3 on Gen2/Gen3 SNA paths. GM965 is Gen4, so that particular Gen2/3 limitation is not the explanation for this machine. Debian Bookworm's `xf86-video-intel` source snapshot is from 2021 and predates that change, but the patch was specifically for Gen2/3.

For the built-in `modesetting` DDX, let Xorg/Mesa negotiate normally first. If explicitly testing DRI3, the modesetting/glamor configuration can use `Option "DRI" "3"`; remove it again if it changes stability or breaks startup. Do not copy the Intel DDX-specific Mesa backend selector (`Option "DRI" "crocus"`) unless the active DDX documents and honors it. Use `LIBGL_DRI3_DISABLE=1` only as a temporary client-side A/B diagnostic.

### DRI3 test sequence

After restarting the display manager (which ends the desktop session):

```bash
# Server protocol extension (not sufficient by itself)
xdpyinfo -queryExtensions | grep -i DRI3

# Active DDX, acceleration backend and DRI setup
grep -iE 'intel\\(0\\)|modeset|glamor|SNA|UXA|DRI[23]|AIGLX' /var/log/Xorg.0.log

# Mesa client renderer and direct-rendering status
LIBGL_DEBUG=verbose glxinfo -B 2>&1

# A/B test the Mesa client's DRI3 path without changing Xorg configuration
LIBGL_DRI3_DISABLE=1 glxinfo -B
```

Compare the renderer and stability with and without the environment variable. Do not leave the override globally set unless a reproducible issue requires it.

## 5. Mesa: i965 versus Crocus

| Mesa driver | Architecture | Status |
|---|---|---|
| `i965` classic DRI | Intel Gen4 and later (including GM965) | Legacy classic driver; moved to Mesa Amber after Mesa 21.3 |
| `crocus` Gallium | Intel Gen4 through Gen7 | Main Mesa path for GM965-era Intel hardware |
| `iris` Gallium | Gen8 and newer | Not for GM965 |
| `i915` classic DRI / `i915g` | Older Gen2/Gen3 families | Not the GM965 graphics driver |
| `llvmpipe` / `softpipe` | CPU software rasterizers | Fallback/testing, not hardware acceleration |

Crocus first appeared as an initial Gallium driver for Intel gfx4–7 in Mesa 21.2. It is the preferred current Mesa path to test on GM965. Mesa's Amber branch retains classic `i965` and other non-Gallium DRI drivers for critical fixes; it is not the preferred long-term feature path.

The DRI module must exist in the loader's actual DRI directory. Common names:

- Crocus: `crocus_dri.so`
- Classic i965: `i965_dri.so`

Check the real installation instead of assuming a package installed the expected module:

```bash
pkg-config --variable=dridriverdir dri
find /usr/lib /usr/lib64 -type f \\( -name crocus_dri.so -o -name i965_dri.so \\) 2>/dev/null
LIBGL_DEBUG=verbose glxinfo -B
```

Do not mix `libEGL`, `libGL`, `libgbm`, `libdrm` and DRI modules from different Mesa builds. A private Mesa test should use one matching prefix and a process-local loader path; do not globally replace system graphics libraries during diagnosis.

### Xorg GLX error versus Chromium ANGLE

A physical Debian session produced this Xorg log:

```text
[XvMC] i965_xvmc driver initialized.
[DRI2] Setup complete
[DRI2] DRI driver: i965
AIGLX error: ... /usr/lib/x86_64-linux-gnu/dri/i965_dri.so:
    cannot open shared object file
GLX: Initialized DRISWRAST GL provider
```

A separate Chromium 115 `chrome://gpu` report showed:

```text
GL_RENDERER: ANGLE (Intel, Mesa Intel(R) 965GM (CL), OpenGL 2.1 Mesa 22.3.6)
Canvas: Hardware accelerated
Compositing: Hardware accelerated
Rasterization: Hardware accelerated
WebGL / WebGL2: Hardware accelerated
ANGLE: egl-angle, angle=opengl
```

These observations must not be collapsed into one conclusion. The AIGLX message concerns Xorg's GLX provider loading `i965_dri.so`; Chromium's ANGLE/EGL context is a separate client path and reported an Intel renderer. Re-run `glxinfo -B` and Chromium's GPU page after each Mesa/DDX change to determine which path is active now.

## 6. Xorg / kernel configuration

### Kernel

The project kernel profile should retain:

- `CONFIG_DRM=y`
- `CONFIG_DRM_I915=y` for the built-in Gentoo live profile
- KMS and framebuffer-console support
- required AGP support where selected by kernel dependencies

The physical Debian machine currently binds `8086:2a02` to `i915`. Kernel `i915` is the correct DRM driver for this Gen4 chipset. Do not add modern Intel `xe`, GuC/HuC firmware, AMD or NVIDIA drivers for GM965.

### Device nodes and permissions

Typical nodes:

- `/dev/dri/card0`: primary DRM device, usually `root:video`
- `/dev/dri/renderD128`: render node, usually `root:render`

Inspect permissions before changing groups:

```bash
ls -l /dev/dri
id
getent group video
getent group render
```

If a user process genuinely needs direct render-node access and the node is `root:render`, add the user to the render group, then fully log out and back in:

```bash
sudo usermod -aG render "$USER"
```

Group membership is not retroactive to an existing desktop session. A missing `getfacl` utility is not a graphics-driver problem; it is not required for these checks.

### Xorg configuration and restart

- Prefer no global Device section when Xorg auto-detects the single GM965.
- Keep the modesetting and legacy Intel DDX profiles mutually exclusive.
- Do not add a fixed panel/output name (for example `LVDS1`) without checking `xrandr --query`.
- Restart the display manager to apply a changed Xorg configuration; this terminates the current graphical session. Keep SSH available for recovery.

Useful inspection:

```bash
xrandr --query
xdpyinfo -queryExtensions | grep -iE 'DRI|XVideo'
grep -iE '\\(EE\\)|\\(WW\\)|intel|modeset|DRI|AIGLX|glamor|SNA|UXA' /var/log/Xorg.0.log
```

## 7. Video APIs: VA-API, XvMC and browser playback

### VA-API

The two common Intel VA drivers are not interchangeable:

| Driver | Intended hardware |
|---|---|
| `i965_drv_video.so` | Legacy Intel VA-API driver, documented for G45/GM45 (GMA X4500MHD) and newer supported platforms; not GM965 |
| `iHD_drv_video.so` | Intel Media Driver for newer platforms; not GM965 |

The D630 test returned:

```text
Trying to open iHD_drv_video.so       -> failed
Trying to open i965_drv_video.so      -> init failed
vaInitialize failed
```

The same failure occurred when explicitly selecting `LIBVA_DRIVER_NAME=i965` on `/dev/dri/renderD128`. FFmpeg had VA-API and QSV support compiled in, but its VA-API device initialization failed. A compiled FFmpeg encoder/decoder does not imply that the physical GPU and driver support it.

### XvMC

The physical Debian Xorg log reports:

```text
[XvMC] i965_xvmc driver initialized.
```

Installed libraries included `libIntelXvMC.so.1`, `libXvMC.so.1` and `libXvMCW.so.1`; the X server advertised `XVideo-MotionCompensation`. The tested `/etc/X11/XvMCConfig` was set to:

```text
/usr/lib/x86_64-linux-gnu/libIntelXvMC.so.1
```

This confirms that the legacy XvMC interface is present and the Intel DDX initialized its XvMC component. It does **not** prove that an MPEG-2 sample decoded successfully in hardware. XvMC is an old X11-era API for legacy codecs; it is not the browser's modern H.264 MP4 decode path and is not a Gentoo build priority.

### Browser and media diagnostics

Use both pages because graphics rendering and media decoding are distinct:

- `chrome://gpu`: GL renderer, compositing, rasterization, GPU process and workarounds.
- `chrome://media-internals`: selected audio/video decoder for the active player.

For a video player, `FFmpegVideoDecoder` with `kIsPlatformVideoDecoder=false` means software video decode. It does not mean GPU compositing is disabled. A `chrome://gpu` line saying “Video Decode: Hardware accelerated” is not proof that a particular playback used a platform decoder; inspect that player's media-internals record.

The D630 sample MP4 test selected `FFmpegVideoDecoder` for H.264 and `FFmpegAudioDecoder` for AAC. Browser GPU compositing/WebGL were independently hardware accelerated through ANGLE/OpenGL.

## 8. Historical driver and distribution matrix

This table is a source/version map for reproducing legacy combinations, not a recommendation to run an obsolete distribution online.

### Debian's packaged `xf86-video-intel` history

| Debian release | Package version |
|---|---|
| Lenny | `2.3.2-2+lenny8` |
| Squeeze | `2.13.0-7` |
| Wheezy | `2.19.0-6` |
| Jessie | `2.21.15-2` |
| Stretch | `2.99.917+git20161206-1` |
| Buster | `2.99.917+git20180925-2` |
| Bullseye | `2.99.917+git20200714-1+deb11u1` |
| Bookworm | `2.99.917+git20210115-1` |

Debian's source archive lists these package versions. The Bookworm source snapshot builds DRI3 support but sets the default maximum DRI level to 2. Inspect the distribution's actual source package/build options before assuming the runtime default.

### Upstream Intel DDX milestones

| Period / release | Change |
|---|---|
| 2007–2008, 2.1–2.4 series | Early 965-era Xorg driver; classic Mesa `i965` and kernel `i915` stack |
| 2009, `xf86-video-intel 2.8.0` | X server 1.6+; removed XAA/EXA and DRI1 in favor of UXA/DRI2; required recent i915 KMS; added MPEG-2 VLD support to XvMC |
| 2009–2010, 2.9–2.13 | KMS/DRI2-era Intel DDX used by Lenny/Squeeze-era systems |
| 2012, 2.19 / 2.21 | Mature legacy DDX generation used by Wheezy/Jessie |
| 2015 onward, 2.99.917 snapshots | SNA-era legacy DDX; DRI3/Present support depends on exact build options and source revision |
| 2023 upstream commit | SNA DRI3 enablement extended to Gen2/Gen3; not a GM965 Gen4 hardware-enablement patch |

### Mesa milestones

| Period | Driver stack |
|---|---|
| Gen4 launch / 2006 onward | Kernel `i915`, Mesa classic `i965` DRI, Intel Xorg DDX |
| 2009+ | GEM/KMS, libdrm-intel, DRI2; XvMC MPEG-2 VLD support on supported hardware |
| Mesa 21.2 | Initial Crocus Gallium driver for Intel gfx4–7 |
| After Mesa 21.3 | Non-Gallium `i965` moved to the Mesa Amber branch for critical fixes; Crocus is the mainline Gen4–7 path |

### Historical combinations worth testing in an isolated VM or disk image

- Debian Lenny/Squeeze: useful for the older 2.3 / 2.13 Intel DDX and early KMS/DRI2 behavior.
- Debian Wheezy/Jessie: useful for 2.19 / 2.21 DDX and later SNA/UXA-era comparison.
- Debian Stretch through Bookworm: useful for comparing later `2.99.917` source snapshots; Bookworm is not a “new” Intel DDX despite the newer Xorg server.
- Ubuntu 9.10 shipped around Intel DDX 2.9.0; Ubuntu 10.04-era 2.9.x provides another contemporary reference.

Use old distributions only to reproduce a specific driver/library combination. Do not transplant old Xorg modules, Mesa DRI modules or `libdrm` binaries into the current Gentoo root: ABI and library dependencies must match.

## 9. Physical D630 diagnostic bundle

Run after each graphics change and keep the outputs together with the DDX/Mesa versions:

```bash
# Device and kernel driver
lspci -nnk -s 00:02.0
lsmod | grep -E 'i915|drm'
dmesg | grep -iE 'i915|drm|gpu|firmware'

# DRM nodes and permissions
ls -l /dev/dri
id

# Xorg and GLX
grep -iE 'intel|modeset|DRI[23]|AIGLX|glamor|SNA|UXA|XvMC|error|failed' /var/log/Xorg.0.log
glxinfo -B
xrandr --query

# X extensions and Mesa module lookup
xdpyinfo -queryExtensions | grep -iE 'DRI|XVideo'
pkg-config --variable=dridriverdir dri
find /usr/lib /usr/lib64 -type f \\( -name crocus_dri.so -o -name i965_dri.so \\) 2>/dev/null

# VA-API (expected to fail on GM965 with the documented Intel drivers)
vainfo
```

Record separately:
1. Xorg DDX selected (`modesetting` or `intel`), acceleration backend and DRI level.
2. Mesa DRI driver file actually loaded and `GL_RENDERER`.
3. Chromium `chrome://gpu` and per-player `chrome://media-internals`.
4. VA-API initialization result.
5. Physical-hardware stability, VT switching, suspend/resume, external display and video playback.

Do not call a test “GPU accelerated” based only on the presence of `/dev/dri`, the Xorg DRI3 extension, FFmpeg's `-hwaccels` list, or a browser's generic video-decode feature status.

## 10. Primary references

- [Intel graphics architecture codenames: GM965 = Gen4 / Crestline](https://wiki.freedesktop.org/dri/IntelCodenames/)
- [Linux kernel i915 DRM documentation](https://docs.kernel.org/gpu/i915.html)
- [Mesa Crocus / supported systems](https://docs.mesa3d.org/systems.html)
- [Mesa Amber branch and i965 maintenance status](https://docs.mesa3d.org/amber.html)
- [Mesa 21.2 release notes: initial Crocus driver for gfx4–7](https://eric.pages.freedesktop.org/mesa/relnotes/21.2.0.html)
- [Intel legacy VA-API driver and supported platforms/codecs](https://github.com/intel/intel-vaapi-driver)
- [Intel VA-API platform capability table](https://www.intel.com/content/www/us/en/developer/articles/technical/linuxmedia-vaapi.html)
- [Intel GM965 Express Chipset datasheet](https://www.intel.com/Assets/PDF/datasheet/316273.pdf) — Clear Video feature table lists MPEG-2 and WMV9 acceleration.
- [Intel Blu-ray playback FAQ](https://www.intel.com/content/www/us/en/support/articles/000006968/graphics.html) — GM965 Blu-ray decode is software-accelerated; do not infer H.264 hardware decoding from the older Clear Video blocks.
- [xf86-video-intel 2.8.0 release notes](https://cgit.freedesktop.org/xorg/driver/xf86-video-intel/tree/NEWS)
- [xf86-video-intel man page](https://cgit.freedesktop.org/xorg/driver/xf86-video-intel/tree/man/intel.man)
- [Debian historical xf86-video-intel source versions](https://sources.debian.org/src/xserver-xorg-video-intel/)
- [Debian Bookworm xf86-video-intel Meson options](https://sources.debian.org/src/xserver-xorg-video-intel/2%3A2.99.917%2Bgit20210115-1/meson_options.txt)
- [Debian Bookworm xf86-video-intel DRI build configuration](https://sources.debian.org/src/xserver-xorg-video-intel/2%3A2.99.917%2Bgit20210115-1/configure.ac)
- [Upstream SNA DRI3 Gen2/3 change](https://gitlab.freedesktop.org/xorg/driver/xf86-video-intel/-/commit/2b552ed7d528d24b688b992a5164e062827d0ccb)
- [Gentoo Intel graphics guidance mirror](https://emirror.d0a.io/wiki/wiki.gentoo.org/wiki/Intel.html)
