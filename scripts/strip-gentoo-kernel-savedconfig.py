#!/usr/bin/env python3
"""Trim a Gentoo kernel savedconfig against the D630 Debian kernel inventory.

Usage:
  python3 scripts/strip-gentoo-kernel-savedconfig.py \
      /etc/portage/savedconfig/sys-kernel/gentoo-kernel-6.18.60
  python3 scripts/strip-gentoo-kernel-savedconfig.py \
      /etc/portage/savedconfig/sys-kernel/gentoo-kernel-6.18.60 --write

Without --write, writes <savedconfig>.stripped for inspection.
With --write, makes a .pre-debian-prune backup and replaces the input.
Only modules are pruned; built-in options are preserved except for explicit
D630 platform overrides below.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEBIAN_CONFIG = ROOT / "kernels/reference/debian-6.1.0-52-amd64.config"
DEBIAN_D630 = ROOT / "kernels/reference/debian-d630-core2.config"
GENTOO_D630 = ROOT / "kernels/profiles/20-d630-base.config"
MODULES_ORDER = (
    ROOT / "kernels/profiles/20-d630-base/debian12/6.1.0-52-d630-core2/modules.order"
)

# Module filenames that do not directly follow the CONFIG_<NAME> -> <name>.ko
# convention. Values are basenames without the .ko suffix.
MODULE_ALIASES = {
    "AGP_INTEL": {"intel-agp"},
    "ACPI_AC": {"ac"},
    "ACPI_BATTERY": {"battery"},
    "ACPI_BUTTON": {"button"},
    "ACPI_FAN": {"fan"},
    "ACPI_VIDEO": {"video"},
    "ATA_PIIX": {"ata_piix"},
    "BLK_DEV_SD": {"sd_mod"},
    "BLK_DEV_SR": {"sr_mod"},
    "BT_HCIBTUSB": {"btusb"},
    "DELL_SMBIOS": {"dell-smbios"},
    "DELL_SMO8800": {"dell-smo8800"},
    "DELL_WMI_DESCRIPTOR": {"dell-wmi-descriptor"},
    "DRM_I915": {"i915"},
    "I2C_I801": {"i2c-i801"},
    "INPUT_EVDEV": {"evdev"},
    "IWLEGACY": {"iwlegacy"},
    "IWL3945": {"iwl3945"},
    "IWL4965": {"iwl4965"},
    "MOUSE_PS2": {"psmouse"},
    "SATA_AHCI": {"ahci"},
    "SENSORS_CORETEMP": {"coretemp"},
    "SENSORS_DELL_SMM": {"dell-smm-hwmon"},
    "SND_HDA": {"snd-hda-codec"},
    "SND_HDA_CODEC_SIGMATEL": {"snd-hda-codec-idt"},
    "SND_HDA_INTEL": {"snd-hda-intel"},
    "USB_EHCI_HCD": {"ehci-hcd", "ehci-pci"},
    "USB_HID": {"usbhid"},
    "USB_NET_CDC_NCM": {"cdc_ncm"},
    "ACPI_WMI": {"wmi"},
    "BT": {"bluetooth"},
    "CPU_FREQ_GOV_POWERSAVE": {"cpufreq-powersave", "cpufreq_powersave"},
    "CPU_FREQ_GOV_ONDEMAND": {"cpufreq-ondemand", "cpufreq_ondemand"},
    "CPU_FREQ_GOV_CONSERVATIVE": {"cpufreq-conservative", "cpufreq_conservative"},
    "CPU_FREQ_GOV_USERSPACE": {"cpufreq-userspace", "cpufreq_userspace"},
    "DELL_PC": {"dell-pc", "dell_pc"},
    "INPUT_JOYSTICK": {"joydev"},
    "USB_NET_CDCETHER": {"cdc_ether"},
    "USB_NET_RNDIS_HOST": {"rndis_host"},
    "USB_STORAGE": {"usb-storage"},
    "USB_UHCI_HCD": {"uhci-hcd"},
    "USB_USBNET": {"usbnet"},
}

# These paths are known to be part of the Debian D630 kernel module inventory.
# ext4, NTFS3 and MSR are expected to be built in, not present as .ko files.
REQUIRED_MODULE_PATHS = {
    "kernel/drivers/ata/ahci.ko",
    "kernel/drivers/ata/ata_piix.ko",
    "kernel/drivers/gpu/drm/i915/i915.ko",
    "kernel/drivers/net/wireless/intel/iwlegacy/iwlegacy.ko",
    "kernel/drivers/net/wireless/intel/iwlegacy/iwl3945.ko",
    "kernel/drivers/usb/host/ehci-pci.ko",
    "kernel/drivers/usb/host/uhci-hcd.ko",
    "kernel/drivers/usb/storage/usb-storage.ko",
    "kernel/drivers/net/usb/usbnet.ko",
    "kernel/drivers/net/usb/rndis_host.ko",
    "kernel/drivers/net/usb/cdc_ether.ko",
    "kernel/drivers/input/mouse/psmouse.ko",
    "kernel/drivers/input/evdev.ko",
    "kernel/sound/pci/hda/snd-hda-intel.ko",
    "kernel/sound/pci/hda/snd-hda-codec-idt.ko",
}

# Keep the known D630 hardware modules if the Debian policy fragment or
# Gentoo D630 profile explicitly selects them. Debian config remains the
# general module allow-list.
BUILTIN_OVERRIDES = {
    "X86_MSR": "y",
    "X86_CPUID": "y",
    "EXT4_FS": "y",
    "NTFS3_FS": "y",
    "EFI": "n",
    "EFI_STUB": "n",
    "EFIVAR_FS": "n",
    "SMP": "y",
    "CPU_SUP_INTEL": "y",
    "MICROCODE": "y",
    "FW_LOADER": "y",
}

ZRAM_OVERRIDES = {
    "DEBUG_FS": "y",
    "ZSMALLOC_STAT": "y",
    "ZSMALLOC": "y",
    "ZRAM": "y",
    "ZRAM_BACKEND_LZO": "y",
    "ZRAM_BACKEND_LZ4": "y",
    "ZRAM_BACKEND_LZ4HC": "y",
    "ZRAM_BACKEND_ZSTD": "y",
    "ZRAM_BACKEND_DEFLATE": "y",
    "ZRAM_BACKEND_842": "y",
    "ZRAM_DEF_COMP_LZO": "y",
    "ZRAM_DEF_COMP_LZORLE": "n",
    "ZRAM_DEF_COMP_LZ4": "n",
    "ZRAM_DEF_COMP_LZ4HC": "n",
    "ZRAM_DEF_COMP_ZSTD": "n",
    "ZRAM_DEF_COMP_DEFLATE": "n",
    "ZRAM_DEF_COMP_842": "n",
    "ZRAM_WRITEBACK": "y",
    "ZRAM_TRACK_ENTRY_ACTIME": "y",
    "ZRAM_MEMORY_TRACKING": "y",
    "ZRAM_MULTI_COMP": "y",
}

CPUFREQ_OVERRIDES = {
    "CPU_FREQ": "y",
    "CPU_FREQ_DEFAULT_GOV_SCHEDUTIL": "y",
    "CPU_FREQ_GOV_SCHEDUTIL": "y",
    "CPU_FREQ_GOV_USERSPACE": "y",
    "X86_ACPI_CPUFREQ": "m",
}

GENTOO_MODULE_OVERRIDES = {
    "MODULES": "y",
    "MODULE_UNLOAD": "y",
    "MODULE_COMPRESS": "y",
    "MODULE_COMPRESS_ZSTD": "y",
    "MODULE_COMPRESS_ALL": "n",
}

# Explicit exclusions for hardware or buses absent from this legacy-BIOS D630.
D630_EXCLUSIONS = {
    "USB_XHCI_HCD": "n",
    "NVME_CORE": "n",
    "BLK_DEV_NVME": "n",
    "NVME_FABRICS": "n",
    "NVME_RDMA": "n",
    "NVME_FC": "n",
    "NVME_TCP": "n",
    "NVME_TARGET": "n",
    "CAN": "n",
    "ISDN": "n",
    "INFINIBAND": "n",
    "FIREWIRE": "n",
    "NFC": "n",
    "WIMAX": "n",
    "IEEE802154": "n",
    "6LOWPAN": "n",
    "USB_GADGET": "n",
    "ETHERNET": "n",
    "MTD": "n",
    "MEDIA_DIGITAL_TV_SUPPORT": "n",
    "MEDIA_RADIO_SUPPORT": "n",
    "MEDIA_SDR_SUPPORT": "n",
    "MEDIA_TEST_SUPPORT": "n",
    "DVB_CORE": "n",
    "RADIO_ADAPTERS": "n",
}


def parse_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^CONFIG_([A-Z0-9_]+)=(.*)$", line)
        if match:
            values[match.group(1)] = match.group(2)
            continue
        match = re.match(r"^# CONFIG_([A-Z0-9_]+) is not set$", line)
        if match:
            values[match.group(1)] = "n"
    return values


def parse_fragment(path: Path) -> dict[str, str]:
    return parse_config(path)


def write_config(path: Path, updates: dict[str, str]) -> None:
    remaining = dict(updates)
    output: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^(?:CONFIG_([A-Z0-9_]+)=.*|# CONFIG_([A-Z0-9_]+) is not set)$", line)
        if not match:
            output.append(line)
            continue
        symbol = match.group(1) or match.group(2)
        if symbol not in remaining:
            output.append(line)
            continue
        value = remaining.pop(symbol)
        output.append(f"CONFIG_{symbol}={value}" if value != "n"
                      else f"# CONFIG_{symbol} is not set")
    if remaining:
        output.append("")
        output.append("# D630 policy overrides")
        for symbol, value in sorted(remaining.items()):
            output.append(f"CONFIG_{symbol}={value}" if value != "n"
                          else f"# CONFIG_{symbol} is not set")
    path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")


def module_names(order_path: Path) -> set[str]:
    names = set()
    for line in order_path.read_text(encoding="utf-8", errors="replace").splitlines():
        item = line.strip()
        if item.endswith(".ko"):
            names.add(Path(item).name[:-3])
    return names


def expected_module_names(symbol: str, available: set[str]) -> set[str] | None:
    if symbol in MODULE_ALIASES:
        return MODULE_ALIASES[symbol]
    # Only trust the normalised Kconfig/module-name convention when the
    # corresponding object is actually present in Debian's modules.order.
    candidate = symbol.lower().replace("_", "-")
    return {candidate} if candidate in available else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("savedconfig", type=Path, help="Gentoo savedconfig file for gentoo-kernel-6.18.60")
    parser.add_argument("--write", action="store_true",
                        help="replace the savedconfig after creating a backup")
    parser.add_argument("--output", type=Path,
                        help="write the result here (default: SAVEDCONFIG.stripped); ignored with --write")
    args = parser.parse_args()

    source = args.savedconfig.resolve()
    if not source.is_file():
        parser.error(f"savedconfig does not exist: {source}")
    for path in (DEBIAN_CONFIG, DEBIAN_D630, GENTOO_D630, MODULES_ORDER):
        if not path.is_file():
            raise SystemExit(f"Missing D630 reference input: {path}")

    released = parse_config(source)
    debian = parse_config(DEBIAN_CONFIG)
    debian_policy = parse_fragment(DEBIAN_D630)
    gentoo_policy = parse_fragment(GENTOO_D630)
    modules = module_names(MODULES_ORDER)

    missing_required = sorted(REQUIRED_MODULE_PATHS - {
        line.strip() for line in MODULES_ORDER.read_text(encoding="utf-8").splitlines()
    })
    if missing_required:
        raise SystemExit(
            "Debian modules.order is missing required D630 modules:\n  "
            + "\n  ".join(missing_required)
        )

    updates: dict[str, str] = {}
    kept_debian = 0
    kept_policy = 0
    removed = 0
    ambiguous = 0
    known_name_checked = 0

    # Prune only =m settings. Do not discard release built-ins here.
    for symbol, value in released.items():
        if value != "m":
            continue

        # Gentoo profile has final say over the Debian D630 overlay.
        profile_value = gentoo_policy.get(symbol)
        overlay_value = debian_policy.get(symbol)
        if profile_value == "n" or overlay_value == "n":
            updates[symbol] = "n"
            removed += 1
            continue
        if profile_value in {"m", "y"} or overlay_value in {"m", "y"}:
            kept_policy += 1
            continue

        expected = expected_module_names(symbol, modules)
        if debian.get(symbol) != "m":
            # A path in modules.order is authoritative even if this Kconfig
            # symbol was renamed or absent from the older Debian config.
            if expected is not None and not expected.isdisjoint(modules):
                kept_debian += 1
            else:
                updates[symbol] = "n"
                removed += 1
            continue

        if expected is None:
            # Some Debian modules have a Kconfig name that differs from the
            # .ko basename. Preserve these conservatively rather than guessing.
            kept_debian += 1
            ambiguous += 1
            continue

        known_name_checked += 1
        if expected.isdisjoint(modules):
            updates[symbol] = "n"
            removed += 1
        else:
            kept_debian += 1

    # Apply explicit D630 settings after module pruning.
    updates.update(BUILTIN_OVERRIDES)
    updates.update(ZRAM_OVERRIDES)
    updates.update(CPUFREQ_OVERRIDES)
    updates.update(GENTOO_MODULE_OVERRIDES)
    updates.update(D630_EXCLUSIONS)

    # Preserve policy-selected D630 modules when present in the released config.
    # Do not promote these to built-in; only the required core items above are.
    target = source if args.write else (args.output or Path(str(source) + ".stripped")).resolve()
    if args.write:
        backup = Path(str(source) + ".pre-debian-prune")
        if not backup.exists():
            shutil.copy2(source, backup)
    else:
        shutil.copy2(source, target)

    write_config(target, updates)

    final = parse_config(target)
    required = {
        "X86_MSR": "y",
        "X86_CPUID": "y",
        "EXT4_FS": "y",
        "NTFS3_FS": "y",
        "ZRAM": "y",
        "ZSMALLOC": "y",
        "ZRAM_BACKEND_LZO": "y",
        "ZRAM_BACKEND_LZ4": "y",
        "ZRAM_BACKEND_LZ4HC": "y",
        "ZRAM_BACKEND_ZSTD": "y",
        "ZRAM_BACKEND_DEFLATE": "y",
        "ZRAM_BACKEND_842": "y",
        "ZRAM_DEF_COMP_LZO": "y",
        "ZRAM_DEF_COMP_LZORLE": "n",
        "ZRAM_DEF_COMP_LZ4": "n",
        "ZRAM_DEF_COMP_LZ4HC": "n",
        "ZRAM_DEF_COMP_ZSTD": "n",
        "ZRAM_DEF_COMP_DEFLATE": "n",
        "ZRAM_DEF_COMP_842": "n",
        "ZRAM_WRITEBACK": "y",
        "ZRAM_TRACK_ENTRY_ACTIME": "y",
        "ZRAM_MEMORY_TRACKING": "y",
        "ZRAM_MULTI_COMP": "y",
        "CPU_FREQ_GOV_USERSPACE": "y",
        "X86_ACPI_CPUFREQ": "m",
        "MODULE_COMPRESS_ZSTD": "y",
    }
    failures = [f"CONFIG_{k}: expected {v}, got {final.get(k, 'missing')}"
                for k, v in required.items() if final.get(k) != v]
    if failures:
        raise SystemExit("Generated config failed required-option checks:\n  " + "\n  ".join(failures))

    module_before = sum(value == "m" for value in released.values())
    module_after = sum(value == "m" for value in final.values())
    report = Path(str(target) + ".report.txt")
    report.write_text(
        "\n".join([
            "D630 Gentoo kernel savedconfig pruning report",
            f"Input: {source}",
            f"Output: {target}",
            f"Debian baseline: {DEBIAN_CONFIG}",
            f"Debian D630 policy: {DEBIAN_D630}",
            f"Debian modules.order: {MODULES_ORDER}",
            f"Debian module inventory entries: {len(modules)}",
            f"Module options before: {module_before}",
            f"Module options after: {module_after}",
            f"Removed module options: {removed}",
            f"Kept by Debian config/module inventory: {kept_debian}",
            f"Kept by explicit D630 policy: {kept_policy}",
            f"Unmapped Debian module names retained conservatively: {ambiguous}",
            f"Module basename checks performed: {known_name_checked}",
            "Required built-ins: X86_MSR, EXT4_FS, NTFS3_FS.",
            "ZRAM: all compiled backends, writeback, age tracking, memory tracking and multi-compressor enabled.",
            "CPUFreq: schedutil default, userspace governor available, ACPI cpufreq module.",
            "Legacy BIOS: EFI/EFI_STUB/EFIVAR_FS disabled.",
            "No kernel compile was performed by this script. Gentoo's kernel build must resolve Kconfig dependencies.",
            "",
        ]),
        encoding="utf-8",
    )
    print(f"Savedconfig written: {target}")
    print(f"Backup: {str(source) + '.pre-debian-prune' if args.write else 'original left untouched'}")
    print(f"Modules: {module_before} -> {module_after}; disabled {removed}.")
    print(f"Report: {report}")
    print("Next: rebuild gentoo-kernel and inspect the resolved .config for any Kconfig dependency changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
