import Foundation
import SwiftData

@Model
public final class StoredHeartRateSample {
    @Attribute(.unique) public var id: UUID
    public var bpm: Int
    public var sensorContact: Bool
    public var energyExpended: Int?
    public var rrIntervalsJSON: String?
    public var timestamp: Date
    public var source: String
    public var isSyncedToHealthKit: Bool

    public init(
        id: UUID = UUID(),
        bpm: Int,
        sensorContact: Bool,
        energyExpended: Int? = nil,
        rrIntervals: [Double]? = nil,
        timestamp: Date = Date(),
        source: String = "Galaxy Fit3",
        isSyncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.bpm = bpm
        self.sensorContact = sensorContact
        self.energyExpended = energyExpended
        if let rrIntervals = rrIntervals, let data = try? JSONEncoder().encode(rrIntervals) {
            self.rrIntervalsJSON = String(data: data, encoding: .utf8)
        } else {
            self.rrIntervalsJSON = nil
        }
        self.timestamp = timestamp
        self.source = source
        self.isSyncedToHealthKit = isSyncedToHealthKit
    }

    public var rrIntervals: [Double]? {
        guard let json = rrIntervalsJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }

    public func toModel() -> HeartRateSample {
        return HeartRateSample(
            id: id,
            bpm: bpm,
            sensorContact: sensorContact,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals,
            timestamp: timestamp,
            source: source
        )
    }
}

@Model
public final class StoredDevice {
    @Attribute(.unique) public var identifierString: String
    public var name: String
    public var macAddress: String?
    public var firmwareVersion: String?
    public var hardwareVersion: String?
    public var manufacturerName: String?
    public var modelNumber: String?
    public var serialNumber: String?
    public var softwareVersion: String?
    public var lastConnected: Date?
    public var isFavorite: Bool

    public init(
        identifierString: String,
        name: String,
        macAddress: String? = nil,
        firmwareVersion: String? = nil,
        hardwareVersion: String? = nil,
        manufacturerName: String? = nil,
        modelNumber: String? = nil,
        serialNumber: String? = nil,
        softwareVersion: String? = nil,
        lastConnected: Date? = nil,
        isFavorite: Bool = true
    ) {
        self.identifierString = identifierString
        self.name = name
        self.macAddress = macAddress
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.manufacturerName = manufacturerName
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.softwareVersion = softwareVersion
        self.lastConnected = lastConnected
        self.isFavorite = isFavorite
    }
}

@Model
public final class ConnectionEvent {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var eventType: String
    public var deviceName: String
    public var details: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        deviceName: String,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.deviceName = deviceName
        self.details = details
    }
}

@MainActor
public final class DataStore: ObservableObject {
    public static let shared = DataStore()

