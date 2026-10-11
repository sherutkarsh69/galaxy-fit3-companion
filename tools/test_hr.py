"""Galaxy Fit3 Heart Rate Stream & GATT Diagnostic Test."""
import asyncio
import json
import os
import sys
import time
from bleak import BleakClient, BleakScanner

TARGET = "74:19:0A:A5:39:8C"
HR_MEASUREMENT_UUID = "00002a37-0000-1000-8000-00805f9b34fb"
HR_LOCATION_UUID = "00002a38-0000-1000-8000-00805f9b34fb"

# Force UTF-8 stdout if needed on Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

def parse_hr(d: bytes):
    if not d or len(d) < 2:
        return 0, False, [], d.hex()
    flags = d[0]
    offset = 1
    # 0 = UINT8 BPM, 1 = UINT16 BPM
    if flags & 0x01:
        if len(d) >= offset + 2:
            bpm = d[offset] | (d[offset + 1] << 8)
            offset += 2
        else:
            bpm = 0
    else:
        bpm = d[offset]
        offset += 1
    
    # Sensor contact status: bit 1 and bit 2
    contact_supported = bool(flags & 0x04)
    contact_detected = bool(flags & 0x02) if contact_supported else None
    
    # Energy expended: bit 3
    if flags & 0x08 and len(d) >= offset + 2:
        offset += 2
        
    # RR intervals: bit 4
    rr_intervals = []
    if flags & 0x10:
        while len(d) >= offset + 2:
            rr_raw = d[offset] | (d[offset + 1] << 8)
            rr_intervals.append(round(rr_raw / 1024.0, 3))
            offset += 2
            
    return bpm, contact_detected, rr_intervals, d.hex()

async def main():
    print("=" * 60)
    print(" Galaxy Fit3 Live HR & BLE Connection Test")
    print("=" * 60)
    print(f"Target MAC: {TARGET}")
    print("Tip: Tap the band screen or wear it to ensure sensor activity.\n")
    
    found_device = None
    found_adv = None
    
    def on_detect(dev, adv):
        nonlocal found_device, found_adv
        if dev.address.upper() == TARGET:
            if found_device is None:
                found_device = dev
                found_adv = adv
                name = dev.name or adv.local_name or "Galaxy Fit3"
                print(f"  [+] DETECTED: {name} (RSSI: {adv.rssi} dBm)")

    print("[1/3] Scanning for Galaxy Fit3 (up to 30s)...")
    scanner = BleakScanner(detection_callback=on_detect)
    await scanner.start()
    
    for sec in range(30):
        await asyncio.sleep(1.0)
        if found_device is not None:
            print(f"  >> Device acquired in {sec + 1}s! Stopping scanner...")
            break
        if (sec + 1) % 5 == 0:
            print(f"  ... still scanning ({sec + 1}s / 30s)")
            
    await scanner.stop()
    await asyncio.sleep(1.5)  # Allow Windows BLE stack to settle
    
    if not found_device:
        print("\n[!] Device not found in 30s scan.")
        print("    Checking if direct connection by MAC address is possible...")
        client_target = TARGET
    else:
        client_target = found_device

    # Connect
    print(f"\n[2/3] Connecting to Galaxy Fit3 (timeout 30s)...")
    client = None
    connected = False
    
    try:
        client = BleakClient(client_target, timeout=30.0)
        await client.connect()
        connected = client.is_connected
        print(f"  [+] CONNECTED successfully! MTU: {client.mtu_size}")
    except Exception as e:
        print(f"  [-] Connection with BLEDevice handle failed: {type(e).__name__}: {e}")
        if client_target != TARGET:
            print(f"  [*] Attempting direct connection by MAC string: {TARGET}...")
            try:
                client = BleakClient(TARGET, timeout=30.0)
                await client.connect()
                connected = client.is_connected
                print(f"  [+] CONNECTED via MAC! MTU: {client.mtu_size}")
            except Exception as e2:
                print(f"  [-] MAC direct connection failed: {type(e2).__name__}: {e2}")

    if not connected or not client or not client.is_connected:
        print("\n[FAILED] Could not establish BLE connection.")
        print("Please verify:")
        print("  1. Band is awake and near PC")
        print("  2. Disconnected from phone / other devices")
        print("  3. Windows Bluetooth toggle cycled if needed")
        return

    # Connection succeeded!
    try:
        print(f"\n[3/3] Inspecting Heart Rate GATT Service...")
        
        # Check Sensor Location
        try:
            loc_val = await client.read_gatt_char(HR_LOCATION_UUID)
            loc_map = {0: "Other", 1: "Chest", 2: "Wrist", 3: "Finger", 4: "Hand", 5: "Ear Lobe", 6: "Foot"}
            loc_str = loc_map.get(loc_val[0], f"Unknown ({loc_val[0]})")
            print(f"  Sensor Location: {loc_str}")
        except Exception as le:
            print(f"  Sensor Location read error: {le}")

        samples = []
        raw_packets = []
        t_start = time.time()
        
        print(f"\n[STREAM] Subscribing to HR notifications for 30 seconds...")
        print(f"  {'Time':>6}  {'BPM':>5}  {'Contact':>8}  {'RR (s)':>14}  {'Raw Hex'}")
        print(f"  {'------':>6}  {'-----':>5}  {'-------':>8}  {'------':>14}  {'-------'}")

        def hr_handler(sender, data: bytearray):
            raw_bytes = bytes(data)
            bpm, contact, rr, raw_hex = parse_hr(raw_bytes)
            elapsed = time.time() - t_start
            samples.append({
                "time": round(elapsed, 2),
                "bpm": bpm,
                "contact": contact,
                "rr": rr,
                "raw": raw_hex
            })
            contact_str = "Yes" if contact is True else ("No" if contact is False else "N/A")
            rr_str = ",".join(f"{r:.3f}" for r in rr) if rr else "-"
            print(f"  {elapsed:5.1f}s  {bpm:5d}  {contact_str:>8}  {rr_str:>14}  {raw_hex}")

        await client.start_notify(HR_MEASUREMENT_UUID, hr_handler)
        
        # Monitor for 30s
        for _ in range(30):
            await asyncio.sleep(1.0)
            
        await client.stop_notify(HR_MEASUREMENT_UUID)
        print("\n[STREAM] Subscription stopped.")

        # Summary
        print("\n" + "=" * 60)
        print(" RESULTS SUMMARY")
        print("=" * 60)
        print(f"Total HR Packets Received: {len(samples)}")
        valid_bpms = [s["bpm"] for s in samples if s["bpm"] > 0]
        if valid_bpms:
            print(f"Heart Rate range: {min(valid_bpms)} - {max(valid_bpms)} BPM (Avg: {sum(valid_bpms)/len(valid_bpms):.1f})")
            print("[SUCCESS] Live Heart Rate streaming is fully operational over standard BLE GATT!")
        elif samples:
            print("[INFO] Packets received, but BPM was 0 (sensor may not be touching skin).")
        else:
            print("[NOTE] No packets arrived during 30s. Continuous HR or workout mode might be required.")

        # Save results to JSON file
        out_path = os.path.join(os.path.dirname(__file__), "fit3_hr_live_result.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({
                "target": TARGET,
                "connected": True,
                "samples_count": len(samples),
                "samples": samples
            }, f, indent=2)
        print(f"\nSaved live data log to: {out_path}")

    finally:
        print("\nDisconnecting...")
        try:
            await client.disconnect()
            print("Disconnected cleanly.")
        except Exception as de:
            print(f"Disconnect error: {de}")

if __name__ == "__main__":
    asyncio.run(main())
