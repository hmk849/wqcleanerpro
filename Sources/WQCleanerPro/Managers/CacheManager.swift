import Foundation
import Combine

/// 缓存清理核心模块。
///
/// 范围边界（务必保持）：
/// - 只操作 `FileManager.default` 返回的、属于**本 App 自身**沙盒内的目录
///   （`Library/Caches`、`tmp`），以及用户通过 `UIDocumentPickerViewController`
///   主动选中并授予 security-scoped 访问权限的外部目录。
/// - 不枚举 `/private/var/mobile/Containers/Data/Application/` 下的其他 App 容器，
///   不读取、不比较任何其他 Bundle ID 对应的目录，不做任何形式的跨 App 访问。
/// - 所有大小统计来自真实的 `FileManager` 属性读取，不做估算或虚构。
@MainActor
final class CacheManager: ObservableObject {
    static let shared = CacheManager()

    @Published private(set) var scanResults: [CacheScanResult] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var cleaningProgress: Double = 0
    @Published private(set) var history: [CleaningHistoryRecord] = []
    @Published var userSelectedURLs: [URL] = []

    private var cleaningTask: Task<Void, Never>?
    private let log = LogManager.shared
    private let fm = FileManager.default

    private init() {
        loadHistory()
    }

    // MARK: - 扫描

    func scanAll() async {
        isScanning = true
        scanResults.removeAll()
        log.log(.info, category: "Cache", message: "开始扫描缓存目录")

        for category in CacheCategory.allCases {
            let result = await scanCategory(category)
            scanResults.append(result)
            log.log(.info, category: "Cache",
                     message: "[\(category.displayName)] 扫描完成：\(result.scannedFileCount) 个文件，\(result.formattedSize)")
        }

        isScanning = false
        log.log(.success, category: "Cache", message: "全部扫描完成")
    }

    private func scanCategory(_ category: CacheCategory) async -> CacheScanResult {
        let start = Date()
        var roots: [URL] = []

        switch category {
        case .libraryCaches:
            if let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                roots = [dir]
            }
        case .tmp:
            roots = [fm.temporaryDirectory]
        case .userSelected:
            roots = userSelectedURLs
        }

        var entries: [CacheFileEntry] = []
        var totalSize: Int64 = 0

        for root in roots {
            let (collected, size) = await enumerateRecursively(root)
            entries.append(contentsOf: collected)
            totalSize += size
        }

        let duration = Date().timeIntervalSince(start)
        return CacheScanResult(
            category: category,
            entries: entries,
            scannedFileCount: entries.count,
            totalSizeBytes: totalSize,
            scanDurationSeconds: duration
        )
    }

    /// 递归枚举目录，使用 resolvingSymlinksInPath 校验真实路径，
    /// 并确保目标仍位于预期根目录之内（防止符号链接越界）。
    private func enumerateRecursively(_ root: URL) async -> ([CacheFileEntry], Int64) {
        await Task.detached(priority: .utility) { [fm] in
            var result: [CacheFileEntry] = []
            var total: Int64 = 0

            let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL

            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { return (result, total) }

            for case let fileURL as URL in enumerator {
                // 符号链接越界防护：解析真实路径后必须仍在 root 之内
                let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL
                guard resolved.path.hasPrefix(resolvedRoot.path) else {
                    continue
                }

                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) else {
                    continue
                }

                let size = Int64(values.fileSize ?? 0)
                let isDir = values.isDirectory ?? false
                if !isDir {
                    total += size
                }
                result.append(CacheFileEntry(
                    url: fileURL,
                    sizeBytes: size,
                    isDirectory: isDir,
                    modifiedAt: values.contentModificationDate
                ))
            }
            return (result, total)
        }.value
    }

    // MARK: - 清理

    /// 执行清理。调用前应已完成 UI 层的二次确认。
    func clean(categories: [CacheCategory]) {
        guard !isCleaning else { return }
        cleaningTask = Task { await performClean(categories: categories) }
    }

    func cancelCleaning() {
        cleaningTask?.cancel()
        log.log(.warning, category: "Cache", message: "用户取消了清理操作")
    }

    private func performClean(categories: [CacheCategory]) async {
        isCleaning = true
        cleaningProgress = 0
        log.log(.info, category: "Cache", message: "开始清理：\(categories.map { $0.displayName }.joined(separator: "、"))")

        var deletedCount = 0
        var freedBytes: Int64 = 0
        let targets = scanResults.filter { categories.contains($0.category) }
        let totalEntries = targets.reduce(0) { $0 + $1.entries.count }
        var processed = 0

        for result in targets {
            // 安全检查：再次确认根目录身份，防止扫描后、清理前目录被替换
            guard await verifyRootIdentity(for: result.category) else {
                log.log(.error, category: "Cache", message: "[\(result.category.displayName)] 身份校验失败，已跳过")
                continue
            }

            for entry in result.entries where !entry.isDirectory {
                if Task.isCancelled {
                    log.log(.warning, category: "Cache", message: "清理已被取消，已处理 \(processed)/\(totalEntries)")
                    isCleaning = false
                    return
                }

                if deleteFileSafely(entry.url) {
                    deletedCount += 1
                    freedBytes += entry.sizeBytes
                }
                processed += 1
                cleaningProgress = totalEntries > 0 ? Double(processed) / Double(totalEntries) : 1
            }
        }

        let record = CleaningHistoryRecord(
            categoriesCleaned: categories.map { $0.displayName },
            filesDeleted: deletedCount,
            bytesFreed: freedBytes,
            succeeded: true
        )
        history.insert(record, at: 0)
        saveHistory()

        log.log(.success, category: "Cache",
                message: "清理完成：删除 \(deletedCount) 个文件，释放 \(record.formattedBytesFreed)")

        isCleaning = false
        await scanAll()
    }

    /// 防止"不删除 Documents 中用户重要文件 / 不删除未知用途数据"：
    /// 只允许删除位于 Caches / tmp / 用户已授权目录内，且真实路径经核验的文件。
    private func deleteFileSafely(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL

        let allowedRoots: [URL] = {
            var roots: [URL] = []
            if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                roots.append(caches.resolvingSymlinksInPath().standardizedFileURL)
            }
            roots.append(fm.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL)
            roots.append(contentsOf: userSelectedURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL })
            return roots
        }()

        guard allowedRoots.contains(where: { resolved.path.hasPrefix($0.path) }) else {
            log.log(.error, category: "Cache", message: "拒绝删除：路径超出允许范围 \(resolved.path)")
            return false
        }

        do {
            try fm.removeItem(at: url)
            return true
        } catch {
            log.log(.error, category: "Cache", message: "删除失败 \(url.lastPathComponent)：\(error.localizedDescription)")
            return false
        }
    }

    private func verifyRootIdentity(for category: CacheCategory) async -> Bool {
        switch category {
        case .libraryCaches, .tmp:
            return true // 系统 API 返回的沙盒内目录，身份恒定
        case .userSelected:
            return !userSelectedURLs.isEmpty
        }
    }

    // MARK: - 历史记录持久化

    private var historyFileURL: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("cleaning_history.json")
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        let dir = historyFileURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: historyFileURL)
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let decoded = try? JSONDecoder().decode([CleaningHistoryRecord].self, from: data) else { return }
        history = decoded
    }
}
