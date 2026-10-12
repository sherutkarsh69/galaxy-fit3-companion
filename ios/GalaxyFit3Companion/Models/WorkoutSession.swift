import Foundation

public enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case outdoorWalk = "Outdoor Walk"
    case running = "Running"
    case cycling = "Cycling"
    case workout = "General Workout"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .outdoorWalk: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .workout: return "dumbbell.fill"
        }
    }

    public var defaultMET: Double {
        switch self {
        case .outdoorWalk: return 3.5
        case .running: return 8.0
        case .cycling: return 6.0
        case .workout: return 5.0
        }
    }
}

public struct WorkoutSession: Identifiable, Codable {
    public let id: UUID
    public let activityType: ActivityType
    public let startDate: Date
    public let durationSeconds: TimeInterval
    public let caloriesBurned: Int
    public let avgBPM: Int
    public let maxBPM: Int

    public init(
        id: UUID = UUID(),
        activityType: ActivityType,
        startDate: Date = Date(),
        durationSeconds: TimeInterval,
        caloriesBurned: Int,
        avgBPM: Int,
        maxBPM: Int
    ) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.avgBPM = avgBPM
        self.maxBPM = maxBPM
    }

    public var durationFormatted: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remMin = minutes % 60
            return String(format: "%d h %02d m", hours, remMin)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
