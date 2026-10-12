import SwiftUI

/// Clean, one-tap activity workout tracker with live telemetry and session history
public struct SimpleWorkoutView: View {
    @ObservedObject var workoutManager = WorkoutManager.shared
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var selectedActivity: ActivityType = .outdoorWalk
    @State private var showSummarySheet: Bool = false

    public init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
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
                    VStack(spacing: 22) {
                        if workoutManager.isWorkoutActive {
                            activeWorkoutCard
                        } else {
                            startActivityCard
                        }

                        // Workout History Section
                        historySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.07, blue: 0.12), for: .navigationBar)
            .sheet(item: $workoutManager.lastCompletedWorkout) { session in
                workoutSummarySheet(session: session)
            }
        }
    }

    // MARK: - Subviews

    private var startActivityCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Select Activity")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)

            // Activity Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ActivityType.allCases) { activity in
                    Button(action: {
                        selectedActivity = activity
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedActivity == activity ? .black : Color(red: 0.0, green: 0.83, blue: 1.0))

                            Text(activity.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedActivity == activity ? .black : .white)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            selectedActivity == activity
                            ? Color(red: 0.0, green: 0.83, blue: 1.0)
                            : Color.white.opacity(0.06)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            // Start Button
            Button(action: {
                workoutManager.startWorkout(activity: selectedActivity, hrService: bluetoothManager.heartRateService)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start \(selectedActivity.rawValue)")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var activeWorkoutCard: some View {
        VStack(spacing: 20) {
            HStack {
                Label(workoutManager.currentActivity.rawValue, systemImage: workoutManager.currentActivity.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                Spacer()
                Text(workoutManager.isPaused ? "PAUSED" : "ACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(workoutManager.isPaused ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(workoutManager.isPaused ? .orange : .green)
                    .clipShape(Capsule())
            }

            // Big Timer
            Text(workoutManager.durationFormatted)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Metrics Row
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("HEART RATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(workoutManager.currentBPM > 0 ? workoutManager.currentBPM : (bluetoothManager.heartRateService.latestHeartRate?.bpm ?? 75))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.37, blue: 0.49))
                        Text("BPM")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36).background(Color.white.opacity(0.1))

                VStack(spacing: 4) {
                    Text("ACTIVE BURN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(workoutManager.caloriesBurned)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                        Text("kcal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            // Control Buttons
            HStack(spacing: 14) {
                Button(action: {
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    HStack {
                        Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        Text(workoutManager.isPaused ? "Resume" : "Pause")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: {
                    _ = workoutManager.endWorkout()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Workout")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.15, blue: 0.22), Color(red: 0.08, green: 0.10, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.3), lineWidth: 1)
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Sessions")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            if workoutManager.workoutHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No workouts recorded yet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(workoutManager.workoutHistory.prefix(10)) { session in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: session.activityType.icon)
                                    .foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0))
                                    .font(.system(size: 18))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.activityType.rawValue)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(session.caloriesBurned) kcal")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 1.0, green: 0.37, blue: 0.49))
                                Text(session.durationFormatted)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func workoutSummarySheet(session: WorkoutSession) -> some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("Workout Complete!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(session.activityType.rawValue)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                metricBox(title: "DURATION", value: session.durationFormatted, unit: "")
                metricBox(title: "CALORIES", value: "\(session.caloriesBurned)", unit: "kcal")
                metricBox(title: "AVG HR", value: "\(session.avgBPM)", unit: "BPM")
            }

            Spacer()

            Button(action: {
                workoutManager.lastCompletedWorkout = nil
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.0, green: 0.83, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.bottom, 20)
        }
        .padding(24)
        .background(Color(red: 0.07, green: 0.09, blue: 0.14))
        .preferredColorScheme(.dark)
    }

    private func metricBox(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
