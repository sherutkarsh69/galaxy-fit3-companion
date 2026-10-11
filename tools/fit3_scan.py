#!/usr/bin/env python3
"""Samsung Galaxy Fit3 (SM-R390) BLE Diagnostic Scanner and Inspector.

This tool performs non-destructive diagnostic scanning, GATT enumeration,
Heart Rate monitoring, notification logging, and proprietary Samsung Auth Service
inspection for the Samsung Galaxy Fit3 activity tracker.

Safety: Strictly passive and read-only. Never writes to unknown characteristics
or sends guessed proprietary payloads.
"""

from __future__ import annotations

import argparse
import asyncio
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
import logging
import os
from pathlib import Path
import re
import signal
import struct
import sys
from typing import Any, Dict, List, Optional, Tuple

from bleak import BleakClient, BleakScanner
from bleak.backends.characteristic import BleakGATTCharacteristic
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from bleak.exc import BleakError

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("fit3_scan")

# -----------------------------------------------------------------------------
# Standard SIG & Samsung Known UUID Reference Mappings
# -----------------------------------------------------------------------------
SIG_SERVICES: dict[str, str] = {
    "00001800-0000-1000-8000-00805f9b34fb": "Generic Access",
    "00001801-0000-1000-8000-00805f9b34fb": "Generic Attribute",
    "0000180a-0000-1000-8000-00805f9b34fb": "Device Information",
    "0000180d-0000-1000-8000-00805f9b34fb": "Heart Rate",
    "0000180f-0000-1000-8000-00805f9b34fb": "Battery Service",
    "00001805-0000-1000-8000-00805f9b34fb": "Current Time Service",
}

SIG_CHARACTERISTICS: dict[str, str] = {
    "00002a00-0000-1000-8000-00805f9b34fb": "Device Name",
    "00002a01-0000-1000-8000-00805f9b34fb": "Appearance",
    "00002a19-0000-1000-8000-00805f9b34fb": "Battery Level",
    "00002a24-0000-1000-8000-00805f9b34fb": "Model Number String",
    "00002a25-0000-1000-8000-00805f9b34fb": "Serial Number String",
    "00002a26-0000-1000-8000-00805f9b34fb": "Firmware Revision String",
    "00002a27-0000-1000-8000-00805f9b34fb": "Hardware Revision String",
    "00002a28-0000-1000-8000-00805f9b34fb": "Software Revision String",
    "00002a29-0000-1000-8000-00805f9b34fb": "Manufacturer Name String",
    "00002a37-0000-1000-8000-00805f9b34fb": "Heart Rate Measurement",
    "00002a38-0000-1000-8000-00805f9b34fb": "Body Sensor Location",
    "00002a39-0000-1000-8000-00805f9b34fb": "Heart Rate Control Point",
    "00002aa6-0000-1000-8000-00805f9b34fb": "Central Address Resolution",
}

SAMSUNG_SERVICES: dict[str, str] = {
    "eedd5e73-6aa8-4673-8219-398a489da87c": "Samsung Auth/Crypto",
    "0000fd69-0000-1000-8000-00805f9b34fb": "Samsung Find Device (FD69)",
}

SAMSUNG_CHARACTERISTICS_PREFIX: dict[str, str] = {
    "50f98bfd": "Supported Cipher",
    "a12be31c": "Nonce",
    "4ebe81f6": "Encrypted Nonce",
}

BODY_SENSOR_LOCATIONS: dict[int, str] = {
    0: "Other",
    1: "Chest",
    2: "Wrist",
    3: "Finger",
    4: "Hand",
    5: "Ear Lobe",
    6: "Foot",
}


def get_iso_timestamp() -> str:
    """Return the current local/UTC ISO 8601 formatted timestamp."""
    return datetime.now(timezone.utc).astimezone().isoformat()


def normalize_uuid(uuid_str: str) -> str:
    """Normalize a 16-bit, 32-bit, or 128-bit UUID to lowercase 128-bit canonical format."""
    u = uuid_str.lower().strip()
    if len(u) == 4:
        return f"0000{u}-0000-1000-8000-00805f9b34fb"
    if len(u) == 8:
        return f"{u}-0000-1000-8000-00805f9b34fb"
    return u


def lookup_service_name(uuid_str: str) -> Tuple[str, bool]:
    """Return the friendly service description and a flag indicating if it is standard SIG."""
    norm = normalize_uuid(uuid_str)
    if norm in SIG_SERVICES:
        return SIG_SERVICES[norm], True
    if norm in SAMSUNG_SERVICES:
        return SAMSUNG_SERVICES[norm], False
    return "Proprietary / Unknown Service", False


def lookup_characteristic_name(uuid_str: str) -> Tuple[str, bool]:
    """Return the friendly characteristic name and a flag indicating if it is standard SIG."""
    norm = normalize_uuid(uuid_str)
    if norm in SIG_CHARACTERISTICS:
        return SIG_CHARACTERISTICS[norm], True
    for prefix, name in SAMSUNG_CHARACTERISTICS_PREFIX.items():
        if norm.startswith(prefix.lower()):
            return f"Samsung {name}", False
    return "Proprietary Characteristic", False


