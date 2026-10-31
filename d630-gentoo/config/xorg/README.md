# D630 Xorg configuration

The active D630 touchpad configuration is `99-synaptics.conf`. The remaining examples
below are deliberately not installed automatically.

## Graphics driver policy

Use Xorg's built-in `modesetting` DDX with Mesa Crocus as the default starting point for the
Intel GM965/GMA X3100. Do not force the legacy Intel DDX simply because the hardware is Intel.

- `profiles/modesetting/10-d630-modesetting.conf.example` is an explicit modesetting
  configuration for diagnostics. Normally Xorg auto-detects this driver without a Device
  section, so leave the example inactive unless you need to force it.
- `profiles/intel-ddx/20-d630-intel-ddx.conf.example` is an A/B test profile for the
  legacy `xf86-video-intel` driver. Copy it to `/etc/X11/xorg.conf.d/` only when testing
  that driver, then compare Xorg logs, rendering and stability against modesetting.

The current Portage target uses `VIDEO_CARDS="intel"`, which selects the built-in
modesetting path. Gentoo's Xorg driver meta-package uses the separate `i915` video-card
flag for `x11-drivers/xf86-video-intel`. Do not enable that flag in the default profile.

Neither example hardcodes `BusID`: the D630 normally has one active display GPU, and Xorg
can identify it. Avoid stale dual-GPU sections copied from a generated Debian `xorg.conf`.

## Input devices

The active `99-synaptics.conf` uses `MatchIsTouchpad` rather than assuming the exact ALPS
product string seen on one Debian installation. The separate deb12dots TrackPoint example
was not copied: its all-zero `TransformationMatrix` would collapse pointer coordinates.

Do not add fixed display output names such as `LVDS1` to global Xorg configuration or
Openbox startup. Query the current output with `xrandr --query` before adding optional
brightness or external-monitor rules.

## Validation

Inspect `/var/log/Xorg.0.log` (or the system journal), `xrandr --query`, and
`glxinfo -B`. Test both driver profiles separately; do not keep both Device sections
active at once. Physical D630 validation is still required.