import Foundation
import SwiftUI

public enum ConnectionState: Equatable, Hashable {
    case idle
    case scanning
    case connecting
    case discovering
    case authenticating
    case connected
    case syncing
    case disconnected
    case error(String)

    public var isConnected: Bool {
        switch self {
        case .connected, .syncing:
            return true
        default:
            return false
        }
    }

    public var isActive: Bool {
        switch self {
        case .scanning, .connecting, .discovering, .authenticating, .syncing:
            return true
        default:
            return false
        }
    }

    public var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .scanning:
            return "Scanning for Galaxy Fit3..."
        case .connecting:
            return "Connecting..."
        case .discovering:
            return "Discovering Services..."
        case .authenticating:
            return "Authenticating..."
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing Data..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    public var statusColor: Color {
        switch self {
        case .connected:
            return Color(red: 0.30, green: 0.69, blue: 0.31) // Green (#4CAF50)
        case .syncing, .connecting, .discovering:
            return Color(red: 1.0, green: 0.76, blue: 0.03)  // Amber (#FFC107)
        case .authenticating:
            return Color(red: 1.0, green: 0.57, blue: 0.0)   // Orange (#FF9100)
        case .scanning:
            return Color(red: 0.0, green: 0.83, blue: 1.0)   // Cyan (#00D4FF)
        case .error:
            return Color(red: 0.96, green: 0.26, blue: 0.21) // Red (#F44336)
        case .idle, .disconnected:
            return Color(white: 0.55)                        // Neutral Gray
        }
    }

    public var statusIcon: String {
        switch self {
        case .idle:
            return "antenna.radiowaves.left.and.right"
        case .scanning:
            return "dot.radiowaves.left.and.right"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .discovering:
            return "magnifyingglass"
        case .authenticating:
            return "lock.shield"
        case .connected:
            return "checkmark.circle.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .disconnected:
            return "xmark.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
