import Foundation
import UserNotifications
import Combine

/// Manages local push notifications for health alerts, goal celebrations, and workout summaries
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    @Published public var isAuthorized: Bool = false
    @Published public var highHRThreshold: Int = 120
    @Published public var isHighHRAlertEnabled: Bool = true
    @Published public var isGoalCelebrationEnabled: Bool = true

    private var lastHighHRAlertDate: Date?
    private var hasCelebratedStepsToday: Bool = false
    private let highHRKey = "notif_high_hr_threshold"
    private let highHREnabledKey = "notif_high_hr_enabled"
    private let goalEnabledKey = "notif_goal_celebration_enabled"

    public init() {
        self.highHRThreshold = UserDefaults.standard.integer(forKey: highHRKey)
        if self.highHRThreshold == 0 {
            self.highHRThreshold = 120
        }
        self.isHighHRAlertEnabled = UserDefaults.standard.object(forKey: highHREnabledKey) as? Bool ?? true
        self.isGoalCelebrationEnabled = UserDefaults.standard.object(forKey: goalEnabledKey) as? Bool ?? true

        checkAuthorizationStatus()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    LogStore.shared.log(level: .warning, category: "NotificationManager", message: "Notification auth error: \(error.localizedDescription)")
                } else {
                    LogStore.shared.log(level: .info, category: "NotificationManager", message: "Notification permission granted: \(granted)")
                }
            }
        }
    }

    public func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    public func updateHighHRThreshold(_ threshold: Int) {
        self.highHRThreshold = threshold
        UserDefaults.standard.set(threshold, forKey: highHRKey)
    }

    public func setHighHREnabled(_ enabled: Bool) {
        self.isHighHRAlertEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: highHREnabledKey)
    }

    public func setGoalCelebrationEnabled(_ enabled: Bool) {
        self.isGoalCelebrationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: goalEnabledKey)
    }

    /// Evaluates current heart rate and triggers alert if abnormally elevated while resting
    public func evaluateHeartRateForAlert(bpm: Int) {
        guard isHighHRAlertEnabled, bpm >= highHRThreshold else { return }

        // Debounce: allow alert at most once every 15 minutes
        if let last = lastHighHRAlertDate, Date().timeIntervalSince(last) < 900 {
            return
        }

        lastHighHRAlertDate = Date()
        sendNotification(
            title: "⚠️ High Heart Rate Alert",
            body: "Your Samsung Galaxy Fit3 measured \(bpm) BPM, exceeding your resting alert limit of \(highHRThreshold) BPM.",
            identifier: "high_hr_alert_\(Int(Date().timeIntervalSince1970))"
        )
    }

    /// Triggers celebratory notification when daily step target is reached
    public func evaluateStepGoal(currentSteps: Int, goal: Int) {
        guard isGoalCelebrationEnabled, currentSteps >= goal, !hasCelebratedStepsToday else { return }
        hasCelebratedStepsToday = true

        sendNotification(
            title: "🎉 Daily Goal Achieved!",
            body: "Congratulations! You reached your target of \(goal.formatted()) steps today (\(currentSteps.formatted()) steps).",
            identifier: "step_goal_celebration"
        )
    }

    /// Sends workout completion recap notification
    public func sendWorkoutCompletionAlert(activityName: String, durationString: String, calories: Int, avgBPM: Int) {
        sendNotification(
            title: "💪 \(activityName) Finished",
            body: "Great session! Duration: \(durationString) · \(calories) active kcal · Avg HR: \(avgBPM) BPM.",
            identifier: "workout_completion_\(Int(Date().timeIntervalSince1970))"
        )
    }

    /// Sends immediate test alert to verify notification sound and banner
    public func sendTestNotification() {
        sendNotification(
            title: "🔔 Galaxy Fit3 Companion",
            body: "Notifications are active and working properly on your iPhone!",
            identifier: "test_notification_\(Int(Date().timeIntervalSince1970))"
        )
    }

    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogStore.shared.log(level: .error, category: "NotificationManager", message: "Failed to dispatch notification: \(error.localizedDescription)")
            } else {
                LogStore.shared.log(level: .info, category: "NotificationManager", message: "Dispatched notification: \(title)")
            }
        }
    }
}