# -----------------------------------------------------------------------------
# Data Models for Reporting
# -----------------------------------------------------------------------------
@dataclass
class DiscoveredDescriptorInfo:
    uuid: str
    handle: int
    value_hex: Optional[str] = None
    value_decoded: Optional[str] = None


@dataclass
class DiscoveredCharacteristicInfo:
    uuid: str
    handle: int
    name: str
    is_standard: bool
    properties: list[str]
    can_read: bool
    can_write: bool
    can_notify: bool
    can_indicate: bool
    read_value_hex: Optional[str] = None
    read_value_decoded: Optional[str] = None
    read_error: Optional[str] = None
    descriptors: list[DiscoveredDescriptorInfo] = field(default_factory=list)


@dataclass
class DiscoveredServiceInfo:
    uuid: str
    name: str
    is_standard: bool
    characteristics: list[DiscoveredCharacteristicInfo] = field(default_factory=list)


@dataclass
class HeartRateSample:
    timestamp: str
    bpm: int
    sensor_contact: str
    energy_expended_kj: Optional[int] = None
    rr_intervals_ms: list[float] = field(default_factory=list)


@dataclass
class NotificationEvent:
    timestamp: str
    service_uuid: str
    characteristic_uuid: str
    length: int
    data_hex: str
    data_ascii: str


@dataclass
class SamsungAuthInspection:
    service_found: bool
    service_uuid: str
    supported_cipher_hex: Optional[str] = None
    supported_cipher_decoded: Optional[str] = None
    supported_cipher_error: Optional[str] = None
    nonce_hex: Optional[str] = None
    nonce_length: Optional[int] = None
    nonce_error: Optional[str] = None
    characteristics_discovered: list[str] = field(default_factory=list)


@dataclass
class DiagnosticReport:
    generated_at: str
    tool_version: str
    target_address: Optional[str]
    target_name: Optional[str]
    scan_results: list[dict[str, Any]] = field(default_factory=list)
    gatt_services: list[DiscoveredServiceInfo] = field(default_factory=list)
    hr_samples: list[HeartRateSample] = field(default_factory=list)
    notifications: list[NotificationEvent] = field(default_factory=list)
    samsung_auth: Optional[SamsungAuthInspection] = None
    errors: list[dict[str, str]] = field(default_factory=list)


# -----------------------------------------------------------------------------
# Parser Helpers
# -----------------------------------------------------------------------------
def decode_bytes_safely(raw_bytes: bytes) -> str:
    """Attempt clean human-readable decoding (ASCII/UTF-8) or hex fallback."""
    if not raw_bytes:
        return "<empty>"
    try:
        decoded = raw_bytes.decode("utf-8").strip("\x00")
        if all(32 <= ord(c) < 127 or c in "\r\n\t" for c in decoded) and len(decoded) > 0:
            return decoded
    except UnicodeDecodeError:
        pass
    return f"0x{raw_bytes.hex().upper()}"


def parse_standard_characteristic_value(uuid_norm: str, data: bytes) -> str:
    """Decode known Bluetooth SIG characteristics into meaningful representations."""
    if not data:
        return "<empty>"

    # Battery Level (0x2A19: 1 byte, 0-100%)
    if uuid_norm == "00002a19-0000-1000-8000-00805f9b34fb":
        if len(data) >= 1:
            return f"{data[0]}%"

    # Body Sensor Location (0x2A38: 1 byte enum)
    if uuid_norm == "00002a38-0000-1000-8000-00805f9b34fb":
        if len(data) >= 1:
            loc_val = data[0]
            return BODY_SENSOR_LOCATIONS.get(loc_val, f"Unknown ({loc_val})")

    # Strings (Device Name, Model, Serial, Firmware, Hardware, Software, Manufacturer)
    str_uuids = {
        "00002a00-0000-1000-8000-00805f9b34fb",
        "00002a24-0000-1000-8000-00805f9b34fb",
        "00002a25-0000-1000-8000-00805f9b34fb",
        "00002a26-0000-1000-8000-00805f9b34fb",
        "00002a27-0000-1000-8000-00805f9b34fb",
        "00002a28-0000-1000-8000-00805f9b34fb",
        "00002a29-0000-1000-8000-00805f9b34fb",
    }
    if uuid_norm in str_uuids:
        try:
            return data.decode("utf-8", errors="replace").strip("\x00")
        except Exception:
            pass

    return decode_bytes_safely(data)


