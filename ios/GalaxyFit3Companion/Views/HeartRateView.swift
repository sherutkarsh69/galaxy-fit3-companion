import SwiftUI
import Charts

public struct HeartRateView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var showingSyncAlert: Bool = false
    @State private var syncAlertMessage: String = ""

    public init(bluetoothManager: BluetoothManager, healthKitManager: HealthKitManager) {
        self.bluetoothManager = bluetoothManager
        self.healthKitManager = healthKitManager
    }

    private var hrService: HeartRateService {
        bluetoothManager.heartRateService
    }

    private var sessionStats: (min: Int, max: Int, avg: Int) {
        let history = hrService.heartRateHistory
        guard !history.isEmpty else { return (0, 0, 0) }
        let bpms = history.map { $0.bpm }
        let minB = bpms.min() ?? 0
        let maxB = bpms.max() ?? 0
        let avgB = bpms.reduce(0, +) / bpms.count
        return (minB, maxB, avgB)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Sensor Contact Banner
                        HStack(spacing: 12) {
                            Image(systemName: hrService.sensorContactDetected ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundColor(hrService.sensorContactDetected ? Color(red: 0.30, green: 0.69, blue: 0.31) : Color(red: 1.0, green: 0.76, blue: 0.03))

                            Text(hrService.sensorContactDetected ? "Sensor contact detected on wrist" : "Sensor contact not detected / Loose fit")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            Text(hrService.bodySensorLocation)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Large Gauge
                        HeartRateGauge(
                            bpm: hrService.latestHeartRate?.bpm ?? 0,
                            isMonitoring: hrService.isMonitoring
                        )
                        .padding(.vertical, 10)

                        // Stats Summary Row
                        HStack(spacing: 12) {
                            statCard(title: "MIN", value: "\(sessionStats.min)", unit: "BPM", color: Color(red: 0.2, green: 0.6, blue: 0.86))
                            statCard(title: "AVG", value: "\(sessionStats.avg)", unit: "BPM", color: Color(red: 0.30, green: 0.69, blue: 0.31))
                            statCard(title: "MAX", value: "\(sessionStats.max)", unit: "BPM", color: Color(red: 1.0, green: 0.35, blue: 0.35))
                        }

                        // Live HR Chart (Swift Charts)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Live Heart Rate")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Last \(hrService.heartRateHistory.count) samples")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            if hrService.heartRateHistory.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "waveform.path.ecg")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary.opacity(0.5))
                                        Text("Waiting for live HR stream...")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 36)
                                    Spacer()
                                }
                            } else {
                                Chart {
                                    ForEach(hrService.heartRateHistory) { sample in
                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("BPM", sample.bpm)
                                        )
                                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                                        .interpolationMethod(.catmullRom)

                                        AreaMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("BPM", sample.bpm)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.35), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                                .chartYScale(domain: 40...180)
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                                        AxisTick().foregroundStyle(Color.white.opacity(0.2))
                                        AxisValueLabel().foregroundStyle(Color.secondary)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                                        AxisTick().foregroundStyle(Color.white.opacity(0.2))
                                        AxisValueLabel().foregroundStyle(Color.secondary)
                                    }
                                }
                                .frame(height: 180)
                            }
                        }
                        .padding(18)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Hint Callout
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                .font(.system(size: 18))

                            Text("Enable continuous HR monitoring on your Galaxy Fit3 (Settings > Heart Rate > Continuous) for real-time 1 Hz streaming.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.85))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.3), lineWidth: 1)
                        )

                        // HealthKit Manual Sync Action
                        Button(action: {
                            Task {
                                if !healthKitManager.isAuthorized {
                                    _ = await healthKitManager.requestAuthorization()
                                }
                                await healthKitManager.syncUnsyncedSamples()
                                syncAlertMessage = "Heart rate samples synchronized with Apple Health."
                                showingSyncAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "heart.text.square.fill")
                                Text(healthKitManager.isSyncing ? "Syncing with Apple Health..." : "Sync History with Apple Health")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.95, green: 0.2, blue: 0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(healthKitManager.isSyncing)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.09), for: .navigationBar)
            .alert("HealthKit Sync", isPresented: $showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncAlertMessage)
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