    public let modelContainer: ModelContainer
    public var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public init(inMemory: Bool = false) {
        let schema = Schema([
            StoredHeartRateSample.self,
            StoredDevice.self,
            ConnectionEvent.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Heart Rate CRUD

    public func saveHeartRateSample(_ sample: HeartRateSample, syncedToHK: Bool = false) {
        let stored = StoredHeartRateSample(
            id: sample.id,
            bpm: sample.bpm,
            sensorContact: sample.sensorContact,
            energyExpended: sample.energyExpended,
            rrIntervals: sample.rrIntervals,
            timestamp: sample.timestamp,
            source: sample.source,
            isSyncedToHealthKit: syncedToHK
        )
        modelContext.insert(stored)
        try? modelContext.save()
    }

    public func markSampleSynced(id: UUID) {
        var descriptor = FetchDescriptor<StoredHeartRateSample>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        if let samples = try? modelContext.fetch(descriptor), let sample = samples.first {
            sample.isSyncedToHealthKit = true
            try? modelContext.save()
        }
    }

    public func fetchHeartRateSamples(since date: Date) -> [StoredHeartRateSample] {
        let descriptor = FetchDescriptor<StoredHeartRateSample>(
            predicate: #Predicate { $0.timestamp >= date },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchRecentHeartRateSamples(limit: Int = 100) -> [StoredHeartRateSample] {
        var descriptor = FetchDescriptor<StoredHeartRateSample>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchTodayStats() -> (minBPM: Int, maxBPM: Int, avgBPM: Int, count: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let samples = fetchHeartRateSamples(since: startOfDay)
        guard !samples.isEmpty else {
            return (0, 0, 0, 0)
        }
        let bpms = samples.map { $0.bpm }
        let minB = bpms.min() ?? 0
        let maxB = bpms.max() ?? 0
        let avgB = bpms.reduce(0, +) / bpms.count
        return (minB, maxB, avgB, bpms.count)
    }

    // MARK: - Device CRUD

    public func saveOrUpdateDevice(_ device: Fit3Device) {
        let idStr = device.id.uuidString
        var descriptor = FetchDescriptor<StoredDevice>(
            predicate: #Predicate { $0.identifierString == idStr }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor), let item = existing.first {
            item.name = device.name
            if let mac = device.macAddress { item.macAddress = mac }
            if let fw = device.firmwareVersion { item.firmwareVersion = fw }
            if let hw = device.hardwareVersion { item.hardwareVersion = hw }
            if let mf = device.manufacturerName { item.manufacturerName = mf }
            if let mn = device.modelNumber { item.modelNumber = mn }
            if let sn = device.serialNumber { item.serialNumber = sn }
            if let sw = device.softwareVersion { item.softwareVersion = sw }
            item.lastConnected = Date()
        } else {
            let newItem = StoredDevice(
                identifierString: idStr,
                name: device.name,
                macAddress: device.macAddress,
                firmwareVersion: device.firmwareVersion,
                hardwareVersion: device.hardwareVersion,
                manufacturerName: device.manufacturerName,
                modelNumber: device.modelNumber,
                serialNumber: device.serialNumber,
                softwareVersion: device.softwareVersion,
                lastConnected: Date(),
                isFavorite: true
            )
            modelContext.insert(newItem)
        }
        try? modelContext.save()
    }

    public func fetchLatestDevice() -> StoredDevice? {
        var descriptor = FetchDescriptor<StoredDevice>(
            sortBy: [SortDescriptor(\.lastConnected, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Connection Events

    public func recordConnectionEvent(type: String, deviceName: String, details: String? = nil) {
        let event = ConnectionEvent(eventType: type, deviceName: deviceName, details: details)
        modelContext.insert(event)
        try? modelContext.save()
    }

    public func fetchRecentEvents(limit: Int = 50) -> [ConnectionEvent] {
        var descriptor = FetchDescriptor<ConnectionEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Data Retention & Cleanup

    public func purgeOldRecords(olderThanDays days: Int = 30) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        
        let hrDescriptor = FetchDescriptor<StoredHeartRateSample>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        if let oldHRs = try? modelContext.fetch(hrDescriptor) {
            for item in oldHRs {
                modelContext.delete(item)
            }
        }

        let eventDescriptor = FetchDescriptor<ConnectionEvent>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        if let oldEvents = try? modelContext.fetch(eventDescriptor) {
            for item in oldEvents {
                modelContext.delete(item)
            }
        }
        try? modelContext.save()
    }

    public func clearAllData() {
        if let allHR = try? modelContext.fetch(FetchDescriptor<StoredHeartRateSample>()) {
            for item in allHR { modelContext.delete(item) }
        }
        if let allDevs = try? modelContext.fetch(FetchDescriptor<StoredDevice>()) {
            for item in allDevs { modelContext.delete(item) }
        }
        if let allEvents = try? modelContext.fetch(FetchDescriptor<ConnectionEvent>()) {
            for item in allEvents { modelContext.delete(item) }
        }
        try? modelContext.save()
    }

    public func exportAllJSON() -> String {
        let samples = fetchRecentHeartRateSamples(limit: 5000)
        let sampleModels = samples.map { $0.toModel() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sampleModels),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonStr
    }
}
