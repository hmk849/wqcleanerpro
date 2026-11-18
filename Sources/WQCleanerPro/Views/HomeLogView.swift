import SwiftUI

struct HomeLogView: View {
    @ObservedObject private var log = LogManager.shared
    @ObservedObject private var compat = CompatibilityChecker.shared
    @State private var shareURL: URL?
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    statusHeader

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(log.entries) { entry in
                                logRow(entry).id(entry.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: log.entries.count) { _, _ in
                        guard log.autoScroll, let last = log.entries.last else { return }
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }

                    toolbar
                }
            }
            .navigationTitle("运行日志")
            .task {
                await compat.runAllChecks()
                if AppSettings.shared.autoScanOnLaunch {
                    await CacheManager.shared.scanAll()
                }
            }
            .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
                ShareSheet(items: [wrapped.url])
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    Text("已复制日志")
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 90)
                        .transition(.opacity)
                }
            }
        }
    }

    private var statusHeader: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(compat.report?.systemVersion.isEmpty == false ? "iOS \(compat.report!.systemVersion)" : "检测中…")
                        .font(.headline)
                    Text(compat.report?.deviceModel ?? "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let report = compat.report {
                    Label(report.allCriticalChecksPassed ? "全部正常" : "部分受限",
                          systemImage: report.allCriticalChecksPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(report.allCriticalChecksPassed ? .green : .orange)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.symbolName)
                .foregroundStyle(color(for: entry.level))
                .font(.caption)
                .frame(width: 16)
            Text(entry.formattedTimestamp)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("[\(entry.category)]")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(entry.message)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        }
    }

    private var toolbar: some View {
        GlassGroup {
            HStack(spacing: 10) {
                GlassButton(title: log.isPaused ? "继续" : "暂停", systemImage: log.isPaused ? "play.fill" : "pause.fill", kind: .plain) {
                    log.isPaused.toggle()
                }
                GlassButton(title: "清空", systemImage: "trash", kind: .destructive) {
                    log.clear()
                }
                GlassButton(title: "复制", systemImage: "doc.on.doc", kind: .plain) {
                    UIPasteboard.general.string = log.copyText
                    withAnimation { showCopiedToast = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation { showCopiedToast = false }
                    }
                }
                GlassButton(title: "导出", systemImage: "square.and.arrow.up", kind: .plain) {
                    shareURL = try? log.exportToTxt()
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
