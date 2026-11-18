import Foundation

/// 单项兼容性/能力检测结果。
/// 所有检测都基于真实的运行时探测（实际尝试读写、实际查询系统版本），
/// 不包含任何针对未公开系统漏洞的探测或假设。
struct CapabilityCheck: Identifiable {
    enum Status {
        case available
        case unavailable(reason: String)
        case notChecked
    }

    let id = UUID()
    let name: String
    let detail: String
    var status: Status

    var isAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    var statusText: String {
        switch status {
        case .available: return "可用"
        case .unavailable(let reason): return "不可用：\(reason)"
        case .notChecked: return "未检测"
        }
    }
}

/// 整体兼容性报告
struct CompatibilityReport {
    var systemVersion: String
    var deviceModel: String
    var checks: [CapabilityCheck]
    var generatedAt: Date = Date()

    var allCriticalChecksPassed: Bool {
        checks.allSatisfy { $0.isAvailable }
    }
}
