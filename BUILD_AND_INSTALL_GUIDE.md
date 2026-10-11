# Samsung Galaxy Fit3 — Complete Build, Test & Install Guide

Welcome! This guide provides an end-to-end walkthrough for working with the **Galaxy Fit3 Companion Project**. Whether you are running the Windows BLE diagnostic toolkit or setting up the iOS companion app, every step is explained from first principles.

---

## Table of Contents
1. [Part 1: Windows BLE Scanner Setup](#part-1-windows-ble-scanner-setup)
   - [Prerequisites](#prerequisites)
   - [Step-by-Step PowerShell Commands](#step-by-step-powershell-commands)
   - [Troubleshooting Windows BLE](#troubleshooting-windows-ble)
2. [Part 2: iOS App Build & Installation](#part-2-ios-app-build--installation)
   - [Why macOS / Xcode is Required](#why-macos--xcode-is-required)
   - [Option A: GitHub Actions CI (Free Automated Builds)](#option-a-github-actions-ci-free-automated-builds)
   - [Option B: Xcode Cloud](#option-b-xcode-cloud)
   - [Option C: Rent or Borrow a Mac](#option-c-rent-or-borrow-a-mac)
   - [Option D: Sideloading on Windows (AltStore / SideStore)](#option-d-sideloading-on-windows-altstore--sidestore)
   - [Apple Developer Program Comparison (Free vs. $99/year)](#apple-developer-program-comparison)
   - [Step-by-Step Xcode Project Setup (macOS)](#step-by-step-xcode-project-setup-macos)
   - [Required Info.plist Configuration](#required-infoplist-configuration)
   - [Required Entitlements](#required-entitlements)
   - [Testing on a Real iPhone](#testing-on-a-real-iphone)
3. [Part 3: Galaxy Fit3 Hardware Preparation](#part-3-galaxy-fit3-hardware-preparation)
   - [Firmware & Settings](#firmware--settings)
   - [Continuous Heart Rate Configuration](#continuous-heart-rate-configuration)
   - [Bluetooth Exclusivity Rule (Crucial)](#bluetooth-exclusivity-rule-crucial)
   - [Static MAC Address Behavior](#static-mac-address-behavior)

---

# Part 1: Windows BLE Scanner Setup

The Python scanner (`tools/fit3_scan.py`) is designed for deep hardware diagnostics, BLE service enumeration, real-time Heart Rate (HRS) streaming, and Samsung proprietary protocol inspection directly from Windows 10/11.

---

### Prerequisites

1. **Python 3.11 or Higher**:
   - Check if Python is installed by running:
     ```powershell
     py --version
     ```
     *(If `py` is not recognized, try `python --version`)*.
   - If missing, download Python 3.11+ from [python.org](https://www.python.org/downloads/).
   - **Important during installation**: Check the box **"Add python.exe to PATH"**.

2. **Bluetooth 4.0+ Adapter**:
   - Built-in Bluetooth on your motherboard/laptop or an external USB Bluetooth 4.0/5.0+ LE dongle (e.g., Realtek, Intel, or CSR-based).
   - Verify Bluetooth is active in **Windows Settings > Bluetooth & devices**.

3. **PowerShell Console**:
   - Standard Windows PowerShell or PowerShell 7 running with standard or administrative privileges.

---

### Step-by-Step PowerShell Commands

Open PowerShell and follow these exact steps:

```powershell
# 1. Navigate to the project tools directory
cd "c:\Users\utkar\OneDrive\Desktop\code\code\galaxy-fit3-companion\tools"

# 2. Install required Python packages (Bleak BLE library)
py -m pip install -r requirements.txt

# 3. Basic scan (discover nearby BLE devices & verify Fit3 visibility)
py fit3_scan.py --scan-only

# 4. Full diagnostic (connect, enumerate all GATT services/characteristics, stream HR & notifications)
py fit3_scan.py

# 5. Quick HR monitoring only (stream for 30 seconds without dumping raw descriptors)
py fit3_scan.py --no-notify --hr-time 30

# 6. Direct connection by MAC address (bypasses device name discovery)
py fit3_scan.py --device "XX:XX:XX:XX:XX:XX"

# 7. Export JSON reports to a custom folder
py fit3_scan.py --output-dir "C:\Users\utkar\OneDrive\Desktop\fit3-reports"
```

---

### Troubleshooting Windows BLE

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Bluetooth adapter not found** | Bluetooth radio disabled or missing drivers | Open **Device Manager**, expand **Bluetooth**, verify your adapter is enabled. Toggle Bluetooth off and on in Windows Settings. |
| **Connection timeout** | Fit3 is actively connected to an Android phone | Samsung Galaxy Fit3 only allows **one active BLE connection**. Disable Bluetooth on your phone or unpair the Fit3 before scanning on PC. |
| **Permission denied / Access denied** | PowerShell restricted or WinRT Bluetooth access blocked | Right-click Windows Terminal/PowerShell and select **"Run as Administrator"**. Also verify Settings > Privacy & security > Radios is turned ON. |
| **No devices found** | Band is asleep, out of range, or battery is dead | Tap the Galaxy Fit3 screen to wake the display. Keep the band within 1 meter of your PC. Ensure band is not in **Do Not Disturb (DND)** or **Airplane Mode**. |
| **BleakError / Device unreachable** | Windows cached stale BLE pairing keys | Go to **Windows Settings > Bluetooth & devices > Devices**. Find "Galaxy Fit3", click the three dots, select **Remove device**. Restart Windows Bluetooth service. |
| **'py' is not recognized** | Python launcher not registered in PATH | Re-run Python installer from [python.org](https://www.python.org), choose **Modify**, and check **"Add Python to environment variables"**. |

---

# Part 2: iOS App Build & Installation

---

### Why macOS / Xcode is Required

> [!IMPORTANT]
> **Windows CANNOT natively compile Swift apps for iOS.**
> 
> Apple's iOS toolchain relies on proprietary macOS frameworks (CoreBluetooth, HealthKit, SwiftUI), the Darwin Mach-O binary format, and the Apple Code Signing subsystem. The official compiler (`xcodebuild`) and the iOS SDK are **only distributed as part of Xcode on macOS**.
> 
> There is no native version of Xcode for Windows or Linux. To get the `.ipa` onto your iPhone, you must use one of the options below.

---

### Option A: GitHub Actions CI (Free Automated Builds)

If your repository is hosted on GitHub (free for public repositories, or using free monthly GitHub Actions minutes on private repositories), you can compile the app entirely in the cloud on Apple Silicon macOS runners without owning a Mac!

A preconfigured workflow file has been created at:
[`.github/workflows/build-ios.yml`](file:///c:/Users/utkar/OneDrive/Desktop/code/code/galaxy-fit3-companion/.github/workflows/build-ios.yml)

#### How It Works:
1. When you push commits to GitHub, GitHub spins up a virtual `macos-14` runner with Xcode 15+ pre-installed.
2. The workflow verifies the Swift source code syntax, compiles the targets, and packages the artifacts.
3. You can download the compiled `.xcarchive` or app bundle directly from the **Actions** tab on GitHub.

#### Step-by-Step GitHub Actions Setup:
1. Initialize git and commit your files:
   ```powershell
   cd "c:\Users\utkar\OneDrive\Desktop\code\code\galaxy-fit3-companion"
   git init
   git add .
   git commit -m "Initial commit of Galaxy Fit3 Companion"
   ```
2. Push your project to a GitHub repository:
   ```powershell
   git remote add origin https://github.com/<your-username>/galaxy-fit3-companion.git
   git branch -M main
   git push -u origin main
   ```
3. Open your browser to `https://github.com/<your-username>/galaxy-fit3-companion/actions`.
4. Select the **Build iOS Companion App** workflow run and download the zipped artifact under **Artifacts**.

---

### Option B: Xcode Cloud

If you have an active Apple Developer Program membership ($99/year), **Xcode Cloud** is built directly into Xcode and App Store Connect:

- **25 free compute hours/month** are included with your developer subscription.
- Automatically handles digital code signing with Apple distribution certificates.
- Builds every Git push in Apple's cloud and automatically pushes the build to your physical iPhone via **TestFlight**.
- **Setup**: Open the project in Xcode on any Mac (or cloud Mac), navigate to **Product > Xcode Cloud > Create Workflow**, and link your GitHub repository.

---

### Option C: Rent or Borrow a Mac

If you only need macOS access for 30–60 minutes to generate your build:
1. **Cloud Mac Services**:
   - [MacinCloud](https://www.macincloud.com/): Pay-as-you-go or hourly Mac in the cloud accessible via standard Windows Remote Desktop (RDP).
   - [MacStadium](https://www.macstadium.com/): Dedicated Mac mini instances.
   - [Scaleway Apple Silicon](https://www.scaleway.com/en/m1-mac-mini/): Hourly rental of Apple Silicon M1/M2 Mac minis.
2. **Borrowing a Friend's / University / Library Mac**:
   - Clone your repository onto their Mac.
   - Open Xcode, plug in your iPhone with a Lightning/USB-C cable, and hit **Run** (`Cmd + R`).

---

### Option D: Sideloading on Windows (AltStore / SideStore)

You can sideload unsigned or self-signed IPAs onto your iPhone directly from Windows using **AltStore**:

#### How AltStore Works:
AltServer runs in the Windows system tray and communicates with your iPhone over your local Wi-Fi network or USB cable, using your personal Apple ID to generate a 7-day personal certificate.

#### AltStore Windows Setup:
1. **Download Prerequisites on Windows**:
   - Install **iTunes for Windows** (Direct `.exe` installer from [apple.com](https://www.apple.com/itunes/), NOT the Microsoft Store version).
   - Install **iCloud for Windows** (Direct `.exe` installer from [Apple Support](https://support.apple.com/HT204283), NOT the Microsoft Store version).
2. Download and install **AltServer** from [altstore.io](https://altstore.io).
3. Connect your iPhone to your Windows PC using a USB cable. Open iTunes and check **"Sync with this iPhone over Wi-Fi"**.
4. In the Windows taskbar, click the AltServer icon > **Install AltStore** > Select your iPhone.
5. Enter your Apple ID and password.
6. Once AltStore appears on your iPhone, go to **Settings > General > VPN & Device Management** and tap **Trust [Your Apple ID]**.
7. In AltStore on iOS, tap **+** to install the `GalaxyFit3Companion.ipa` build.

> [!NOTE]
> **Free Sideloading Caveats**:
> - Free Apple IDs expire after **7 days**, requiring AltServer on PC to auto-refresh the certificate over Wi-Fi.
> - Maximum limit of **3 active sideloaded apps** per device.
> - Certain background tasks are throttled compared to native App Store or Developer signed apps.

---

### Apple Developer Program Comparison

| Feature | Free Apple ID | Paid Program ($99/year) |
| :--- | :--- | :--- |
| **Profile Validity** | 7 days (must re-sign weekly) | **365 days (1 year)** |
| **Max Devices** | 3 apps per device | Unlimited testing devices |
| **TestFlight Distribution** | ❌ No | **✅ Yes (up to 10,000 testers)** |
| **App Store Release** | ❌ No | **✅ Yes** |
| **Background BLE Central** | Limited execution window | **Full unrestricted background runtime** |
| **HealthKit Integration** | Local testing only | Full distribution capability |

> [!TIP]
> **Why Paid is Recommended**: The Galaxy Fit3 Companion relies on continuous background Bluetooth Central connectivity (`bluetooth-central`) and Apple HealthKit sync. While free Apple IDs work for short testing sessions, a paid developer account allows the app to run continuously in the background for a full year without weekly re-signing.

---

### Step-by-Step Xcode Project Setup (macOS)

When you have access to a Mac with Xcode 15 or 16 installed:

1. **Launch Xcode**: Select **File > New > Project...**
2. **Choose Template**: Select **iOS** tab > **App** > Click **Next**.
3. **Configure Project Settings**:
   - **Product Name**: `GalaxyFit3Companion`
   - **Team**: Select your Apple Developer Account / Personal Team
   - **Organization Identifier**: `com.yourname`
   - **Bundle Identifier**: `com.yourname.galaxyfit3companion`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - Uncheck "Include Tests" (or keep checked if you want to import test targets)
   - Click **Create**.
4. **Import Project Source Files**:
   - In Finder, open `ios/GalaxyFit3Companion/`.
   - Drag the following directories and files into the Xcode Project Navigator:
     - `GalaxyFit3CompanionApp.swift`
     - `ContentView.swift`
     - `Managers/` (BluetoothManager.swift, HealthKitManager.swift, SyncManager.swift)
     - `Models/` (Fit3Device.swift, HeartRateMeasurement.swift, WorkoutRecord.swift)
     - `Persistence/` (DataPersistenceManager.swift)
     - `Views/` (DashboardView.swift, DeviceDetailView.swift, HistoryView.swift, SettingsView.swift)
   - When prompted: Check **"Copy items if needed"** and select **Create groups**.
5. **Set Minimum Deployment Target**:
   - Click on the project root in the left sidebar.
   - Under **Targets > GalaxyFit3Companion > General > Minimum Deployments**, set to **iOS 17.0**.
6. **Configure Capabilities**:
   - Navigate to the **Signing & Capabilities** tab.
   - Click **+ Capability** and add:
     - **Background Modes**: Check ✅ **Uses Bluetooth LE accessories** (`bluetooth-central`).
     - **HealthKit**: Check ✅ **Background Delivery** (if writing continuous metrics).
7. **Select Physical Device**:
   - Connect your iPhone via USB.
   - In Xcode's top toolbar, click the device selector and choose your iPhone instead of an iOS Simulator.
8. **Build and Run**:
   - Press `Cmd + R` or click the **Play** button to compile and install onto your iPhone.

---

### Required Info.plist Configuration

The file [ios/GalaxyFit3Companion/Info.plist](file:///c:/Users/utkar/OneDrive/Desktop/code/code/galaxy-fit3-companion/ios/GalaxyFit3Companion/Info.plist) contains all mandatory permission strings required by Apple. If configuring manually in Xcode, ensure these keys exist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 1. Modern Bluetooth Permission (iOS 13+) -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Galaxy Fit3 Companion needs continuous Bluetooth access to stream real-time heart rate and synchronize health telemetry in the background.</string>

    <!-- 2. Legacy Bluetooth Permission (iOS 12 and below fallback) -->
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Galaxy Fit3 Companion connects to your Samsung Galaxy Fit3 smart band over Bluetooth LE.</string>

    <!-- 3. Background Execution Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <!-- bluetooth-central: Keeps BLE connection alive when app is minimized -->
        <string>bluetooth-central</string>
    </array>

    <!-- 4. HealthKit Read Permission -->
    <key>NSHealthShareUsageDescription</key>
    <string>This app reads health activity metrics to correlate exercise data with your Galaxy Fit3 band records.</string>

    <!-- 5. HealthKit Write/Update Permission -->
    <key>NSHealthUpdateUsageDescription</key>
    <string>This app synchronizes heart rate measurements, resting metrics, and workout logs from your Galaxy Fit3 directly into Apple Health.</string>
</dict>
</plist>
```

---

### Required Entitlements

Ensure your target's `.entitlements` file includes:
1. `com.apple.developer.healthkit` set to `YES`
2. `com.apple.developer.healthkit.background-delivery` set to `YES` (optional for background writes)

---

### Testing on a Real iPhone

> [!WARNING]
> **The iOS Simulator does NOT support Bluetooth hardware passthrough.**
> Xcode's iOS Simulator cannot discover or connect to physical BLE hardware. You **MUST** run the app on a physical iPhone.

#### 1. Enable Developer Mode on iOS 16/17/18:
1. On your iPhone, open **Settings**.
2. Go to **Privacy & Security**.
3. Scroll to the bottom and select **Developer Mode**.
4. Toggle **Developer Mode ON**.
5. Tap **Restart**.
6. After restarting, unlock your iPhone and tap **Turn On**, then enter your passcode.

#### 2. Trust the Developer Certificate:
1. When you first install the app from Xcode or AltStore, opening it will show an "Untrusted Developer" prompt.
2. Open **Settings > General > VPN & Device Management**.
3. Tap on your **Apple ID** under *Developer App*.
4. Tap **Trust "[Your Apple ID]"** and confirm.
5. Launch the **GalaxyFit3Companion** app from your home screen.
6. Grant the prompted **Bluetooth** and **Apple Health** permissions.

---

# Part 3: Galaxy Fit3 Preparation

To ensure immediate pairing and continuous data streaming without interference:

---

### Firmware & Settings
1. Before unpairing from your Android phone, open the **Galaxy Wearable** app and verify the band is updated to the latest Samsung firmware.
2. Ensure the band has at least **30% battery** charge.

---

### Continuous Heart Rate Configuration
By default, the Galaxy Fit3 may measure heart rate only once every 10 minutes to preserve battery. For real-time telemetry testing:
1. On the Galaxy Fit3, swipe up to open the App drawer.
2. Tap **Settings (gear icon) > Health**.
3. Tap **Heart Rate** and select **Continuous**.
4. Alternatively, swipe through the widgets and start any workout (e.g., **"Other Workout"** or **"Walking"**), which immediately activates the high-frequency optical PPG sensor.

---

### Bluetooth Exclusivity Rule (Crucial)

```
       [Android Phone: Galaxy Wearable Active]
                        │ 
                        ▼ (Locks BLE Connection)
             [Samsung Galaxy Fit3]
                        ▲
                        │ (BLOCKED! Connection Refused)
        [Windows Scanner / iPhone App]
```

- **Bluetooth Low Energy allows only ONE Central connection at a time** on the Galaxy Fit3.
- If your Fit3 is currently connected to **Samsung Health** or the **Galaxy Wearable** app on an Android phone, it will refuse connections from Windows or iOS.
- **Before testing**:
  - Turn **OFF Bluetooth** on your Android phone, OR:
  - Put your Android phone into Airplane Mode, OR:
  - Factory reset / Unpair the Fit3 from Galaxy Wearable if dedicating it to iOS development.

---

### Static MAC Address Behavior
- Unlike many consumer smartwatches that randomize their Bluetooth MAC address every 15 minutes, the **Galaxy Fit3 maintains a static or semi-static BLE MAC address** once initialized.
- Once you locate your band's MAC address using `py fit3_scan.py --scan-only` (e.g., `58:8E:81:XX:XX:XX`), you can connect directly in future sessions without scanning delays:
  ```powershell
  py fit3_scan.py --device "58:8E:81:XX:XX:XX"
  ```
- On iOS, CoreBluetooth masks MAC addresses into system-generated UUIDs (`CBPeripheral.identifier`). The iOS app caches this UUID in `UserDefaults` via `BluetoothManager.swift` for seamless auto-reconnection whenever the band is in proximity.

---

### Summary Checklist

- [ ] **Windows**: Ran `py fit3_scan.py --scan-only` and discovered device.
- [ ] **Windows**: Ran `py fit3_scan.py --hr-time 30` to stream real-time Heart Rate.
- [ ] **Hardware**: Disabled Android Bluetooth to release the Fit3 connection.
- [ ] **Hardware**: Enabled Continuous Heart Rate on the band.
- [ ] **iOS**: Code checked into GitHub repository with Actions CI workflow configured.
- [ ] **iPhone**: Enabled Developer Mode and trusted developer certificate.
- [ ] **Xcode / AltStore**: Installed `GalaxyFit3Companion` onto physical iPhone.
