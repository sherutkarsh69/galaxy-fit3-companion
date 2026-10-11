import SwiftUI

public struct HeartRateGauge: View {
    public let bpm: Int
    public let isMonitoring: Bool

    public init(bpm: Int, isMonitoring: Bool) {
        self.bpm = bpm
        self.isMonitoring = isMonitoring
    }

    private var normalizedProgress: Double {
        // Range 40 to 190 BPM mapped to 0.0 ... 1.0
        let clamped = min(max(Double(bpm), 40.0), 190.0)
        return (clamped - 40.0) / (190.0 - 40.0)
    }

    private var zoneColor: Color {
        switch bpm {
        case 0..<60:
            return Color(red: 0.2, green: 0.6, blue: 0.86) // Rest / Low (Blue)
        case 60..<100:
            return Color(red: 0.30, green: 0.69, blue: 0.31) // Normal / Fat Burn (Green)
        case 100..<140:
            return Color(red: 1.0, green: 0.76, blue: 0.03) // Cardio (Yellow/Amber)
        case 140...:
            return Color(red: 1.0, green: 0.35, blue: 0.35) // Peak / Intense (Coral/Red)
        default:
            return Color(white: 0.5)
        }
    }

    private var zoneName: String {
        switch bpm {
        case 0..<60: return "Resting"
        case 60..<100: return "Normal"
        case 100..<140: return "Cardio"
        case 140...: return "Peak"
        default: return "--"
        }
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(90))

            // Progress arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * normalizedProgress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [zoneColor.opacity(0.7), zoneColor]),
                        center: .center,
                        startAngle: .degrees(140),
                        endAngle: .degrees(400)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: bpm)

            // Inner content
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                    .symbolEffect(.pulse, options: .repeating, value: isMonitoring && bpm > 0)

                Text(bpm > 0 ? "\(bpm)" : "--")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("BPM")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(2)

                Text(zoneName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(zoneColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(zoneColor.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(width: 240, height: 240)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HeartRateGauge(bpm: 78, isMonitoring: true)
    }
}
