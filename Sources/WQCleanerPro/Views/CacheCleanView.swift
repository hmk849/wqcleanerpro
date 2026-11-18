import SwiftUI
import UniformTypeIdentifiers

struct CacheCleanView: View {
    @ObservedObject private var cache = CacheManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showConfirm = false
    @State private var pendingCategories: [CacheCategory] = []
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    ForEach(cache.scanResults) { result in
                        categoryCard(result)
                    }

                    addFolderButton

                    actionBar

                    noticeSection
                }
                .padding()
            }
            .navigationTitle("缓存清理")
            .refreshable { await cache.scanAll() }
            .confirmationDialog(
                "确认清理",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("确认删除", role: .destructive) {
                    cache.clean(categories: pendingCategories)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除所选分类下的全部文件，此操作不可撤销。")
            }
            .sheet(isPresented: $showDocumentPicker) {
                FolderPicker { url in
                    if let url {
                        cache.userSelectedURLs.append(url)
                        Task { await cache.scanAll() }
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("可释放空间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalFormattedSize)
                        .font(.title2.bold())
                }
                Spacer()
                if cache.isScanning {
                    ProgressView()
                } else {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(settings.accentColor)
                }
            }
        }
    }

    private var totalFormattedSize: String {
        let total = cache.scanResults.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func categoryCard(_ result: CacheScanResult) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: result.category.iconName)
                        .foregroundStyle(settings.accentColor)
                    Text(result.category.displayName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(result.formattedSize)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("\(result.scannedFileCount) 个文件 · 耗时 \(String(format: "%.2f", result.scanDurationSeconds))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    GlassButton(title: "清理此项", systemImage: "trash", kind: .destructive,
                                isDisabled: result.scannedFileCount == 0 || cache.isCleaning) {
                        requestClean([result.category])
                    }
                }
            }
        }
    }

    private var addFolderButton: some View {
        Button {
            showDocumentPicker = true
        } label: {
            Label("手动选择一个文件夹加入清理范围", systemImage: "folder.badge.plus")
                .font(.footnote)
        }
        .padding(.top, 4)
    }

    private var actionBar: some View {
        GlassGroup {
            VStack(spacing: 10) {
                if cache.isCleaning {
                    ProgressView(value: cache.cleaningProgress)
                    HStack {
                        Text("清理中…\(Int(cache.cleaningProgress * 100))%")
                            .font(.caption)
                        Spacer()
                        GlassButton(title: "取消", kind: .plain) {
                            cache.cancelCleaning()
                        }
                    }
                } else {
                    GlassButton(title: "一键清理全部", systemImage: "wand.and.stars", isDisabled: cache.scanResults.isEmpty) {
                        requestClean(cache.scanResults.map { $0.category })
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    private func requestClean(_ categories: [CacheCategory]) {
        if settings.confirmBeforeClean {
            pendingCategories = categories
            showConfirm = true
        } else {
            cache.clean(categories: categories)
        }
    }

    private var noticeSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("说明事项", systemImage: "exclamationmark.circle")
                    .font(.footnote.bold())
                Group {
                    Text("1. 不同 iOS 版本对文件系统的权限策略可能不同，部分系统目录可能无法访问。")
                    Text("2. 清理缓存可能导致部分内容需要重新下载或重新生成。")
                    Text("3. 重要数据请在清理前自行备份；本工具不会清理 Documents 中的用户文件。")
                    Text("4. 不支持的系统版本不会强制执行清理，会在兼容性检测中明确提示原因。")
                    Text("5. 所有扫描与清理的容量数字均来自真实文件系统统计，不做估算或虚构。")
                    Text("6. 本工具仅清理本 App 自身沙盒目录及用户手动授权的目录，不访问其他已安装 App 的数据。")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// 系统文件选择器封装，用于用户主动授权一个外部目录加入清理范围。
struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onPick(nil); return }
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}
