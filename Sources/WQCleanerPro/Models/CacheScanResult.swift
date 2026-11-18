import Foundation

/// 可清理的缓存分类。
/// 注意：这里的范围严格限定在"本 App 自身沙盒目录"以及"用户通过系统文件选择器
/// 主动授权的外部目录"，不涉及读取其他已安装 App 的私有容器。
enum CacheCategory: String, Codable, CaseIterable, Identifiable {
    case libraryCaches = "Library/Caches"
    case tmp = "tmp"
    case userSelected = "用户选择的目录"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .libraryCaches: return "系统缓存（Library/Caches）"
        case .tmp: return "临时文件（tmp）"
        case .userSelected: return "用户手动选择的目录"
        }
    }

    var iconName: String {
        switch self {
        case .libraryCaches: return "externaldrive.fill"
        case .tmp: return "clock.arrow.circlepath"
        case .userSelected: return "folder.badge.gearshape"
        }
    }
}

/// 单个被扫描到的文件/目录条目
struct CacheFileEntry: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    let isDirectory: Bool
    let modifiedAt: Date?
}

/// 一次扫描的结果（按分类聚合）
struct CacheScanResult: Identifiable {
    let id = UUID()
    let category: CacheCategory
    var entries: [CacheFileEntry]
    var scannedFileCount: Int
    var totalSizeBytes: Int64
    var scanDurationSeconds: Double
    var isSelectedForCleaning: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}

/// 一次清理操作的历史记录
struct CleaningHistoryRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let categoriesCleaned: [String]
    let filesDeleted: Int
    let bytesFreed: Int64
    let succeeded: Bool
    let note: String?

    init(categoriesCleaned: [String], filesDeleted: Int, bytesFreed: Int64, succeeded: Bool, note: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.categoriesCleaned = categoriesCleaned
        self.filesDeleted = filesDeleted
        self.bytesFreed = bytesFreed
        self.succeeded = succeeded
        self.note = note
    }

    var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}
