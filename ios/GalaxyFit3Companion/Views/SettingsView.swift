import SwiftUI

public struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var healthKitManager: HealthKitManager
    @ObservedObject var notificationManager = NotificationManager.shared
    @ObservedObject var stepTracker = StepTrackerManager.shared

    @State private var showingExportSheet: Bool = false
    @State private var exportPayload: String = ""
    @State private var buzzedSuccess: Bool = false

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

                        // Section 2: iPhone-to-Watch ANCS Guide
                        watchNotificationGuideSection

                        // Section 3: Band Controls (Buzz Watch)
                        bandControlsSection

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
                Label("Send Test Notification to iPhone", systemImage: "bell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var watchNotificationGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Calls & App Alerts on Watch", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.08))

            Text("To receive incoming phone calls, WhatsApp, and SMS alerts on your Galaxy Fit3 screen, ensure iOS system notification sharing is enabled:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 8) {
                stepRow(number: "1", text: "Open iPhone Settings > Bluetooth")
                stepRow(number: "2", text: "Tap the ⓘ icon next to Galaxy Fit3")
                stepRow(number: "3", text: "Turn ON 'Share System Notifications'")
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open iPhone Settings")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.2))
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }

    private var bandControlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Band Controls", systemImage: "waveform")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.08))

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
                HStack {
                    Image(systemName: buzzedSuccess ? "checkmark.circle.fill" : "bell.and.waveform.fill")
                    Text(buzzedSuccess ? "Alert Sent to Band!" : "Buzz My Watch (Test Vibration)")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buzzedSuccess ? Color.green : Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
