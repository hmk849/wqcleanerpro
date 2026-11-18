import Foundation
import Combine

/// 全局日志中心：所有模块（缓存扫描/清理、兼容性检测、GitHub 云编译）
/// 统一通过这里写日志，首页日志页实时订阅展示。
@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published private(set) var entries: [LogEntry] = []
    @Published var isPaused: Bool = false
    @Published var autoScroll: Bool = true

    private let maxEntries = 5000

    private init() {
        log(.info, category: "App", message: "LogManager 初始化完成")
    }

    func log(_ level: LogLevel, category: String, message: String) {
        guard !isPaused else { return }
        let entry = LogEntry(level: level, category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
        log(.info, category: "Log", message: "日志已清空")
    }

    var copyText: String {
        entries.map { $0.exportLine }.joined(separator: "\n")
    }

    /// 导出为 TXT 文件，返回临时文件 URL 供分享
    func exportToTxt() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "WQCleanerPro_Log_\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try copyText.write(to: url, atomically: true, encoding: .utf8)
        log(.success, category: "Log", message: "日志已导出：\(filename)")
        return url
    }
}
