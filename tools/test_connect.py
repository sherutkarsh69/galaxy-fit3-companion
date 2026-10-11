"""Galaxy Fit3 connection test — uses callback scanner + extended connection attempts."""
import asyncio
from bleak import BleakClient, BleakScanner
from bleak.exc import BleakError

TARGET_MAC = "74:19:0A:A5:39:8C"

async def main():
    # Step 1: Find device using callback scanner (proven to work)
    print("[1/3] Scanning with callback scanner (12s)...")
    found = {}
    def callback(device, adv_data):
        found[device.address.upper()] = (device, adv_data)
    
    scanner = BleakScanner(detection_callback=callback)
    await scanner.start()
    await asyncio.sleep(12.0)
    await scanner.stop()
    
    if TARGET_MAC not in found:
        print(f"  ERROR: {TARGET_MAC} not found among {len(found)} devices.")
        return
    
    device, adv = found[TARGET_MAC]
    print(f"  Found: {device.name or adv.local_name} ({device.address}) RSSI={adv.rssi}")
    
    # Step 2: Try connection — attempt 1: BLEDevice object, 30s timeout
    print(f"\n[2/3] Connecting via BLEDevice (timeout=30s)...")
    try:
        client = BleakClient(device, timeout=30.0)
        await client.connect()
        print(f"  CONNECTED! MTU={client.mtu_size}")
    except Exception as e:
        print(f"  Attempt 1 failed: {type(e).__name__}: {e}")
        
        # Attempt 2: MAC string
        print(f"\n[2b/3] Connecting via MAC string (timeout=30s)...")
        try:
            client = BleakClient(TARGET_MAC, timeout=30.0)
            await client.connect()
            print(f"  CONNECTED via MAC! MTU={client.mtu_size}")
        except Exception as e2:
            print(f"  Attempt 2 failed: {type(e2).__name__}: {e2}")
            
            # Attempt 3: Pair first via Windows, then connect
            print(f"\n[2c/3] Trying to pair first, then connect...")
            try:
                client = BleakClient(device, timeout=30.0)
                paired = await client.pair()
                print(f"  Pair result: {paired}")
                if not client.is_connected:
                    await client.connect()
                print(f"  CONNECTED after pairing! MTU={client.mtu_size}")
            except Exception as e3:
                print(f"  Attempt 3 failed: {type(e3).__name__}: {e3}")
                print(f"\n  ALL CONNECTION METHODS FAILED.")
                print(f"  The Galaxy Fit3 may require initial provisioning via Samsung Galaxy Wearable")
                print(f"  before it accepts BLE GATT connections from non-Samsung devices.")
                print(f"  Try: reconnect the band to Samsung Health on your phone first,")
                print(f"  then disconnect and retry the scanner.")
                return
    
    # Step 3: If connected, enumerate GATT
    if client.is_connected:
        print(f"\n[3/3] Enumerating GATT services...")
        for service in client.services:
            print(f"\n  SERVICE: {service.uuid}")
            print(f"    Description: {service.description}")
            for char in service.characteristics:
                props = ", ".join(char.properties)
                print(f"    CHAR: {char.uuid} [{props}]")
                print(f"      Description: {char.description}")
                if "read" in char.properties:
                    try:
                        val = await client.read_gatt_char(char)
                        print(f"      Value: 0x{val.hex().upper()} ({len(val)} bytes)")
                        try:
                            text = val.decode('utf-8', errors='replace').strip('\x00')
                            if text and all(32 <= ord(c) < 127 for c in text):
                                print(f"      Text:  '{text}'")
                        except:
                            pass
                    except Exception as re:
                        print(f"      Read Error: {type(re).__name__}: {re}")
        
        await client.disconnect()
        print(f"\nDisconnected. GATT enumeration complete!")
    
if __name__ == "__main__":
    asyncio.run(main())
