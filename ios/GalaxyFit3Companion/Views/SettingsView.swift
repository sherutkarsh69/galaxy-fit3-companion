import SwiftUI

public struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager

    @AppStorage("fit3_retention_days") private var retentionDays: Int = 30
    @AppStorage("fit3_bg_monitoring") private var backgroundMonitoring: Bool = true
    @State private var showingClearConfirmation: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var exportPayload: String = ""

    public init(bluetoothManager: BluetoothManager, healthKitManager: HealthKitManager) {
        self.bluetoothManager = bluetoothManager
        self.healthKitManager = healthKitManager
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: Health Integration
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Apple Health", systemImage: "heart.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            Divider().background(Color.white.opacity(0.08))

                            Toggle(isOn: Binding(
                                get: { healthKitManager.isAuthorized },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            _ = await healthKitManager.requestAuthorization()
                                        }
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync Heart Rate to Apple Health")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Stores continuous HR measurements in HealthKit")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(Color(red: 0.95, green: 0.2, blue: 0.4))

                            if let lastSync = healthKitManager.lastSyncDate {
                                HStack {
                                    Text("Last synced:")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                }
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Section 2: Bluetooth & Background
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Connectivity", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            Divider().background(Color.white.opacity(0.08))

                            Toggle(isOn: $bluetoothManager.autoReconnect) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-Reconnect")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Automatically reconnect when Galaxy Fit3 is in range")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(Color(red: 0.0, green: 0.83, blue: 1.0))

                            Toggle(isOn: $backgroundMonitoring) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Background State Preservation")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Allows iOS to wake the app for BLE notifications")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(Color(red: 0.0, green: 0.83, blue: 1.0))
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Section 3: Data Persistence & Retention
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Data Management", systemImage: "internaldrive")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            Divider().background(Color.white.opacity(0.08))

                            HStack {
                                Text("Retention Period")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Retention", selection: $retentionDays) {
                                    Text("7 Days").tag(7)
                                    Text("14 Days").tag(14)
                                    Text("30 Days").tag(30)
                                    Text("90 Days").tag(90)
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                .onChange(of: retentionDays) { _, newVal in
                                    DataStore.shared.purgeOldRecords(olderThanDays: newVal)
                                }
                            }

                            Button(action: {
                                exportPayload = DataStore.shared.exportAllJSON()
                                showingExportSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export Stored Data (JSON)")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button(role: .destructive, action: {
                                showingClearConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear All Local Data")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Section 4: About & Privacy
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About Companion App")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)

                            Text("Galaxy Fit3 Companion connects your SM-R390 to iOS using open Bluetooth SIG standards. All health measurements are stored locally on your device and never uploaded to external servers.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(3)

                            HStack {
                                Text("App Version")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("1.0.0 (Build 1)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.09), for: .navigationBar)
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(activityItems: [exportPayload])
            }
            .confirmationDialog("Clear All Data?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    DataStore.shared.clearAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action will erase all stored heart rate measurements and device records from this phone.")
            }
        }
    }
}
