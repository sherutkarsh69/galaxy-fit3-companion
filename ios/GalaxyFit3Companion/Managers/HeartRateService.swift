import Foundation
import CoreBluetooth
import Combine

@MainActor
public final class HeartRateService: ObservableObject {
    public static let serviceUUID = CBUUID(string: "180D")
    public static let measurementCharUUID = CBUUID(string: "2A37")
    public static let bodySensorLocationCharUUID = CBUUID(string: "2A38")
    public static let controlPointCharUUID = CBUUID(string: "2A39")

    @Published public private(set) var latestHeartRate: HeartRateSample?
    @Published public private(set) var heartRateHistory: [HeartRateSample] = []
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var sensorContactDetected: Bool = false
    @Published public private(set) var bodySensorLocation: String = "Unknown"

    private let maxHistoryCount = 60
    private var hrCharacteristic: CBCharacteristic?

    public init() {}

    public func configure(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let isMeasurement = characteristic.uuid == Self.measurementCharUUID || characteristic.uuid.uuidString.uppercased().contains("2A37")
        let isLocation = characteristic.uuid == Self.bodySensorLocationCharUUID || characteristic.uuid.uuidString.uppercased().contains("2A38")

        if isMeasurement {
            self.hrCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            self.isMonitoring = true
            LogStore.shared.log(
                level: .info,
                category: "HeartRateService",
                message: "Subscribed to Heart Rate Measurement (0x2A37)"
            )
        } else if isLocation {
            peripheral.readValue(for: characteristic)
        }
    }

    public func handleNotificationStateUpdate(characteristic: CBCharacteristic) {
        let isMeasurement = characteristic.uuid == Self.measurementCharUUID || characteristic.uuid.uuidString.uppercased().contains("2A37")
        if isMeasurement {
            self.isMonitoring = characteristic.isNotifying
            LogStore.shared.log(
                level: .info,
                category: "HeartRateService",
                message: "Heart Rate notification state updated: \(characteristic.isNotifying)"
            )
        }
    }

    public func handleValueUpdate(characteristic: CBCharacteristic, peripheralName: String = "Galaxy Fit3") {
        guard let data = characteristic.value else { return }

        let isMeasurement = characteristic.uuid == Self.measurementCharUUID || characteristic.uuid.uuidString.uppercased().contains("2A37")
        let isLocation = characteristic.uuid == Self.bodySensorLocationCharUUID || characteristic.uuid.uuidString.uppercased().contains("2A38")

        if isMeasurement {
            self.isMonitoring = true
            if let sample = HeartRateSample(from: data, source: peripheralName) {
                self.latestHeartRate = sample
                self.sensorContactDetected = sample.sensorContact
                self.heartRateHistory.append(sample)
                if self.heartRateHistory.count > maxHistoryCount {
                    self.heartRateHistory.removeFirst(self.heartRateHistory.count - maxHistoryCount)
                }
                DataStore.shared.saveHeartRateSample(sample)
                LogStore.shared.log(
                    level: .info,
                    category: "HeartRateService",
                    message: "BPM: \(sample.bpm), Contact: \(sample.sensorContact), Energy: \(sample.energyExpended?.description ?? "nil")",
                    rawData: data
                )
            } else {
                LogStore.shared.log(
                    level: .warning,
                    category: "HeartRateService",
                    message: "Failed to parse Heart Rate packet of \(data.count) bytes",
                    rawData: data
                )
            }
        } else if isLocation {
            parseBodySensorLocation(data)
        }
    }

    private func parseBodySensorLocation(_ data: Data) {
        guard !data.isEmpty else { return }
        let code = data[0]
        let location: String
        switch code {
        case 0: location = "Other"
        case 1: location = "Chest"
        case 2: location = "Wrist"
        case 3: location = "Finger"
        case 4: location = "Hand"
        case 5: location = "Ear Lobe"
        case 6: location = "Foot"
        default: location = "Reserved (\(code))"
        }
        self.bodySensorLocation = location
        LogStore.shared.log(
            level: .info,
            category: "HeartRateService",
            message: "Body Sensor Location: \(location) (code: \(code))"
        )
    }

    public func resetEnergyExpended(peripheral: CBPeripheral) {
        guard let char = peripheral.services?
            .first(where: { $0.uuid == Self.serviceUUID })?
            .characteristics?
            .first(where: { $0.uuid == Self.controlPointCharUUID }) else {
            LogStore.shared.log(
                level: .warning,
                category: "HeartRateService",
                message: "HR Control Point (0x2A39) not available to reset energy"
            )
            return
        }
        let resetCommand = Data([0x01])
        peripheral.writeValue(resetCommand, for: char, type: .withResponse)
        LogStore.shared.log(
            level: .info,
            category: "HeartRateService",
            message: "Sent reset energy expended command to 0x2A39"
        )
    }

    public func setMonitoring(_ enabled: Bool, peripheral: CBPeripheral?) {
        guard let peripheral = peripheral, let char = hrCharacteristic else { return }
        peripheral.setNotifyValue(enabled, for: char)
        self.isMonitoring = enabled
    }

    public func reset() {
        self.latestHeartRate = nil
        self.heartRateHistory.removeAll()
        self.isMonitoring = false
        self.sensorContactDetected = false
        self.bodySensorLocation = "Unknown"
        self.hrCharacteristic = nil
    }
}
