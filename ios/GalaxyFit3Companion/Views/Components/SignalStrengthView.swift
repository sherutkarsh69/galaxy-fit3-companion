import SwiftUI

public struct SignalStrengthView: View {
    public let rssi: Int

    public init(rssi: Int) {
        self.rssi = rssi
    }

    private var activeBars: Int {
        if rssi >= -55 {
            return 4
        } else if rssi >= -70 {
            return 3
        } else if rssi >= -85 {
            return 2
        } else if rssi > -100 {
            return 1
        } else {
            return 0
        }
    }

    private var signalColor: Color {
        switch activeBars {
        case 4: return Color(red: 0.30, green: 0.69, blue: 0.31) // Excellent (Green)
        case 3: return Color(red: 0.0, green: 0.83, blue: 1.0)   // Good (Cyan)
        case 2: return Color(red: 1.0, green: 0.76, blue: 0.03)  // Fair (Amber)
        default: return Color(red: 0.96, green: 0.26, blue: 0.21) // Weak (Red)
        }
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(bar <= activeBars ? signalColor : Color.white.opacity(0.2))
                    .frame(width: 4, height: CGFloat(bar * 4 + 4))
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        SignalStrengthView(rssi: -45)
        SignalStrengthView(rssi: -65)
        SignalStrengthView(rssi: -80)
        SignalStrengthView(rssi: -95)
    }
    .padding()
    .background(Color.black)
}
