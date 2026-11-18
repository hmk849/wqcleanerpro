import SwiftUI

struct GitHubActionsView: View {
    @ObservedObject private var auth = GitHubAuthManager.shared
    @ObservedObject private var actions = GitHubActionsService.shared

    @State private var selectedRepo: GHRepo?
    @State private var selectedBranch: GHBranch?
    @State private var selectedWorkflow: GHWorkflow?

    var body: some View {
        NavigationStack {
            Group {
                if auth.isLoggedIn {
                    buildCenter
                } else {
                    loginPrompt
                }
            }
            .navigationTitle("GitHub 云编译")
        }
    }

    // MARK: - 未登录

    private var loginPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48))
            Text("登录 GitHub 以使用云端编译")
                .font(.headline)

            if auth.isAuthenticating, let code = auth.userCode, let url = auth.verificationURL {
                VStack(spacing: 8) {
                    Text("打开 \(url)")
                        .font(.footnote)
                    Text(code)
                        .font(.title.bold().monospaced())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    ProgressView("等待授权…")
                }
            } else {
                GlassButton(title: "使用 GitHub 登录", systemImage: "arrow.right.circle") {
                    Task { await auth.startDeviceFlow() }
                }
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - 已登录

    private var buildCenter: some View {
        ScrollView {
            VStack(spacing: 16) {
                userHeader

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        picker("仓库", selection: $selectedRepo, options: actions.repos) { $0.fullName }
                            .onChange(of: selectedRepo) { _, repo in
                                guard let repo else { return }
                                Task {
                                    await actions.loadBranches(repo: repo)
                                    await actions.loadWorkflows(repo: repo)
                                }
                            }

                        picker("分支", selection: $selectedBranch, options: actions.branches) { $0.name }
                        picker("Workflow", selection: $selectedWorkflow, options: actions.workflows) { $0.name }

                        GlassButton(title: "一键启动编译", systemImage: "play.fill",
                                    isDisabled: selectedRepo == nil || selectedBranch == nil || selectedWorkflow == nil) {
                            guard let r = selectedRepo, let b = selectedBranch, let w = selectedWorkflow else { return }
                            Task {
                                await actions.triggerBuild(repo: r, workflow: w, branch: b)
                                await actions.loadRuns(repo: r, workflow: w)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                artifactKindLegend

                if !actions.runs.isEmpty {
                    runsSection
                }
            }
            .padding()
        }
        .task { await actions.loadRepos() }
    }

    private var userHeader: some View {
        GlassCard {
            HStack {
                AsyncImage(url: URL(string: auth.currentUser?.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text(auth.currentUser?.name ?? auth.currentUser?.login ?? "")
                        .font(.subheadline.bold())
                    Text("@\(auth.currentUser?.login ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                GlassButton(title: "退出登录", kind: .plain) {
                    auth.logout()
                }
            }
        }
    }

    private func picker<T: Hashable & Identifiable>(_ title: String, selection: Binding<T?>, options: [T], label: @escaping (T) -> String) -> some View {
        Menu {
            ForEach(options) { option in
                Button(label(option)) { selection.wrappedValue = option }
            }
        } label: {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(selection.wrappedValue.map(label) ?? "请选择")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
        }
        .font(.subheadline)
    }

    private var artifactKindLegend: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("产物类型说明", systemImage: "shippingbox")
                    .font(.footnote.bold())
                ForEach([BuildArtifactKind.simulator, .unsignedIPA, .signedIPA], id: \.self) { kind in
                    Text("• \(kind.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("历史运行记录")
                    .font(.subheadline.bold())
                ForEach(actions.runs) { run in
                    HStack {
                        statusIcon(for: run)
                        VStack(alignment: .leading) {
                            Text("#\(run.id) · \(run.status)")
                                .font(.caption)
                            Text(run.createdAt)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if run.status != "completed" {
                            Button("取消") {
                                guard let repo = selectedRepo else { return }
                                Task { await actions.cancelRun(repo: repo, runID: run.id) }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func statusIcon(for run: GHWorkflowRun) -> some View {
        let (symbol, color): (String, Color) = {
            switch (run.status, run.conclusion) {
            case ("completed", "success"): return ("checkmark.circle.fill", .green)
            case ("completed", _): return ("xmark.circle.fill", .red)
            default: return ("clock.fill", .orange)
            }
        }()
        return Image(systemName: symbol).foregroundStyle(color)
    }
}

extension BuildArtifactKind: CaseIterable, Hashable {}
