import SwiftUI

public struct StatusBadge: View {
    public let state: ConnectionState

    public init(state: ConnectionState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(state.statusColor.opacity(0.4), lineWidth: state.isActive ? 4 : 0)
                        .scaleEffect(state.isActive ? 1.4 : 1.0)
                        .animation(state.isActive ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: state.isActive)
                )

            Text(state.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(state.statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(state.statusColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(state.statusColor.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(state: .connected)
        StatusBadge(state: .syncing)
        StatusBadge(state: .scanning)
        StatusBadge(state: .error("Timeout"))
        StatusBadge(state: .disconnected)
    }
    .padding()
    .background(Color.black)
}
