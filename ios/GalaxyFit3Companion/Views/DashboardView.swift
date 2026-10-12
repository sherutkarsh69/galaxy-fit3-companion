import SwiftUI

public struct DashboardView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager
    @ObservedObject var hrService: HeartRateService
    @ObservedObject var stepTracker = StepTrackerManager.shared
    @ObservedObject var workoutManager = WorkoutManager.shared

    @State private var todayStats: (minBPM: Int, maxBPM: Int, avgBPM: Int, count: Int) = (0, 0, 0, 0)
    @State private var buzzedSuccess: Bool = false

    public init(bluetoothManager: BluetoothManager, healthKitManager: HealthKitManager) {
        self.bluetoothManager = bluetoothManager
        self.healthKitManager = healthKitManager
        self.hrService = bluetoothManager.heartRateService
    }

    private var currentHRStatus: (title: String, color: Color) {
        guard let bpm = hrService.latestHeartRate?.bpm else {
            return ("Waiting", .secondary)
        }
        if bpm < 65 {
            return ("Resting", Color(red: 0.0, green: 0.83, blue: 1.0))
        } else if bpm <= 100 {
            return ("Normal", Color(red: 0.30, green: 0.85, blue: 0.45))
        } else if bpm <= 135 {
            return ("Active", Color(red: 1.0, green: 0.65, blue: 0.2))
        } else {
            return ("Peak", Color(red: 1.0, green: 0.35, blue: 0.35))
        }
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
                    VStack(spacing: 18) {
                        // Connection Status Card
                        connectionCard

                        // 1. Activity Triad Rings (Steps, Active Energy, Time)
                        ActivityTriadView(stepTracker: stepTracker, activeCalories: workoutManager.caloriesBurned)

                        // 2. Live Heart Rate Card with Human Status Badge
                        heartRateCard

                        // 3. Quick Actions (Buzz Watch & Start Workout)
                        quickActionsBar

                        // 4. Today's Heart Rate Range
                        todayStatsGrid

                        // 5. Hardware Info
                        deviceCard
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
                stepTracker.refresh()
            }
        }
    }

    // MARK: - Subviews

    private var connectionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(bluetoothManager.connectionState.statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: bluetoothManager.connectionState.statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(bluetoothManager.connectionState.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(bluetoothManager.connectedDevice?.displayName ?? "Samsung Galaxy Fit3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                StatusBadge(state: bluetoothManager.connectionState)
            }

            Spacer()

            if bluetoothManager.connectionState.isConnected {
                VStack(alignment: .trailing, spacing: 2) {
                    SignalStrengthView(rssi: bluetoothManager.rssi)
                    Text("\(bluetoothManager.rssi) dBm")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: {
                    bluetoothManager.checkAndConnectSystemPeripherals()
                    if bluetoothManager.connectedDevice == nil {
                        bluetoothManager.startScanning()
                    }
                }) {
                    Text("Connect")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heartRateCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                            .font(.system(size: 13))
                        Text("LIVE HEART RATE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        // Status Badge
                        Text(currentHRStatus.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(currentHRStatus.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(currentHRStatus.color.opacity(0.15))
                            .clipShape(Capsule())
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
                        Text("Last updated: \(sample.timestamp.formatted(date: .omitted, time: .standard))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Button(action: {
                            bluetoothManager.resubscribeHeartRate()
                        }) {
                            Label("Refresh Stream", systemImage: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.15))
                        .frame(width: 76, height: 76)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 34))
                        .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                        .symbolEffect(.pulse, options: .repeating, value: hrService.isMonitoring)
                }
            }

            // Daily Range Bar
            if todayStats.minBPM > 0 && todayStats.maxBPM > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Min: \(todayStats.minBPM) BPM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.86))
                        Spacer()
                        Text("Avg: \(todayStats.avgBPM) BPM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Max: \(todayStats.maxBPM) BPM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    }

                    // Visual Range Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)

                            let minVal = Double(todayStats.minBPM)
                            let maxVal = Double(todayStats.maxBPM)
                            let currentVal = Double(hrService.latestHeartRate?.bpm ?? todayStats.avgBPM)
                            let ratio = maxVal > minVal ? (currentVal - minVal) / (maxVal - minVal) : 0.5
                            let clampedRatio = min(max(ratio, 0.0), 1.0)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.6, blue: 0.86), Color(red: 1.0, green: 0.35, blue: 0.35)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(clampedRatio), height: 6)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                                .offset(x: max(0, geo.size.width * CGFloat(clampedRatio) - 6))
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
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

    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            // Buzz My Watch Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                bluetoothManager.triggerBandVibration()
                withAnimation {
                    buzzedSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        buzzedSuccess = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: buzzedSuccess ? "waveform.badge.magnifyingglass" : "bell.and.waveform.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                    Text(buzzedSuccess ? "Sent Alert!" : "Buzz Watch")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.2), lineWidth: 1)
                )
            }

            // Test Notification Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                NotificationManager.shared.sendTestNotification()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.2))
                    Text("Test Alert")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 1.0, green: 0.65, blue: 0.2).opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var todayStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S SUMMARY")
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
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var deviceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "applewatch")
                .font(.system(size: 22))
                .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))

            VStack(alignment: .leading, spacing: 2) {
                Text("Samsung Galaxy Fit3 (SM-R390)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Bluetooth 5.3 BLE · Continuous Optical HR")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func refreshDashboard() {
        loadStats()
        stepTracker.refresh()
    }

    private func loadStats() {
        self.todayStats = DataStore.shared.fetchTodayStats()
    }
}
