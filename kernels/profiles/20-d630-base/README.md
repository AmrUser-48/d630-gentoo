# Profile 20 — Debian D630 Reference Inventory

## Purpose

This page collects text-only evidence from the Debian installation running on the physical Dell Latitude D630. Use it to refine [the Profile 20 Gentoo base-kernel overlay](../20-d630-base.config).

Profile 20 is the conventional installed Gentoo kernel. It retains Gentoo's standard distribution-kernel coverage and uses modules for D630 device drivers wherever Kconfig permits. This inventory is evidence about the laptop, not a replacement for Gentoo's distribution baseline.

Do not upload or copy module binaries (.ko), firmware blobs, initramfs images, or whole system directories. Paste command output only.

## Collect the information

Run these commands on Debian and paste their output into the matching sections below.

### System and root filesystem

~~~bash
cat /etc/debian_version
uname -a
lscpu
findmnt -no SOURCE,FSTYPE,OPTIONS /
~~~

### Active kernel configuration

Prefer the configuration exported by the running kernel; fall back to Debian's installed config:

~~~bash
zcat /proc/config.gz 2>/dev/null || cat "/boot/config-$(uname -r)"
~~~

Paste the complete output. It is the main reference for available kernel options and the configuration actually running on Debian.

### PCI devices and bound drivers

~~~bash
lspci -nnk
~~~

### USB devices

~~~bash
lsusb
~~~

### Loaded modules

~~~bash
lsmod
~~~

This is a runtime snapshot only. A module absent from lsmod may still be available, built into the kernel, or needed by hardware that was not active during the snapshot.

### Installed module filenames

This lists names and paths only; it does not read or copy module contents.

~~~bash
find "/lib/modules/$(uname -r)" -type f -name '*.ko*' -printf '%P\n' | sort
~~~

### Firmware filenames and requests

The first command lists firmware paths only. The second shows firmware requests recorded by the running kernel.

~~~bash
find /lib/firmware -type f -printf '%P\n' | sort
dmesg | grep -i firmware
~~~

### Optional device state

~~~bash
rfkill list
~~~

## Collected data

### Debian and running kernel

Paste the output of the system and root-filesystem commands here.

### Running kernel configuration

Paste the complete configuration here.

### PCI inventory

Paste the complete lspci -nnk output here.

### USB inventory

Paste the lsusb output here.

### Loaded modules — already received

The supplied lsmod snapshot confirms these D630-related drivers and stacks:

| Function | Observed modules |
|---|---|
| Graphics | i915, drm, drm_kms_helper, drm_display_helper, drm_buddy, ttm, i2c_algo_bit |
| Intel 3945ABG Wi-Fi | iwl3945, iwlegacy, mac80211, cfg80211, libarc4 |
| HDA audio / IDT codec | snd_hda_intel, snd_hda_codec_idt, snd_hda_codec_generic, snd_hda_codec, snd_hda_core, snd_pcm, snd_timer |
| USB 2.0 | usbcore, ehci_hcd, ehci_pci, uhci_hcd, usbhid, hid, hid_generic |
| SATA / ATA / SCSI | ahci, libahci, ata_piix, ata_generic, libata, scsi_mod, scsi_common, sd_mod |
| Keyboard and pointing devices | psmouse, evdev, serio_raw, uinput, joydev |
| Dell platform | dell_laptop, dell_wmi, dell_smbios, dell_smm_hwmon, dell_wmi_descriptor, dcdbas, video, wmi |
| ACPI, frequency and sensors | acpi_cpufreq, battery, ac, coretemp, i2c_i801, i2c_smbus, lpc_ich, button |

The same snapshot also shows general-purpose facilities in use, including nftables/netfilter, tun, KVM, loop, device mapper, FUSE, configfs and crypto modules. Preserve these according to the intended Gentoo system feature set; they are not D630-specific hardware drivers.

### Installed module filenames

Paste the output of the module-filename command here.

### Firmware filenames

Paste the output of the firmware-filename command here.

### Firmware requests from dmesg

Paste the output of dmesg | grep -i firmware here. An empty result is valid.

### Additional notes

Record optional hardware, devices tested only occasionally, driver problems, or hardware that was disconnected during collection. Distinguish confirmed hardware from devices merely supported by the generic Gentoo baseline.

## How this inventory is used

1. Match PCI and USB device IDs to their bound drivers.
2. Compare the Debian running config with the installed module inventory and loaded-module snapshot.
3. Identify firmware required by the D630 and keep firmware payloads separate from kernel configuration.
4. Update Profile 20 only for verified D630 requirements. Keep Gentoo's unrelated distribution-kernel coverage intact.
5. Resolve the fragment against the actual Gentoo kernel source and inspect the resulting .config. A requested =m or =y in a fragment is not proof that Kconfig retained it.