def parse_heart_rate_measurement(data: bytes) -> HeartRateSample:
    """Parse standard Bluetooth SIG Heart Rate Measurement (0x2A37).

    Flags Byte:
    - Bit 0: HR Format (0: UINT8, 1: UINT16)
    - Bit 1-2: Sensor Contact Status (00/01: not supported/detected, 10: supported not detected, 11: supported detected)
    - Bit 3: Energy Expended Status (1: present as UINT16)
    - Bit 4: RR-Interval (1: present as one or more UINT16 in 1/1024 seconds)
    """
    if len(data) < 2:
        raise ValueError(f"Packet too short for Heart Rate Measurement: {len(data)} bytes")

    flags = data[0]
    hr_format_16 = bool(flags & 0x01)
    contact_bits = (flags >> 1) & 0x03
    energy_present = bool(flags & 0x08)
    rr_present = bool(flags & 0x10)

    offset = 1
    if hr_format_16:
        if len(data) < offset + 2:
            raise ValueError("Incomplete 16-bit HR field")
        bpm = struct.unpack_from("<H", data, offset)[0]
        offset += 2
    else:
        bpm = data[offset]
        offset += 1

    contact_desc = {
        0: "Not Supported",
        1: "Not Supported",
        2: "Supported (No Contact)",
        3: "Supported (Contact Detected)",
    }.get(contact_bits, "Unknown")

    energy_kj: Optional[int] = None
    if energy_present:
        if len(data) >= offset + 2:
            energy_kj = struct.unpack_from("<H", data, offset)[0]
            offset += 2

    rr_intervals: list[float] = []
    if rr_present:
        while len(data) >= offset + 2:
            raw_rr = struct.unpack_from("<H", data, offset)[0]
            # 1/1024 s to milliseconds
            ms = round((raw_rr / 1024.0) * 1000.0, 2)
            rr_intervals.append(ms)
            offset += 2

    return HeartRateSample(
        timestamp=get_iso_timestamp(),
        bpm=bpm,
        sensor_contact=contact_desc,
        energy_expended_kj=energy_kj,
        rr_intervals_ms=rr_intervals,
    )


