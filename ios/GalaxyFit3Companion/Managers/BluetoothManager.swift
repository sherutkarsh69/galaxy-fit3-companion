import Foundation
import CoreBluetooth
import Combine

@MainActor
public final class BluetoothManager: NSObject, ObservableObject {
    public static let shared = BluetoothManager()

    // MARK: - Published Properties
    @Published public private(set) var connectionState: ConnectionState = .idle
    @Published public private(set) var discoveredDevices: [Fit3Device] = []
    @Published public private(set) var connectedDevice: Fit3Device?
    @Published public private(set) var rssi: Int = -100
    @Published public private(set) var isScanning: Bool = false
    @Published public var autoReconnect: Bool = true {
        didSet {
            UserDefaults.standard.set(autoReconnect, forKey: "fit3_auto_reconnect")
        }
    }

    // Sub-service managers
    public let heartRateService = HeartRateService()
    public let deviceInfoService = DeviceInfoService()
    public let gattServiceManager = GATTServiceManager()
    public let proprietaryProtocol = ProprietaryProtocol()

    // MARK: - Private State
    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var scanTimer: Timer?
    private var connectionTimeoutTimer: Timer?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private var lastTargetPeripheralUUID: UUID?
    private let restoreIdentifier = "com.galaxyfit3companion.bluetooth.restore"
    private let knownSavedUUIDKey = "fit3_last_connected_device_uuid"

    public override init() {
        super.init()
        self.autoReconnect = UserDefaults.standard.object(forKey: "fit3_auto_reconnect") as? Bool ?? true
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    deinit {
        scanTimer?.invalidate()
        connectionTimeoutTimer?.invalidate()
        if let peripheral = activePeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - Public Actions

    public func startScanning(timeout: TimeInterval = 15.0) {
        guard centralManager.state == .poweredOn else {
            LogStore.shared.log(
                level: .warning,
                category: "BluetoothManager",
                message: "Cannot scan: Bluetooth is in state \(centralManager.state.rawValue)"
            )
            updateState(.error("Bluetooth is not powered on"))
            return
        }

        updateState(.scanning)
        isScanning = true
        discoveredDevices.removeAll()

        // Scan for devices advertising Heart Rate Service (0x180D) or all nearby devices
        let servicesToScan: [CBUUID] = [HeartRateService.serviceUUID]
        centralManager.scanForPeripherals(
            withServices: servicesToScan,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "Started BLE scanning with timeout \(Int(timeout))s"
        )

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
                if self?.connectionState == .scanning {
                    self?.updateState(.idle)
                }
            }
        }
    }

