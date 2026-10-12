import Foundation
import Combine
import UIKit

/// Manages active workout tracking sessions, live duration, HR telemetry, and calorie calculations
public final class WorkoutManager: ObservableObject {
    public static let shared = WorkoutManager()

    @Published public var isWorkoutActive: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var currentActivity: ActivityType = .outdoorWalk
    @Published public var elapsedSeconds: TimeInterval = 0
    @Published public var currentBPM: Int = 0
    @Published public var caloriesBurned: Int = 0
    @Published public var avgBPM: Int = 0
    @Published public var maxBPM: Int = 0
    @Published public var workoutHistory: [WorkoutSession] = []
    @Published public var lastCompletedWorkout: WorkoutSession? = nil

    private var timer: Timer?
    private var recordedBPMs: [Int] = []
    private let historyStorageKey = "saved_workout_history_v1"
    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadHistory()
    }

    public var durationFormatted: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public func startWorkout(activity: ActivityType, hrService: HeartRateService? = nil) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        self.currentActivity = activity
        self.isWorkoutActive = true
        self.isPaused = false
        self.elapsedSeconds = 0
        self.caloriesBurned = 0
        self.recordedBPMs.removeAll()
        self.avgBPM = 0
        self.maxBPM = 0

        if let current = hrService?.latestHeartRate?.bpm {
            self.currentBPM = current
            self.recordedBPMs.append(current)
            self.maxBPM = current
            self.avgBPM = current
        }

        // Attach listener to HeartRateService if provided
        if let hrService = hrService {
            hrService.$latestHeartRate
                .compactMap { $0?.bpm }
                .sink { [weak self] bpm in
                    self?.receiveBPM(bpm)
                }
                .store(in: &cancellables)
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
    }

    public func pauseWorkout() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.isPaused = true
    }

    public func resumeWorkout() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.isPaused = false
    }

    public func endWorkout() -> WorkoutSession? {
        guard isWorkoutActive else { return nil }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        timer?.invalidate()
        timer = nil
        cancellables.removeAll()

        let calculatedAvg = recordedBPMs.isEmpty ? 75 : (recordedBPMs.reduce(0, +) / recordedBPMs.count)
        let calculatedMax = recordedBPMs.max() ?? calculatedAvg
        let finalCalories = max(caloriesBurned, Int(elapsedSeconds / 60.0 * currentActivity.defaultMET * 1.1))

        let session = WorkoutSession(
            activityType: currentActivity,
            startDate: Date().addingTimeInterval(-elapsedSeconds),
            durationSeconds: elapsedSeconds,
            caloriesBurned: finalCalories,
            avgBPM: calculatedAvg,
            maxBPM: calculatedMax
        )

        self.lastCompletedWorkout = session
        self.workoutHistory.insert(session, at: 0)
        saveHistory()

        self.isWorkoutActive = false
        self.isPaused = false

        // Dispatch local notification
        NotificationManager.shared.sendWorkoutCompletionAlert(
            activityName: session.activityType.rawValue,
            durationString: session.durationFormatted,
            calories: session.caloriesBurned,
            avgBPM: session.avgBPM
        )

        return session
    }

    public func receiveBPM(_ bpm: Int) {
        guard isWorkoutActive && !isPaused else { return }
        self.currentBPM = bpm
        self.recordedBPMs.append(bpm)
        self.maxBPM = max(self.maxBPM, bpm)
        self.avgBPM = recordedBPMs.reduce(0, +) / recordedBPMs.count
    }

    private func tickTimer() {
        guard isWorkoutActive && !isPaused else { return }
        self.elapsedSeconds += 1.0

        // Update calorie burn every second:
        // Keytel formula approximation per second:
        // If HR available (> 50): kcal/sec = ((-55.0969 + (0.6309 * HR) + (0.1988 * 70kg) + (0.2017 * 28yo)) / 4.184) / 60
        let effectiveHR = Double(currentBPM > 40 ? currentBPM : 80)
        let kcalPerMinute = max(((-55.0969 + (0.6309 * effectiveHR) + 13.916 + 5.6476) / 4.184), currentActivity.defaultMET * 1.0)
        let kcalPerSecond = kcalPerMinute / 60.0

        let accumulated = Double(caloriesBurned) + kcalPerSecond
        self.caloriesBurned = Int(accumulated)
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(workoutHistory) {
            UserDefaults.standard.set(encoded, forKey: historyStorageKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyStorageKey),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) {
            self.workoutHistory = decoded
        }
    }
}
