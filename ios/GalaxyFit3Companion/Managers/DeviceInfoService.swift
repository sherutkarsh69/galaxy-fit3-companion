import Foundation
import CoreBluetooth
import Combine

@MainActor
public final class DeviceInfoService: ObservableObject {
    public static let serviceUUID = CBUUID(string: "180A")
    public static let manufacturerNameUUID = CBUUID(string: "2A29")
    public static let modelNumberUUID      = CBUUID(string: "2A24")
    public static let serialNumberUUID     = CBUUID(string: "2A25")
    public static let hardwareRevisionUUID = CBUUID(string: "2A27")
    public static let firmwareRevisionUUID = CBUUID(string: "2A26")
    public static let softwareRevisionUUID = CBUUID(string: "2A28")

    @Published public private(set) var manufacturerName: String?
    @Published public private(set) var modelNumber: String?
    @Published public private(set) var serialNumber: String?
    @Published public private(set) var hardwareRevision: String?
    @Published public private(set) var firmwareRevision: String?
    @Published public private(set) var softwareRevision: String?
    @Published public private(set) var isServiceDiscovered: Bool = false

    public init() {}

    public func configure(peripheral: CBPeripheral, service: CBService) {
        guard service.uuid == Self.serviceUUID else { return }
        self.isServiceDiscovered = true
        LogStore.shared.log(
            level: .info,
            category: "DeviceInfoService",
            message: "Discovered Device Information Service (0x180A)"
        )
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    public func handleValueUpdate(characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        let stringVal = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? data.map { String(format: "%02X", $0) }.joined(separator: " ")

        switch characteristic.uuid {
        case Self.manufacturerNameUUID:
            self.manufacturerName = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Manufacturer: \(stringVal)")
        case Self.modelNumberUUID:
            self.modelNumber = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Model: \(stringVal)")
        case Self.serialNumberUUID:
            self.serialNumber = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Serial: \(stringVal)")
        case Self.hardwareRevisionUUID:
            self.hardwareRevision = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Hardware: \(stringVal)")
        case Self.firmwareRevisionUUID:
            self.firmwareRevision = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Firmware: \(stringVal)")
        case Self.softwareRevisionUUID:
            self.softwareRevision = stringVal
            LogStore.shared.log(level: .info, category: "DeviceInfoService", message: "Software: \(stringVal)")
        default:
            break
        }
    }

    public func reset() {
        self.manufacturerName = nil
        self.modelNumber = nil
        self.serialNumber = nil
        self.hardwareRevision = nil
        self.firmwareRevision = nil
        self.softwareRevision = nil
        self.isServiceDiscovered = false
    }
}
