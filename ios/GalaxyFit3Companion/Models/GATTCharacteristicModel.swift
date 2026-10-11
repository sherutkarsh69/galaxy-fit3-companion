import Foundation
import CoreBluetooth

public struct GATTCharacteristicModel: Identifiable, Equatable, Hashable {
    public let id: String
    public let serviceUUID: CBUUID
    public let characteristicUUID: CBUUID
    public let serviceName: String
    public let characteristicName: String
    public let properties: [String]
    public var rawValue: Data?
    public var stringValue: String?
    public var lastUpdated: Date?

    public init(
        serviceUUID: CBUUID,
        characteristicUUID: CBUUID,
        serviceName: String,
        characteristicName: String,
        properties: [String],
        rawValue: Data? = nil,
        stringValue: String? = nil,
        lastUpdated: Date? = nil
    ) {
        self.id = "\(serviceUUID.uuidString)_\(characteristicUUID.uuidString)"
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.serviceName = serviceName
        self.characteristicName = characteristicName
        self.properties = properties
        self.rawValue = rawValue
        self.stringValue = stringValue
        self.lastUpdated = lastUpdated
    }

    public var hexString: String {
        guard let data = rawValue, !data.isEmpty else { return "None" }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

public struct GATTServiceModel: Identifiable, Equatable {
    public let id: String
    public let serviceUUID: CBUUID
    public let serviceName: String
    public let isPrimary: Bool
    public var characteristics: [GATTCharacteristicModel]

    public init(
        serviceUUID: CBUUID,
        serviceName: String,
        isPrimary: Bool = true,
        characteristics: [GATTCharacteristicModel] = []
    ) {
        self.id = serviceUUID.uuidString
        self.serviceUUID = serviceUUID
        self.serviceName = serviceName
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}
