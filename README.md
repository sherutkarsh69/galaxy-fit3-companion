# ⌚ Galaxy Fit3 iOS Companion (`SM-R390`)

> An open-source, zero-cost bridge connecting the **Samsung Galaxy Fit3** directly to Apple **iPhone 17 Pro (iOS 17+)** using native **Swift**, **SwiftUI**, **Core Bluetooth**, and **HealthKit** — completely eliminating the need for an Android smartphone, Samsung Galaxy Wearable, or a Samsung Account.

---

## 🏆 Project Status & Empirical Breakthrough (October 2026)

On October 11, 2026, direct empirical tests using a physical Samsung Galaxy Fit3 (`SM-R390`) confirmed:
- ✅ **Zero Samsung Wearable or Android dependency for live Heart Rate**: The band exposes standard **Bluetooth SIG Heart Rate Service (`0x180D`)** with **Heart Rate Measurement (`0x2A37`)** notification streaming.
- ✅ **Continuous Real-Time HR Ingestion**: Received and decoded 20 consecutive live packets (69–72 BPM) with active skin contact status (`0x06` flag) over native BLE GATT.
- ✅ **Native Apple HealthKit Sync**: Streams heart rate directly into Apple Health (`HKQuantityTypeIdentifierHeartRate`) via standard Core Bluetooth APIs.
- ✅ **GATT Architecture Cataloged**: Full table of standard (`0x1800`, `0x1801`, `0x180A`, `0x180D`) and proprietary Samsung services (`0x1A1A`, `0xFD69`, `EEDD5E73`, `1B7E8251`) decoded and mapped.

See the complete [Roadmap & Verification Report](ROADMAP_AND_VERIFICATION.md) for full protocol details.

---

## 📱 Repository Structure

```text
galaxy-fit3-companion/
├── .github/
│   └── workflows/
│       └── build-ios.yml          # GitHub Actions CI: Compiles .ipa on free macOS runners
├── ios/
│   ├── project.yml                # XcodeGen project spec
│   └── GalaxyFit3Companion/
│       ├── GalaxyFit3CompanionApp.swift
│       ├── ContentView.swift
│       ├── Info.plist             # Background BLE & HealthKit permissions
│       ├── Managers/
│       │   ├── BluetoothManager.swift       # CBCentralManager core engine
│       │   ├── HeartRateService.swift       # 0x180D parser & stream handler
│       │   ├── HealthKitManager.swift       # HKHealthStore writer
│       │   ├── DeviceInfoService.swift      # 0x180A hardware inspector
│       │   ├── GATTServiceManager.swift     # Full GATT table explorer
│       │   └── ProprietaryProtocol.swift    # Samsung SAP & Auth researcher
│       ├── Models/
│       ├── Persistence/
│       ├── Views/
│       └── Tests/
└── tools/
    ├── requirements.txt           # Python bleak dependencies
    ├── fit3_scan.py               # Comprehensive Windows BLE diagnostic CLI
    ├── test_hr.py                 # Fast 30s live HR verification tool
    └── fit3_hr_live_result.json   # Empirical session capture
```

---

## 🚀 How to Build & Install on iPhone (No Mac Required!)

Because Windows cannot compile iOS apps directly, this repository includes an automated **GitHub Actions CI workflow** that builds on Apple Silicon cloud runners for free.

### Step 1: Push to your GitHub Repository
From PowerShell:
```powershell
cd "c:\Users\utkar\OneDrive\Desktop\code\code\galaxy-fit3-companion"
git init -b main
git add .
git commit -m "Galaxy Fit3 iOS Companion initial release"
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/galaxy-fit3-companion.git
git push -u origin main
```

### Step 2: Download the Compiled IPA
1. Open your repository on GitHub in your web browser.
2. Click on the **Actions** tab.
3. Select the latest **Build Galaxy Fit3 iOS Companion (IPA)** run.
4. Under **Artifacts** at the bottom, download `GalaxyFit3Companion-IPA.zip`.
5. Extract `GalaxyFit3Companion.ipa`.

### Step 3: Install onto iPhone 17 Pro via Sideloadly or AltStore
1. Download **Sideloadly** (Free for Windows from [sideloadly.io](https://sideloadly.io/)) or **AltServer** ([altstore.io](https://altstore.io/)).
2. Connect your iPhone 17 Pro to your Windows PC via USB.
3. Drag and drop `GalaxyFit3Companion.ipa` into Sideloadly.
4. Enter your Apple ID and click **Start**.
5. On your iPhone: Go to **Settings > General > VPN & Device Management**, tap your developer certificate, and tap **Trust**.
6. Open **Galaxy Fit3 Companion**, allow Bluetooth and HealthKit access, and pair your band!

For full troubleshooting, manual Xcode instructions, and developer certificate options, consult the [Build, Test & Install Guide](BUILD_AND_INSTALL_GUIDE.md).