# -----------------------------------------------------------------------------
# Core Scanner and Inspector Class
# -----------------------------------------------------------------------------
class Fit3Scanner:
    """Encapsulates BLE scanning, GATT enumeration, HR monitoring, and reporting."""

    def __init__(
        self,
        scan_time: int = 10,
        hr_time: int = 60,
        notify_time: int = 120,
        output_dir: Path | str = ".",
        target_mac: Optional[str] = None,
        scan_only: bool = False,
        no_hr: bool = False,
        no_notify: bool = False,
    ) -> None:
        self.scan_time = max(1, scan_time)
        self.hr_time = max(1, hr_time)
        self.notify_time = max(1, notify_time)
        self.output_dir = Path(output_dir)
        self.target_mac = target_mac.upper() if target_mac else None
        self.scan_only = scan_only
        self.no_hr = no_hr
        self.no_notify = no_notify

        self.shutdown_requested = asyncio.Event()
        self.report = DiagnosticReport(
            generated_at=get_iso_timestamp(),
            tool_version="1.0.0-windows",
            target_address=self.target_mac,
            target_name=None,
        )

    def log_error(self, stage: str, message: str, hint: Optional[str] = None) -> None:
        """Record an error into report and log to console with troubleshooting hints."""
        err_obj = {
            "timestamp": get_iso_timestamp(),
            "stage": stage,
            "message": message,
            "hint": hint or "Check device proximity and Windows Bluetooth settings.",
        }
        self.report.errors.append(err_obj)
        logger.error("[%s] %s", stage, message)
        if hint:
            logger.warning("[Troubleshooting Hint] %s", hint)

    async def scan_devices(self) -> list[Tuple[BLEDevice, AdvertisementData]]:
        """Perform BLE scan for specified duration and return discovered devices."""
        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] Scanning for BLE devices ({self.scan_time}s)...")
        print(f"=======================================================\n")

        discovered: dict[str, Tuple[BLEDevice, AdvertisementData]] = {}

        def detection_callback(device: BLEDevice, adv_data: AdvertisementData) -> None:
            discovered[device.address.upper()] = (device, adv_data)

        try:
            scanner = BleakScanner(detection_callback=detection_callback)
            await scanner.start()
            for _ in range(self.scan_time):
                if self.shutdown_requested.is_set():
                    break
                await asyncio.sleep(1.0)
            await scanner.stop()
        except BleakError as exc:
            self.log_error(
                "BLE Scanner",
                f"Bluetooth adapter scan failed: {exc}",
                "Ensure Bluetooth is enabled in Windows Settings and not in Airplane Mode.",
            )
            return []
        except Exception as exc:
            self.log_error("BLE Scanner", f"Unexpected scan exception: {exc}")
            return []

        results = list(discovered.values())
        print(f"Discovered {len(results)} BLE device(s):\n")

        for idx, (dev, adv) in enumerate(results, start=1):
            name = dev.name or adv.local_name or "<unnamed>"
            is_fit3 = bool(re.search(r"Galaxy\s*Fit3", name, re.IGNORECASE))
            highlight = " *** [GALAXY FIT3 CANDIDATE] ***" if is_fit3 else ""

            mfg_info = (
                {f"0x{k:04X}": v.hex() for k, v in adv.manufacturer_data.items()}
                if adv.manufacturer_data
                else {}
            )
            adv_services = [normalize_uuid(s) for s in adv.service_uuids]

            self.report.scan_results.append(
                {
                    "address": dev.address,
                    "name": name,
                    "rssi": adv.rssi,
                    "is_fit3_match": is_fit3,
                    "manufacturer_data": mfg_info,
                    "service_uuids": adv_services,
                }
            )

            print(f"[{idx:2d}] {dev.address} | RSSI: {adv.rssi:4d} dBm | Name: '{name}'{highlight}")
            if adv_services:
                print(f"     Services: {', '.join(adv_services)}")
            if mfg_info:
                print(f"     Manufacturer Data: {mfg_info}")

        return results

    def select_device(
        self, devices: list[Tuple[BLEDevice, AdvertisementData]]
    ) -> Optional[BLEDevice]:
        """Prompt user or automatically choose the Galaxy Fit3 candidate."""
        if self.target_mac:
            for dev, _ in devices:
                if dev.address.upper() == self.target_mac:
                    return dev
            print(f"\nTarget MAC {self.target_mac} was not detected in scan.")
            return None

        fit3_matches = [
            (dev, adv)
            for dev, adv in devices
            if re.search(r"Galaxy\s*Fit3", dev.name or adv.local_name or "", re.IGNORECASE)
        ]

        if len(fit3_matches) == 1:
            chosen_dev, _ = fit3_matches[0]
            print(f"\n--> Automatically detected Galaxy Fit3: {chosen_dev.name} ({chosen_dev.address})")
            confirm = input("Connect to this device? [Y/n]: ").strip().lower()
            if confirm in ("", "y", "yes"):
                return chosen_dev

        if not devices:
            print("\nNo BLE devices found. Ensure device is powered on, charged, and nearby.")
            return None

        print("\nSelect a device to inspect (or press Enter to abort):")
        for idx, (dev, adv) in enumerate(devices, start=1):
            name = dev.name or adv.local_name or "<unnamed>"
            print(f"  [{idx}] {dev.address} ({name})")

        choice = input("Enter choice number: ").strip()
        if not choice.isdigit():
            print("Operation aborted by user.")
            return None

        choice_idx = int(choice)
        if 1 <= choice_idx <= len(devices):
            return devices[choice_idx - 1][0]

        print("Invalid choice index.")
        return None

    async def connect_and_enumerate_gatt(self, client: BleakClient) -> None:
        """Enumerate GATT services, characteristics, and descriptors."""
        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] GATT Profile Enumeration")
        print(f"=======================================================\n")

        for service in client.services:
            srv_uuid_norm = normalize_uuid(service.uuid)
            srv_desc, srv_is_sig = lookup_service_name(srv_uuid_norm)
            srv_label = "SIG Standard" if srv_is_sig else "Proprietary"

            srv_info = DiscoveredServiceInfo(
                uuid=srv_uuid_norm,
                name=srv_desc,
                is_standard=srv_is_sig,
            )

            print(f"\nService: {srv_uuid_norm} [{srv_desc}] ({srv_label})")

            for char in service.characteristics:
                char_uuid_norm = normalize_uuid(char.uuid)
                char_desc, char_is_sig = lookup_characteristic_name(char_uuid_norm)
                props = char.properties
                can_read = "read" in props
                can_write = any(p in props for p in ("write", "write-without-response"))
                can_notify = "notify" in props
                can_indicate = "indicate" in props

                char_info = DiscoveredCharacteristicInfo(
                    uuid=char_uuid_norm,
                    handle=char.handle,
                    name=char_desc,
                    is_standard=char_is_sig,
                    properties=props,
                    can_read=can_read,
                    can_write=can_write,
                    can_notify=can_notify,
                    can_indicate=can_indicate,
                )

                props_str = ",".join(props).upper()
                print(f"  * Char: {char_uuid_norm} [Handle: 0x{char.handle:04X}]")
                print(f"    Name: {char_desc} | Props: [{props_str}]")

                # Perform safe read if characteristic supports reading
                if can_read:
                    try:
                        raw_val = await client.read_gatt_char(char)
                        char_info.read_value_hex = f"0x{raw_val.hex().upper()}"
                        char_info.read_value_decoded = parse_standard_characteristic_value(
                            char_uuid_norm, raw_val
                        )
                        print(
                            f"    Value: {char_info.read_value_hex} | Decoded: '{char_info.read_value_decoded}'"
                        )
                    except BleakError as read_err:
                        err_msg = f"BleakError: {read_err}"
                        char_info.read_error = err_msg
                        print(f"    Value: [Read Failed: {err_msg}]")
                    except Exception as read_err:
                        err_msg = f"{type(read_err).__name__}: {read_err}"
                        char_info.read_error = err_msg
                        print(f"    Value: [Read Failed: {err_msg}]")

                # Descriptors
                for desc in char.descriptors:
                    desc_uuid_norm = normalize_uuid(desc.uuid)
                    desc_info = DiscoveredDescriptorInfo(
                        uuid=desc_uuid_norm,
                        handle=desc.handle,
                    )
                    try:
                        raw_desc = await client.read_gatt_descriptor(desc.handle)
                        desc_info.value_hex = f"0x{raw_desc.hex().upper()}"
                        desc_info.value_decoded = decode_bytes_safely(raw_desc)
                        print(
                            f"      - Desc: {desc_uuid_norm} [Handle: 0x{desc.handle:04X}] "
                            f"= {desc_info.value_hex} ('{desc_info.value_decoded}')"
                        )
                    except Exception as desc_err:
                        print(f"      - Desc: {desc_uuid_norm} [Read Failed: {desc_err}]")
                    char_info.descriptors.append(desc_info)

                srv_info.characteristics.append(char_info)

            self.report.gatt_services.append(srv_info)

    async def inspect_samsung_auth_service(self, client: BleakClient) -> None:
        """Inspect proprietary Samsung Auth Service strictly in read-only mode."""
        samsung_srv_uuid = normalize_uuid("eedd5e73-6aa8-4673-8219-398a489da87c")
        samsung_srv = client.services.get_service(samsung_srv_uuid)

        if not samsung_srv:
            logger.info("Samsung Auth/Crypto service (%s) not present on this device.", samsung_srv_uuid)
            return

        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] Samsung Proprietary - Read Only Inspection")
        print(f"=======================================================\n")
        print(f"Target Service: {samsung_srv_uuid} (Samsung Auth/Crypto)")
        print("SAFETY NOTICE: Strictly read-only inspection. No cryptographic or write operations will be sent.")

        inspection = SamsungAuthInspection(
            service_found=True,
            service_uuid=samsung_srv_uuid,
        )

        for char in samsung_srv.characteristics:
            norm_c = normalize_uuid(char.uuid)
            inspection.characteristics_discovered.append(norm_c)

            # Match Supported Cipher (50f98bfd-...)
            if norm_c.startswith("50f98bfd"):
                print(f"\n[+] Reading Supported Cipher Characteristic ({norm_c})...")
                try:
                    val = await client.read_gatt_char(char)
                    inspection.supported_cipher_hex = f"0x{val.hex().upper()}"
                    inspection.supported_cipher_decoded = decode_bytes_safely(val)
                    print(f"    Hex: {inspection.supported_cipher_hex}")
                    print(f"    Decoded Cipher String: '{inspection.supported_cipher_decoded}'")
                except Exception as exc:
                    err = str(exc)
                    inspection.supported_cipher_error = err
                    print(f"    [Read Error]: {err}")

            # Match Nonce Characteristic (a12be31c-...)
            elif norm_c.startswith("a12be31c"):
                print(f"\n[+] Reading Challenge Nonce Characteristic ({norm_c})...")
                try:
                    val = await client.read_gatt_char(char)
                    inspection.nonce_hex = f"0x{val.hex().upper()}"
                    inspection.nonce_length = len(val)
                    print(f"    Nonce Length: {len(val)} bytes")
                    print(f"    Nonce Hex: {inspection.nonce_hex}")
                except Exception as exc:
                    err = str(exc)
                    inspection.nonce_error = err
                    print(f"    [Read Error]: {err}")

            # Match Encrypted Nonce (4ebe81f6-...)
            elif norm_c.startswith("4ebe81f6"):
                print(f"\n[!] Encrypted Nonce Characteristic identified: {norm_c}")
                print("    [SAFE SKIP]: Characteristics requiring encrypted response are NOT written to.")

        self.report.samsung_auth = inspection

    async def monitor_heart_rate(self, client: BleakClient) -> None:
        """Subscribe to Heart Rate Measurement (0x2A37) and log live BPM readings."""
        if self.no_hr:
            print("\n[HR Monitor] Skipped by --no-hr flag.")
            return

        hr_char_uuid = normalize_uuid("00002a37-0000-1000-8000-00805f9b34fb")
        hr_char = client.services.get_characteristic(hr_char_uuid)
        if not hr_char:
            print("\n[HR Monitor] Heart Rate Measurement characteristic (0x2A37) not found on device.")
            return

        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] Live Heart Rate Monitor ({self.hr_time}s)")
        print(f"=======================================================")
        print("Listening for HR packets. Ensure sensor is against skin for readings... (Ctrl+C to stop)\n")

        def hr_notification_handler(_: BleakGATTCharacteristic, data: bytearray) -> None:
            try:
                sample = parse_heart_rate_measurement(bytes(data))
                self.report.hr_samples.append(sample)
                rr_str = f" | RR: {sample.rr_intervals_ms}ms" if sample.rr_intervals_ms else ""
                energy_str = (
                    f" | Energy: {sample.energy_expended_kj} kJ"
                    if sample.energy_expended_kj is not None
                    else ""
                )
                print(
                    f"[{sample.timestamp}] BPM: {sample.bpm:3d} | Contact: {sample.sensor_contact}"
                    f"{energy_str}{rr_str}"
                )
            except Exception as parse_err:
                logger.warning("Failed parsing HR packet: %s (Raw: 0x%s)", parse_err, data.hex())

        try:
            await client.start_notify(hr_char, hr_notification_handler)
            start_time = asyncio.get_running_loop().time()
            while (asyncio.get_running_loop().time() - start_time) < self.hr_time:
                if self.shutdown_requested.is_set():
                    break
                await asyncio.sleep(0.5)
            await client.stop_notify(hr_char)
            print(f"[HR Monitor] Completed. Logged {len(self.report.hr_samples)} sample(s).")
        except Exception as exc:
            self.log_error(
                "HR Monitor",
                f"Heart rate subscription error: {exc}",
                "Ensure device is not currently streaming HR to Samsung Health.",
            )

    async def log_all_notifications(self, client: BleakClient) -> None:
        """Subscribe to all notifiable characteristics and record received packets."""
        if self.no_notify:
            print("\n[Notification Logger] Skipped by --no-notify flag.")
            return

        notifiable_chars: list[BleakGATTCharacteristic] = []
        for service in client.services:
            for char in service.characteristics:
                if "notify" in char.properties or "indicate" in char.properties:
                    # Skip 0x2A37 if already monitored
                    if normalize_uuid(char.uuid) == "00002a37-0000-1000-8000-00805f9b34fb":
                        continue
                    notifiable_chars.append(char)

        if not notifiable_chars:
            print("\n[Notification Logger] No additional notifiable characteristics found.")
            return

        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] Notification Logger ({self.notify_time}s)")
        print(f"=======================================================")
        print(f"Discovered {len(notifiable_chars)} notifiable characteristic(s).")

        confirm = input("Subscribe to all notifiable characteristics? [Y/n]: ").strip().lower()
        if confirm not in ("", "y", "yes"):
            print("Skipping notification logging.")
            return

        active_subscriptions: list[BleakGATTCharacteristic] = []

        def make_handler(srv_uuid: str, char_uuid: str):
            def handler(_: BleakGATTCharacteristic, data: bytearray) -> None:
                now_iso = get_iso_timestamp()
                raw_bytes = bytes(data)
                evt = NotificationEvent(
                    timestamp=now_iso,
                    service_uuid=srv_uuid,
                    characteristic_uuid=char_uuid,
                    length=len(raw_bytes),
                    data_hex=f"0x{raw_bytes.hex().upper()}",
                    data_ascii=decode_bytes_safely(raw_bytes),
                )
                self.report.notifications.append(evt)
                print(
                    f"[{now_iso}] NOTIFY {char_uuid} (Len {evt.length}): {evt.data_hex} ('{evt.data_ascii}')"
                )

            return handler

        for char in notifiable_chars:
            srv_norm = normalize_uuid(char.service_uuid) if hasattr(char, "service_uuid") else "Unknown"
            char_norm = normalize_uuid(char.uuid)
            try:
                await client.start_notify(char, make_handler(srv_norm, char_norm))
                active_subscriptions.append(char)
                print(f"  + Subscribed to {char_norm} ({lookup_characteristic_name(char_norm)[0]})")
            except Exception as sub_err:
                logger.warning("Could not subscribe to %s: %s", char_norm, sub_err)

        if not active_subscriptions:
            print("No subscriptions could be activated.")
            return

        print(f"\nListening for notifications for {self.notify_time}s... (Ctrl+C to stop)\n")
        start_time = asyncio.get_running_loop().time()
        while (asyncio.get_running_loop().time() - start_time) < self.notify_time:
            if self.shutdown_requested.is_set():
                break
            await asyncio.sleep(0.5)

        for char in active_subscriptions:
            try:
                await client.stop_notify(char)
            except Exception:
                pass
        print(f"\n[Notification Logger] Completed. Captured {len(self.report.notifications)} event(s).")

    def export_reports(self) -> Tuple[Path, Path]:
        """Export both JSON and human-readable text diagnostic reports."""
        self.output_dir.mkdir(parents=True, exist_ok=True)
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        json_path = self.output_dir / f"fit3_report_{timestamp_str}.json"
        txt_path = self.output_dir / f"fit3_report_{timestamp_str}.txt"

        # 1. JSON Report
        report_dict = asdict(self.report)
        with open(json_path, "w", encoding="utf-8") as jf:
            json.dump(report_dict, jf, indent=2, ensure_ascii=False)

        # 2. Text Report
        with open(txt_path, "w", encoding="utf-8") as tf:
            tf.write("=" * 80 + "\n")
            tf.write("       SAMSUNG GALAXY FIT3 BLE DIAGNOSTIC & ENUMERATION REPORT\n")
            tf.write("=" * 80 + "\n")
            tf.write(f"Generated At      : {self.report.generated_at}\n")
            tf.write(f"Tool Version      : {self.report.tool_version}\n")
            tf.write(f"Target Device     : {self.report.target_name or 'N/A'}\n")
            tf.write(f"Target MAC        : {self.report.target_address or 'N/A'}\n")
            tf.write(f"Total Errors      : {len(self.report.errors)}\n\n")

            tf.write("-" * 80 + "\n")
            tf.write("1. GATT SERVICES & CHARACTERISTICS TREE\n")
            tf.write("-" * 80 + "\n")
            if not self.report.gatt_services:
                tf.write("  No GATT services recorded (e.g. scan-only mode or connection failed).\n")
            for srv in self.report.gatt_services:
                cat = "SIG Standard" if srv.is_standard else "Proprietary"
                tf.write(f"\n[SERVICE] {srv.uuid}\n")
                tf.write(f"  Description: {srv.name} ({cat})\n")
                for ch in srv.characteristics:
                    tf.write(f"  +- [CHAR] {ch.uuid} (Handle: 0x{ch.handle:04X})\n")
                    tf.write(f"     Name      : {ch.name}\n")
                    tf.write(f"     Properties: {', '.join(ch.properties).upper()}\n")
                    if ch.can_read:
                        if ch.read_error:
                            tf.write(f"     Read Error: {ch.read_error}\n")
                        else:
                            tf.write(f"     Read Hex  : {ch.read_value_hex}\n")
                            tf.write(f"     Read Text : {ch.read_value_decoded}\n")
                    for desc in ch.descriptors:
                        tf.write(
                            f"     +- [DESC] {desc.uuid} (Handle: 0x{desc.handle:04X}) "
                            f"= {desc.value_hex} ('{desc.value_decoded}')\n"
                        )

            tf.write("\n" + "-" * 80 + "\n")
            tf.write("2. SAMSUNG AUTH/CRYPTO SERVICE INSPECTION\n")
            tf.write("-" * 80 + "\n")
            if self.report.samsung_auth:
                sa = self.report.samsung_auth
                tf.write(f"Service UUID          : {sa.service_uuid}\n")
                tf.write(f"Supported Cipher Hex  : {sa.supported_cipher_hex or 'N/A'}\n")
                tf.write(f"Supported Cipher Text : {sa.supported_cipher_decoded or 'N/A'}\n")
                if sa.supported_cipher_error:
                    tf.write(f"Supported Cipher Err  : {sa.supported_cipher_error}\n")
                tf.write(f"Nonce Hex             : {sa.nonce_hex or 'N/A'}\n")
                tf.write(f"Nonce Length          : {sa.nonce_length or 0} bytes\n")
                if sa.nonce_error:
                    tf.write(f"Nonce Error           : {sa.nonce_error}\n")
                tf.write(f"Discovered Chars      : {len(sa.characteristics_discovered)}\n")
            else:
                tf.write("  Samsung Auth Service was not detected on this device.\n")

            tf.write("\n" + "-" * 80 + "\n")
            tf.write("3. HEART RATE MONITORING SAMPLES\n")
            tf.write("-" * 80 + "\n")
            tf.write(f"Total Samples: {len(self.report.hr_samples)}\n")
            for sample in self.report.hr_samples:
                rr_info = f", RR: {sample.rr_intervals_ms} ms" if sample.rr_intervals_ms else ""
                tf.write(
                    f"[{sample.timestamp}] BPM: {sample.bpm:3d} | Contact: {sample.sensor_contact}{rr_info}\n"
                )

            tf.write("\n" + "-" * 80 + "\n")
            tf.write("4. NOTIFICATION LOG\n")
            tf.write("-" * 80 + "\n")
            tf.write(f"Total Notifications: {len(self.report.notifications)}\n")
            for notif in self.report.notifications:
                tf.write(
                    f"[{notif.timestamp}] Char: {notif.characteristic_uuid} | "
                    f"Len: {notif.length:2d} | Hex: {notif.data_hex} | Ascii: '{notif.data_ascii}'\n"
                )

            tf.write("\n" + "-" * 80 + "\n")
            tf.write("5. RECORDED ERRORS & TROUBLESHOOTING\n")
            tf.write("-" * 80 + "\n")
            if not self.report.errors:
                tf.write("  No errors encountered during execution.\n")
            for err in self.report.errors:
                tf.write(f"[{err['timestamp']}] Stage: {err['stage']}\n")
                tf.write(f"  Message: {err['message']}\n")
                tf.write(f"  Hint   : {err['hint']}\n")

            tf.write("\n" + "=" * 80 + "\n")
            tf.write("END OF REPORT\n")
            tf.write("=" * 80 + "\n")

        print(f"\n=======================================================")
        print(f"[{get_iso_timestamp()}] Diagnostic Reports Exported:")
        print(f"  JSON : {json_path.resolve()}")
        print(f"  Text : {txt_path.resolve()}")
        print(f"=======================================================\n")
        return json_path, txt_path

    async def run(self) -> None:
        """Main execution sequence."""
        # 1. Device Discovery
        device: Optional[BLEDevice] = None
        if self.target_mac:
            # On Windows, Bleak requires a real BLEDevice with platform details.
            # We scan first and match by MAC address to get a valid device handle.
            print(f"Direct connection requested to target MAC: {self.target_mac}")
            print(f"Scanning to acquire device handle...")
            discovered = await self.scan_devices()
            for dev, adv in discovered:
                if dev.address.upper() == self.target_mac:
                    device = dev
                    print(f"\n--> Found target device: {dev.name} ({dev.address})")
                    break
            if not device:
                self.log_error(
                    "Device Lookup",
                    f"Target MAC {self.target_mac} was not found during scan.",
                    "Ensure device is powered on, in range, and not connected to another host.",
                )
                self.export_reports()
                return
        else:
            discovered = await self.scan_devices()
            if self.scan_only:
                print("\n--scan-only specified. Scanning finished.")
                self.export_reports()
                return

            device = self.select_device(discovered)
            if not device:
                print("No device selected. Exporting discovery scan report...")
                self.export_reports()
                return

        self.report.target_address = device.address
        self.report.target_name = device.name

        # 2. Connection and Inspection
        print(f"\nConnecting to {device.name or 'Device'} ({device.address})... (Timeout: 10s)")
        client = BleakClient(device, timeout=10.0)
        try:
            connected = await client.connect()
            if not connected:
                self.log_error(
                    "Connection",
                    f"Failed to connect to {device.address}.",
                    "Ensure device is not connected to Samsung Health on phone or another PC.",
                )
                self.export_reports()
                return

            print(f"Connected successfully! MTU: {client.mtu_size}")

            # 3. GATT Profile Enumeration
            await self.connect_and_enumerate_gatt(client)

            # 4. Samsung Auth Service Read-Only Inspection
            await self.inspect_samsung_auth_service(client)

            # 5. Heart Rate Monitor
            if not self.shutdown_requested.is_set():
                await self.monitor_heart_rate(client)

            # 6. Notification Logger
            if not self.shutdown_requested.is_set():
                await self.log_all_notifications(client)

        except BleakError as exc:
            self.log_error(
                "Bleak Connection",
                f"Connection exception: {exc}",
                "Disconnect device from phone first. In Windows Bluetooth settings, unpair and re-pair if needed.",
            )
        except asyncio.CancelledError:
            print("\nOperation cancelled by user.")
        except Exception as exc:
            self.log_error("Runtime", f"Unexpected runtime error: {exc}")
        finally:
            if client.is_connected:
                print("\nDisconnecting from device...")
                try:
                    await client.disconnect()
                    print("Disconnected safely.")
                except Exception as disc_err:
                    logger.warning("Error during disconnect: %s", disc_err)

            # 7. Final Report Export
            self.export_reports()


