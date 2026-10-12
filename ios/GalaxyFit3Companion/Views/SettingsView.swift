import SwiftUI

public struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager
    @ObservedObject var notificationManager = NotificationManager.shared
    @ObservedObject var stepTracker = StepTrackerManager.shared

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
                        // Section 1: Notifications & Alerts
                        notificationSettingsSection

                        // Section 2: Health & Device Integration Status
                        deviceStatusSection

                        // Section 4: Daily Goals
                        goalsSection

                        // Section 5: Apple Health
                        appleHealthSection

                        // Section 6: Data Export
                        dataExportSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings & Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.07, blue: 0.12), for: .navigationBar)
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(activityItems: [exportPayload])
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }

    // MARK: - Subviews

    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Smart Health Alerts", systemImage: "bell.badge.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(notificationManager.isAuthorized ? "ENABLED" : "NOT PERMITTED")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(notificationManager.isAuthorized ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(notificationManager.isAuthorized ? .green : .orange)
                    .clipShape(Capsule())
            }

            Divider().background(Color.white.opacity(0.08))

            if !notificationManager.isAuthorized {
                Button(action: {
                    notificationManager.requestAuthorization()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Enable iPhone Notifications")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // High HR Alert Toggle
            Toggle(isOn: Binding(
                get: { notificationManager.isHighHRAlertEnabled },
                set: { notificationManager.setHighHREnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("High Resting Heart Rate Alert")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("Alert if heart rate spikes unexpectedly while resting")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .tint(Color(red: 0.0, green: 0.83, blue: 1.0))

            if notificationManager.isHighHRAlertEnabled {
                HStack {
                    Text("Alert Limit:")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Limit", selection: Binding(
                        get: { notificationManager.highHRThreshold },
                        set: { notificationManager.updateHighHRThreshold($0) }
                    )) {
                        Text("110 BPM").tag(110)
                        Text("120 BPM").tag(120)
                        Text("130 BPM").tag(130)
                        Text("140 BPM").tag(140)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }

            // Step Goal Celebration Toggle
            Toggle(isOn: Binding(
                get: { notificationManager.isGoalCelebrationEnabled },
                set: { notificationManager.setGoalCelebrationEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step Goal Celebration")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("Notify when hitting daily step target")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .tint(Color(red: 0.0, green: 0.83, blue: 1.0))

            // Test Alert Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                notificationManager.sendTestNotification()
            }) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text("Test iPhone Health Alert Now")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Device & Feature Status", systemImage: "bolt.horizontal.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.08))

            VStack(spacing: 10) {
                statusRow(title: "Live Heart Rate", subtitle: "Continuous BLE streaming from Fit3", status: "Active", isGood: true)
                statusRow(title: "Daily Steps & Movement", subtitle: "iPhone CoreMotion pedometer", status: "Ready", isGood: true)
                statusRow(title: "Apple Health Sync", subtitle: "Writes HR & Energy to HealthKit", status: healthKitManager.isAuthorized ? "Enabled" : "Off", isGood: healthKitManager.isAuthorized)
                statusRow(title: "Health Alerts", subtitle: "High HR & Goal alerts on iPhone", status: notificationManager.isAuthorized ? "Active" : "Off", isGood: notificationManager.isAuthorized)
                statusRow(title: "Watch Screen Notifications", subtitle: "Hardware locked to Android by Samsung", status: "Phone Only", isGood: false)
            }

            Text("Samsung engineered the Galaxy Fit3 screen exclusively for Android's Galaxy Wearable app. Continuous heart rate, workouts, and smart alerts are seamlessly powered on your iPhone.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func statusRow(title: String, subtitle: String, status: String, isGood: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(status)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isGood ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                .foregroundColor(isGood ? .green : .secondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }


    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Daily Goals", systemImage: "target")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.08))

            HStack {
                Text("Daily Step Goal:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Step Goal", selection: Binding(
                    get: { stepTracker.stepGoal },
                    set: { stepTracker.updateStepGoal($0) }
                )) {
                    Text("6,000").tag(6000)
                    Text("8,000").tag(8000)
                    Text("10,000").tag(10000)
                    Text("12,000").tag(12000)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var appleHealthSection: some View {
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
                    Text("Sync to Apple Health")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("Stores heart rate measurements into Apple Health")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .tint(Color(red: 0.95, green: 0.2, blue: 0.4))

            Button(action: {
                Task {
                    await healthKitManager.syncUnsyncedSamples()
                }
            }) {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Data & Export", systemImage: "square.and.arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.08))

            Button(action: {
                exportPayload = DataStore.shared.exportAllJSON()
                showingExportSheet = true
            }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Export Heart Rate History (JSON)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
