import Foundation
import SwiftUI

public enum DiagnosticLevel: String, Codable, CaseIterable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    public var color: Color {
        switch self {
        case .info:
            return Color(white: 0.7)
        case .warning:
            return Color(red: 1.0, green: 0.76, blue: 0.03)
        case .error:
            return Color(red: 0.96, green: 0.26, blue: 0.21)
        }
    }
}

public struct DiagnosticLog: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: DiagnosticLevel
    public let category: String
    public let message: String
    public let rawData: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: String,
        message: String,
        rawData: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.rawData = rawData
    }
}

@MainActor
public final class LogStore: ObservableObject {
    public static let shared = LogStore()

    @Published public private(set) var logs: [DiagnosticLog] = []
    private let maxLogs = 1000

    public init() {}

    public func log(level: DiagnosticLevel, category: String, message: String, rawData: Data? = nil) {
        let hexString: String? = rawData.map { data in
            data.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
        let entry = DiagnosticLog(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            rawData: hexString
        )
        logs.insert(entry, at: 0)
        if logs.count > maxLogs {
            logs.removeLast(logs.count - maxLogs)
        }
    }

    public func clear() {
        logs.removeAll()
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(logs),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
