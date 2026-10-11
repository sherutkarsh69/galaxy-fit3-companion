import SwiftUI

public struct DashboardView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var isRefreshing: Bool = false
    @State private var todayStats: (minBPM: Int, maxBPM: Int, avgBPM: Int, count: Int) = (0, 0, 0, 0)

    public init(bluetoothManager: BluetoothManager, healthKitManager: HealthKitManager) {
        self.bluetoothManager = bluetoothManager
        self.healthKitManager = healthKitManager
    }

    private var hrService: HeartRateService {
        bluetoothManager.heartRateService
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background dark gradient
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Connection Status Card
                        connectionCard

                        // Device Info Card
                        deviceCard

                        // Live Heart Rate Card
                        heartRateCard

                        // Today's Stats Grid
                        todayStatsGrid

                        // Battery Info Card (Proprietary Note)
                        batteryCard

                        // Quick Sync Bar
                        syncBar
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .refreshable {
                    refreshDashboard()
                }
            }
            .navigationTitle("Galaxy Fit3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.07, blue: 0.12), for: .navigationBar)
            .onAppear {
                loadStats()
            }
        }
    }

    // MARK: - Subviews

    private var connectionCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(bluetoothManager.connectionState.statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: bluetoothManager.connectionState.statusIcon)
                    .font(.system(size: 22))
                    .foregroundColor(bluetoothManager.connectionState.statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bluetoothManager.connectedDevice?.displayName ?? "Samsung Galaxy Fit3")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                StatusBadge(state: bluetoothManager.connectionState)
            }

            Spacer()

            if bluetoothManager.connectionState.isConnected {
                VStack(alignment: .trailing, spacing: 4) {
                    SignalStrengthView(rssi: bluetoothManager.rssi)
                    Text("\(bluetoothManager.rssi) dBm")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var deviceCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Hardware Details", systemImage: "applewatch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("SM-R390")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
            }

            Divider().background(Color.white.opacity(0.08))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Firmware")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(bluetoothManager.deviceInfoService.firmwareRevision ?? "R390XXU0AXA1")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protocol")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Bluetooth 5.3 BLE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var heartRateCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                    Text("LATEST HEART RATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hrService.latestHeartRate != nil ? "\(hrService.latestHeartRate!.bpm)" : "--")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("BPM")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                if let sample = hrService.latestHeartRate {
                    Text(sample.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("Waiting for live sensor stream...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                    .symbolEffect(.pulse, options: .repeating, value: hrService.isMonitoring)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.08, blue: 0.12), Color(red: 0.09, green: 0.11, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.2), lineWidth: 1)
        )
    }

    private var todayStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S HEART RATE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                metricTile(title: "MINIMUM", value: "\(todayStats.minBPM)", unit: "BPM", color: Color(red: 0.2, green: 0.6, blue: 0.86))
                metricTile(title: "AVERAGE", value: "\(todayStats.avgBPM)", unit: "BPM", color: Color(red: 0.30, green: 0.69, blue: 0.31))
                metricTile(title: "PEAK", value: "\(todayStats.maxBPM)", unit: "BPM", color: Color(red: 1.0, green: 0.35, blue: 0.35))
            }
        }
    }

    private func metricTile(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Text(value != "0" ? value : "--")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var batteryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "battery.50")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Battery Level")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Standard GATT 0x180F is omitted by Samsung. Requires proprietary SAP protocol.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var syncBar: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            if let lastSync = healthKitManager.lastSyncDate {
                Text("Last HealthKit Sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("HealthKit Sync: Ready")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await healthKitManager.syncUnsyncedSamples()
                    loadStats()
                }
            }) {
                Text("Sync Now")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func refreshDashboard() {
        loadStats()
    }

    private func loadStats() {
        self.todayStats = DataStore.shared.fetchTodayStats()
    }
}
