import SwiftUI

/// Apple Fitness-style concentric Activity Triad rings for Steps, Calories, and Active Time
public struct ActivityTriadView: View {
    @ObservedObject var stepTracker: StepTrackerManager
    public let activeCalories: Int

    public init(stepTracker: StepTrackerManager, activeCalories: Int = 0) {
        self.stepTracker = stepTracker
        self.activeCalories = activeCalories
    }

    private var stepsProgress: Double {
        return stepTracker.progress
    }

    private var caloriesProgress: Double {
        let goal = 500.0
        let effective = Double(activeCalories > 0 ? activeCalories : max(stepTracker.todaySteps / 22, 50))
        return min(effective / goal, 1.0)
    }

    private var activeTimeProgress: Double {
        let goal = 30.0
        return min(Double(stepTracker.activeMinutes) / goal, 1.0)
    }

    public var body: some View {
        HStack(spacing: 20) {
            // Concentric Rings
            ZStack {
                // Background Track 1 (Steps - Cyan)
                Circle()
                    .stroke(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.18), lineWidth: 10)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(stepsProgress))
                    .stroke(
                        Color(red: 0.0, green: 0.83, blue: 1.0),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: stepsProgress)

                // Background Track 2 (Calories - Coral)
                Circle()
                    .stroke(Color(red: 1.0, green: 0.37, blue: 0.49).opacity(0.18), lineWidth: 9)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: CGFloat(caloriesProgress))
                    .stroke(
                        Color(red: 1.0, green: 0.37, blue: 0.49),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: caloriesProgress)

                // Background Track 3 (Active Time - Emerald)
                Circle()
                    .stroke(Color(red: 0.0, green: 0.90, blue: 0.46).opacity(0.18), lineWidth: 8)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: CGFloat(activeTimeProgress))
                    .stroke(
                        Color(red: 0.0, green: 0.90, blue: 0.46),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 54, height: 54)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: activeTimeProgress)
            }
            .frame(width: 105, height: 105)

            // Metrics Column
            VStack(alignment: .leading, spacing: 10) {
                // Steps
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.83, blue: 1.0))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(stepTracker.todaySteps.formatted()) / \(stepTracker.stepGoal.formatted())")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Steps · \(stepTracker.distanceString)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Calories
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.37, blue: 0.49))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        let effKcal = activeCalories > 0 ? activeCalories : max(stepTracker.todaySteps / 22, 50)
                        Text("\(effKcal) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Active Energy Burn")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Active Minutes
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.90, blue: 0.46))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(stepTracker.activeMinutes) / 30 mins")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Brisk Movement")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
