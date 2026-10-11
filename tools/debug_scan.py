"""Debug scan — list ALL BLE devices found."""
import asyncio
from bleak import BleakScanner

async def main():
    print("Scanning ALL BLE devices for 12 seconds...\n")
    
    found = {}
    def callback(device, adv_data):
        found[device.address] = (device, adv_data)
    
    scanner = BleakScanner(detection_callback=callback)
    await scanner.start()
    await asyncio.sleep(12.0)
    await scanner.stop()
    
    print(f"Found {len(found)} devices:\n")
    for addr, (dev, adv) in sorted(found.items()):
        name = dev.name or adv.local_name or "<unnamed>"
        fit3 = " *** FIT3 ***" if "fit3" in (name or "").lower() or "galaxy" in (name or "").lower() else ""
        samsung = " [Samsung]" if "74:19:0A" in addr.upper() else ""
        mfg = {f"0x{k:04X}": v.hex() for k, v in adv.manufacturer_data.items()} if adv.manufacturer_data else {}
        svcs = [str(s) for s in adv.service_uuids] if adv.service_uuids else []
        print(f"  {addr} | RSSI: {adv.rssi:4d} | Name: '{name}'{fit3}{samsung}")
        if mfg:
            print(f"    Manufacturer: {mfg}")
        if svcs:
            print(f"    Services: {svcs}")
        print()

if __name__ == "__main__":
    asyncio.run(main())
