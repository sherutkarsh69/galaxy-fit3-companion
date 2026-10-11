import Foundation

public struct Fit3Device: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var macAddress: String?
    public var rssi: Int
    public var firmwareVersion: String?
    public var hardwareVersion: String?
    public var manufacturerName: String?
    public var modelNumber: String?
    public var serialNumber: String?
    public var softwareVersion: String?
    public var lastConnected: Date?
    public var advertisementDataSummary: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        macAddress: String? = nil,
        rssi: Int = -100,
        firmwareVersion: String? = nil,
        hardwareVersion: String? = nil,
        manufacturerName: String? = nil,
        modelNumber: String? = nil,
        serialNumber: String? = nil,
        softwareVersion: String? = nil,
        lastConnected: Date? = nil,
        advertisementDataSummary: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.macAddress = macAddress
        self.rssi = rssi
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.manufacturerName = manufacturerName
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.softwareVersion = softwareVersion
        self.lastConnected = lastConnected
        self.advertisementDataSummary = advertisementDataSummary
    }

    public var isPairedInSystem: Bool = false

    public var isGalaxyFit3: Bool {
        let lower = name.lowercased()
        return lower.contains("fit3") || lower.contains("r390") || lower.contains("galaxy fit") || lower.contains("fit 3")
    }

    public var displayName: String {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Galaxy Fit3 Device"
        }
        return name
    }
}
