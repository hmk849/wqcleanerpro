import Foundation

/// 日志级别
enum LogLevel: String, Codable, CaseIterable {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
    case debug = "DEBUG"

    var symbolName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .debug: return "ladybug.fill"
        }
    }
}

/// 单条运行日志，所有日志均来自真实运行事件，不存在占位或虚构内容。
struct LogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String

    init(level: LogLevel, category: String, message: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var exportLine: String {
        "[\(formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)"
    }
}