    public func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        if isScanning {
            centralManager.stopScan()
            isScanning = false
            LogStore.shared.log(
                level: .info,
                category: "BluetoothManager",
                message: "Stopped BLE scanning"
            )
        }
    }

    public func connect(to device: Fit3Device) {
        stopScanning()
        self.retryCount = 0
        self.lastTargetPeripheralUUID = device.id
        UserDefaults.standard.set(device.id.uuidString, forKey: knownSavedUUIDKey)

        let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [device.id])
        if let target = knownPeripherals.first {
            initiateConnection(to: target)
        } else {
            LogStore.shared.log(
                level: .warning,
                category: "BluetoothManager",
                message: "Target peripheral not cached by CBCentralManager, scanning..."
            )
            startScanning()
        }
    }

    public func disconnect() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        retryCount = 0
        lastTargetPeripheralUUID = nil
        UserDefaults.standard.removeObject(forKey: knownSavedUUIDKey)

        if let peripheral = activePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        updateState(.disconnected)
    }

    public func reconnectToSavedDevice() {
        guard let uuidString = UserDefaults.standard.string(forKey: knownSavedUUIDKey),
              let uuid = UUID(uuidString: uuidString) else {
            return
        }
        self.lastTargetPeripheralUUID = uuid
        let retrieved = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let target = retrieved.first {
            initiateConnection(to: target)
        }
    }

    // MARK: - Internal Helpers

    private func initiateConnection(to peripheral: CBPeripheral) {
        self.activePeripheral = peripheral
        peripheral.delegate = self
        updateState(.connecting)

        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "Initiating connection to \(peripheral.name ?? "Fit3") [\(peripheral.identifier)]"
        )

        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ])

        startConnectionTimeout()
    }

    private func startConnectionTimeout(duration: TimeInterval = 10.0) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleConnectionTimeout()
            }
        }
    }

    private func handleConnectionTimeout() {
        LogStore.shared.log(
            level: .error,
            category: "BluetoothManager",
            message: "Connection timed out"
        )
        if let peripheral = activePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        attemptRetryOrError(message: "Connection timed out")
    }

    private func attemptRetryOrError(message: String) {
        if retryCount < maxRetries, let uuid = lastTargetPeripheralUUID, autoReconnect {
            retryCount += 1
            let delay = pow(2.0, Double(retryCount)) // exponential backoff: 2s, 4s, 8s
            LogStore.shared.log(
                level: .warning,
                category: "BluetoothManager",
                message: "Retrying connection in \(Int(delay))s (Attempt \(retryCount)/\(maxRetries))"
            )
            updateState(.connecting)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let retrieved = self.centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let target = retrieved.first {
                    self.initiateConnection(to: target)
                }
            }
        } else {
            updateState(.error(message))
        }
    }

    private func updateState(_ newState: ConnectionState) {
        self.connectionState = newState
        let devName = connectedDevice?.name ?? activePeripheral?.name ?? "Unknown Device"
        DataStore.shared.recordConnectionEvent(type: newState.statusText, deviceName: devName)
        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "State transitioned to: \(newState.statusText)"
        )
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            LogStore.shared.log(level: .info, category: "BluetoothManager", message: "Bluetooth powered on")
            if autoReconnect && connectedDevice == nil {
                reconnectToSavedDevice()
            }
        case .poweredOff:
            LogStore.shared.log(level: .warning, category: "BluetoothManager", message: "Bluetooth powered off")
            updateState(.error("Bluetooth is turned off"))
        case .unauthorized:
            LogStore.shared.log(level: .error, category: "BluetoothManager", message: "Bluetooth unauthorized")
            updateState(.error("Bluetooth permission denied"))
        case .unsupported:
            LogStore.shared.log(level: .error, category: "BluetoothManager", message: "Bluetooth unsupported")
            updateState(.error("BLE unsupported on this hardware"))
        case .resetting:
            LogStore.shared.log(level: .warning, category: "BluetoothManager", message: "Bluetooth is resetting")
            updateState(.connecting)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "State restoration invoked by iOS background system"
        )
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restoredPeripheral = peripherals.first {
            self.activePeripheral = restoredPeripheral
            restoredPeripheral.delegate = self
            self.connectedDevice = Fit3Device(
                id: restoredPeripheral.identifier,
                name: restoredPeripheral.name ?? "Galaxy Fit3",
                lastConnected: Date()
            )
            updateState(.connected)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? "Unknown Device"

        // Filter / map advertisement dictionary summary
        var adSummary: [String: String] = [:]
        for (k, v) in advertisementData {
            adSummary[k] = String(describing: v)
        }

        let device = Fit3Device(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            lastConnected: nil,
            advertisementDataSummary: adSummary
        )

        if let idx = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[idx] = device
        } else {
            discoveredDevices.append(device)
            LogStore.shared.log(
                level: .info,
                category: "BluetoothManager",
                message: "Discovered: \(device.name) (\(device.id)), RSSI: \(RSSI)"
            )
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        retryCount = 0

        self.rssi = -60
        self.connectedDevice = Fit3Device(
            id: peripheral.identifier,
            name: peripheral.name ?? "Galaxy Fit3",
            lastConnected: Date()
        )

        updateState(.discovering)
        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "Successfully connected to \(peripheral.name ?? "Device"). Discovering services..."
        )

        peripheral.discoverServices([
            HeartRateService.serviceUUID,
            DeviceInfoService.serviceUUID,
            ProprietaryProtocol.authServiceUUID
        ])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        let errDesc = error?.localizedDescription ?? "Failed to connect"
        LogStore.shared.log(
            level: .error,
            category: "BluetoothManager",
            message: "Connection failed: \(errDesc)"
        )
        attemptRetryOrError(message: errDesc)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        let errDesc = error?.localizedDescription ?? "Device disconnected"
        LogStore.shared.log(
            level: .warning,
            category: "BluetoothManager",
            message: "Disconnected from \(peripheral.name ?? "Device"): \(errDesc)"
        )

        heartRateService.reset()
        deviceInfoService.reset()
        gattServiceManager.reset()
        proprietaryProtocol.reset()

        if autoReconnect && error != nil {
            attemptRetryOrError(message: errDesc)
        } else {
            updateState(.disconnected)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            LogStore.shared.log(
                level: .error,
                category: "BluetoothManager",
                message: "Error discovering services: \(error.localizedDescription)"
            )
            updateState(.error("Service discovery failed"))
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            LogStore.shared.log(
                level: .warning,
                category: "BluetoothManager",
                message: "No services discovered on peripheral"
            )
            updateState(.connected)
            return
        }

        LogStore.shared.log(
            level: .info,
            category: "BluetoothManager",
            message: "Discovered \(services.count) services"
        )

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            LogStore.shared.log(
                level: .error,
                category: "BluetoothManager",
                message: "Error discovering characteristics for \(service.uuid): \(error.localizedDescription)"
            )
            return
        }

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Heart Rate Service
                if service.uuid == HeartRateService.serviceUUID {
                    heartRateService.configure(peripheral: peripheral, characteristic: characteristic)
                }

                // Device Info Service
                if service.uuid == DeviceInfoService.serviceUUID {
                    peripheral.readValue(for: characteristic)
                }

                // Proprietary Auth Service
                if service.uuid.uuidString.lowercased() == ProprietaryProtocol.authServiceUUID.uuidString.lowercased() {
                    proprietaryProtocol.configure(peripheral: peripheral, service: service)
                }
            }
        }

        if let allServices = peripheral.services {
            gattServiceManager.updateServices(from: allServices)
        }

        if connectionState == .discovering {
            updateState(.connected)
            if let dev = connectedDevice {
                DataStore.shared.saveOrUpdateDevice(dev)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            LogStore.shared.log(
                level: .error,
                category: "BluetoothManager",
                message: "Error updating value for \(characteristic.uuid): \(error.localizedDescription)"
            )
            return
        }

        // Heart rate notifications
        if characteristic.service?.uuid == HeartRateService.serviceUUID {
            heartRateService.handleValueUpdate(characteristic: characteristic, peripheralName: peripheral.name ?? "Galaxy Fit3")
        }

        // Device Info reads
        if characteristic.service?.uuid == DeviceInfoService.serviceUUID {
            deviceInfoService.handleValueUpdate(characteristic: characteristic)
            if let dev = connectedDevice {
                var updated = dev
                updated.manufacturerName = deviceInfoService.manufacturerName
                updated.modelNumber = deviceInfoService.modelNumber
                updated.serialNumber = deviceInfoService.serialNumber
                updated.hardwareVersion = deviceInfoService.hardwareRevision
                updated.firmwareVersion = deviceInfoService.firmwareRevision
                updated.softwareVersion = deviceInfoService.softwareRevision
                self.connectedDevice = updated
                DataStore.shared.saveOrUpdateDevice(updated)
            }
        }

        // Proprietary service reads
        if characteristic.service?.uuid.uuidString.lowercased() == ProprietaryProtocol.authServiceUUID.uuidString.lowercased() {
            proprietaryProtocol.handleValueUpdate(characteristic: characteristic)
        }

        gattServiceManager.updateCharacteristicValue(characteristic)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            LogStore.shared.log(
                level: .error,
                category: "BluetoothManager",
                message: "Notification state update error for \(characteristic.uuid): \(error.localizedDescription)"
            )
            return
        }

        if characteristic.service?.uuid == HeartRateService.serviceUUID {
            heartRateService.handleNotificationStateUpdate(characteristic: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            self.rssi = RSSI.intValue
        }
    }
}
