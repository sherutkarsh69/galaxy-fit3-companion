import Foundation
import HealthKit
import Combine

@MainActor
public final class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()

    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var authorizationError: String? = nil

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
    private let sleepAnalysisType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

    public init() {
        checkAuthorizationStatus()
    }

    public func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isAuthorized = false
            return
        }
        let status = healthStore.authorizationStatus(for: heartRateType)
        self.isAuthorized = (status == .sharingAuthorized)
    }

    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationError = "HealthKit is not available on this device"
            return false
        }

        let writeTypes: Set<HKSampleType> = [heartRateType]
        let readTypes: Set<HKObjectType> = [
            heartRateType,
            stepCountType,
            oxygenSaturationType,
            sleepAnalysisType
        ]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            checkAuthorizationStatus()
            LogStore.shared.log(
                level: .info,
                category: "HealthKitManager",
                message: "HealthKit authorization requested. Authorized: \(self.isAuthorized)"
            )
            return self.isAuthorized
        } catch {
            self.authorizationError = error.localizedDescription
            LogStore.shared.log(
                level: .error,
                category: "HealthKitManager",
                message: "HealthKit authorization failed: \(error.localizedDescription)"
            )
            return false
        }
    }

    /// Writes a single heart rate sample with strict duplicate prevention.
    /// Checks for existing samples within ±30s window from our app source before writing.
    public func writeHeartRateSample(_ sample: HeartRateSample) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard isAuthorized else { return false }

        // Duplicate check window: ±30 seconds
        let windowStart = sample.timestamp.addingTimeInterval(-30)
        let windowEnd = sample.timestamp.addingTimeInterval(30)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        let isDuplicate = await checkForDuplicate(predicate: predicate)
        if isDuplicate {
            LogStore.shared.log(
                level: .info,
                category: "HealthKitManager",
                message: "Skipping duplicate HR sample at \(sample.timestamp)"
            )
            return true
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: bpmUnit, doubleValue: Double(sample.bpm))
        
        var metadata: [String: Any] = [
            HKMetadataKeyDeviceSerialNumber: sample.source,
            HKMetadataKeyWasUserEntered: false
        ]
        if sample.sensorContact {
            metadata[HKMetadataKeyHeartRateSensorLocation] = HKHeartRateSensorLocation.wrist.rawValue
        }

        let hkSample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: sample.timestamp,
            end: sample.timestamp,
            metadata: metadata
        )

        do {
            try await healthStore.save(hkSample)
            self.lastSyncDate = Date()
            DataStore.shared.markSampleSynced(id: sample.id)
            LogStore.shared.log(
                level: .info,
                category: "HealthKitManager",
                message: "Successfully saved HR sample: \(sample.bpm) BPM to HealthKit"
            )
            return true
        } catch {
            LogStore.shared.log(
                level: .error,
                category: "HealthKitManager",
                message: "Failed to write HR sample to HealthKit: \(error.localizedDescription)"
            )
            return false
        }
    }

    /// Batch sync unsynced samples from DataStore
    public func syncUnsyncedSamples() async {
        guard isAuthorized else { return }
        self.isSyncing = true
        defer { self.isSyncing = false }

        let recentSamples = DataStore.shared.fetchRecentHeartRateSamples(limit: 50)
        let unsynced = recentSamples.filter { !$0.isSyncedToHealthKit }

        var successCount = 0
        for stored in unsynced {
            let model = stored.toModel()
            let ok = await writeHeartRateSample(model)
            if ok {
                successCount += 1
            }
        }

        LogStore.shared.log(
            level: .info,
            category: "HealthKitManager",
            message: "HealthKit batch sync completed. Synced \(successCount) of \(unsynced.count) samples."
        )
    }

    private func checkForDuplicate(predicate: NSPredicate) async -> Bool {
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, results, error in
                if let results = results, !results.isEmpty {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            healthStore.execute(query)
        }
    }
}