# -----------------------------------------------------------------------------
# Signal Handling and Entry Point
# -----------------------------------------------------------------------------
def build_cli_parser() -> argparse.ArgumentParser:
    """Create command-line argument parser."""
    parser = argparse.ArgumentParser(
        description="Samsung Galaxy Fit3 (SM-R390) BLE Diagnostic Scanner and GATT Inspector",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--scan-time", type=int, default=10, help="Duration to scan for BLE devices (seconds)")
    parser.add_argument("--hr-time", type=int, default=60, help="Duration to monitor Heart Rate (seconds)")
    parser.add_argument(
        "--notify-time",
        type=int,
        default=120,
        help="Duration to log general notifications (seconds)",
    )
    parser.add_argument("--output-dir", type=str, default=".", help="Directory to save generated reports")
    parser.add_argument(
        "--device",
        type=str,
        default=None,
        help="Direct Bluetooth address / MAC of target (skips selection)",
    )
    parser.add_argument(
        "--scan-only",
        action="store_true",
        help="Only perform discovery scan without GATT connection",
    )
    parser.add_argument("--no-hr", action="store_true", help="Skip Heart Rate monitoring step")
    parser.add_argument(
        "--no-notify",
        action="store_true",
        help="Skip general notification logging step",
    )
    return parser


def main() -> None:
    """Synchronous application entry point."""
    parser = build_cli_parser()
    args = parser.parse_args()

    app = Fit3Scanner(
        scan_time=args.scan_time,
        hr_time=args.hr_time,
        notify_time=args.notify_time,
        output_dir=args.output_dir,
        target_mac=args.device,
        scan_only=args.scan_only,
        no_hr=args.no_hr,
        no_notify=args.no_notify,
    )

    def sigint_handler(*_: Any) -> None:
        print("\n[Ctrl+C received] Finishing current operation and saving report...")
        app.shutdown_requested.set()

    # Windows and POSIX signal registration
    signal.signal(signal.SIGINT, sigint_handler)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, sigint_handler)

    try:
        asyncio.run(app.run())
    except KeyboardInterrupt:
        print("\nProcess interrupted. Finalizing...")
        app.export_reports()
    except Exception as exc:
        print(f"\nFatal error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
