import SwiftUI
import SwiftData

@main
struct GalaxyFit3CompanionApp: App {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var dataStore = DataStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(bluetoothManager: bluetoothManager, healthKitManager: healthKitManager)
                .environmentObject(bluetoothManager)
                .environmentObject(healthKitManager)
                .environmentObject(dataStore)
                .modelContainer(dataStore.modelContainer)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            LogStore.shared.log(
                level: .info,
                category: "AppLifecycle",
                message: "App transitioned to Active foreground"
            )
            // Re-check HealthKit status and trigger pending batch sync
            Task {
                healthKitManager.checkAuthorizationStatus()
                if healthKitManager.isAuthorized {
                    await healthKitManager.syncUnsyncedSamples()
                }
            }
        case .inactive:
            LogStore.shared.log(
                level: .info,
                category: "AppLifecycle",
                message: "App transitioned to Inactive"
            )
        case .background:
            LogStore.shared.log(
                level: .info,
                category: "AppLifecycle",
                message: "App transitioned to Background. State preservation active."
            )
            // Trigger routine database prune on background entry
            let retention = UserDefaults.standard.integer(forKey: "fit3_retention_days")
            let days = retention > 0 ? retention : 30
            DataStore.shared.purgeOldRecords(olderThanDays: days)
        @unknown default:
            break
        }
    }
}
