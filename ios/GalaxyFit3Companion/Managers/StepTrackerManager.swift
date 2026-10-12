import Foundation
import CoreMotion
import Combine

/// Manages real-time daily step counting, distance, and activity tracking via iPhone CoreMotion
public final class StepTrackerManager: ObservableObject {
    public static let shared = StepTrackerManager()

    @Published public var todaySteps: Int = 0
    @Published public var todayDistanceMeters: Double = 0.0
    @Published public var todayFloors: Int = 0
    @Published public var activeMinutes: Int = 0
    @Published public var stepGoal: Int = 10000
    @Published public var isAvailable: Bool = false
    @Published public var authorizationStatusText: String = "Ready"

    private let pedometer = CMPedometer()
    private var isUpdating: Bool = false
    private let stepGoalKey = "user_daily_step_goal"

    public init() {
        self.stepGoal = UserDefaults.standard.integer(forKey: stepGoalKey)
        if self.stepGoal == 0 {
            self.stepGoal = 10000
        }
        self.isAvailable = CMPedometer.isStepCountingAvailable()
        queryTodaySteps()
        startLiveUpdates()
    }

    public var progress: Double {
        guard stepGoal > 0 else { return 0.0 }
        return min(Double(todaySteps) / Double(stepGoal), 1.0)
    }

    public var distanceKm: Double {
        return todayDistanceMeters / 1000.0
    }

    public var distanceString: String {
        return String(format: "%.1f km", distanceKm)
    }

    public func updateStepGoal(_ newGoal: Int) {
        self.stepGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: stepGoalKey)
    }

    public func refresh() {
        queryTodaySteps()
    }

    private func queryTodaySteps() {
        guard isAvailable else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil else {
                    if let error = error {
                        LogStore.shared.log(level: .warning, category: "StepTracker", message: "Step query error: \(error.localizedDescription)")
                    }
                    return
                }

                self.todaySteps = data.numberOfSteps.intValue
                if let dist = data.distance {
                    self.todayDistanceMeters = dist.doubleValue
                }
                if let floors = data.floorsAscended {
                    self.todayFloors = floors.intValue
                }
                // Estimate active minutes: ~100 steps per active minute
                self.activeMinutes = max(data.numberOfSteps.intValue / 105, 0)
                NotificationManager.shared.evaluateStepGoal(currentSteps: self.todaySteps, goal: self.stepGoal)
            }
        }
    }

    private func startLiveUpdates() {
        guard isAvailable && !isUpdating else { return }
        isUpdating = true

        let now = Date()
        pedometer.startUpdates(from: now) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil else { return }

                // Pedometer live update delta added to current tally
                self.queryTodaySteps()
            }
        }
    }

    deinit {
        pedometer.stopUpdates()
    }
}
