import SwiftUI

public struct ContentView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var selectedTab: Int = 0

    public init(bluetoothManager: BluetoothManager, healthKitManager: HealthKitManager) {
        self.bluetoothManager = bluetoothManager
        self.healthKitManager = healthKitManager
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(bluetoothManager: bluetoothManager, healthKitManager: healthKitManager)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            SimpleWorkoutView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Workout", systemImage: "figure.run")
                }
                .tag(1)

            HeartRateView(bluetoothManager: bluetoothManager, healthKitManager: healthKitManager)
                .tabItem {
                    Label("Heart Rate", systemImage: "heart.fill")
                }
                .tag(2)

            Group {
                if bluetoothManager.connectedDevice != nil {
                    DeviceDetailView(bluetoothManager: bluetoothManager)
                } else {
                    ScannerView(bluetoothManager: bluetoothManager)
                }
            }
            .tabItem {
                Label(bluetoothManager.connectedDevice != nil ? "Device" : "Find Fit3", systemImage: "applewatch")
            }
            .tag(3)

            SettingsView(bluetoothManager: bluetoothManager, healthKitManager: healthKitManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(Color(red: 0.0, green: 0.83, blue: 1.0))
        .preferredColorScheme(.dark)
    }
}
