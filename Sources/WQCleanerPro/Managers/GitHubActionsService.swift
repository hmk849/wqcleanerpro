import Foundation

struct GHRepo: Identifiable, Decodable, Hashable {
    var id: Int
    let name: String
    let fullName: String
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case defaultBranch = "default_branch"
    }
}

struct GHBranch: Identifiable, Decodable, Hashable {
    var id: String { name }
    let name: String
}

struct GHWorkflow: Identifiable, Decodable, Hashable {
    var id: Int
    let name: String
    let path: String
    let state: String
}

enum BuildArtifactKind: String {
    case simulator = "模拟器编译（无需签名，仅验证可编译）"
    case unsignedIPA = "未签名 IPA（需自行重新签名后安装）"
    case signedIPA = "已签名可安装 IPA（需在 Secrets 中配置证书与描述文件）"
}

struct GHWorkflowRun: Identifiable, Decodable, Hashable {
    var id: Int
    let status: String
    let conclusion: String?
    let htmlURL: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, conclusion
        case htmlURL = "html_url"
        case createdAt = "created_at"
    }
}

/// 与 GitHub Actions REST API 通信，驱动"GitHub 云端编译"页面。
@MainActor
final class GitHubActionsService: ObservableObject {
    static let shared = GitHubActionsService()

    @Published private(set) var repos: [GHRepo] = []
    @Published private(set) var branches: [GHBranch] = []
    @Published private(set) var workflows: [GHWorkflow] = []
    @Published private(set) var runs: [GHWorkflowRun] = []
    @Published private(set) var isBusy = false

    private let log = LogManager.shared
    private var auth: GitHubAuthManager { GitHubAuthManager.shared }

    private init() {}

    private func authorizedRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = auth.token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    func loadRepos() async {
        isBusy = true
        log.log(.info, category: "GitHub", message: "获取仓库列表")
        do {
            let url = URL(string: "https://api.github.com/user/repos?per_page=100&sort=updated")!
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(url))
            repos = try JSONDecoder().decode([GHRepo].self, from: data)
            log.log(.success, category: "GitHub", message: "获取到 \(repos.count) 个仓库")
        } catch {
            log.log(.error, category: "GitHub", message: "获取仓库失败：\(error.localizedDescription)")
        }
        isBusy = false
    }

    func loadBranches(repo: GHRepo) async {
        log.log(.info, category: "GitHub", message: "获取分支：\(repo.fullName)")
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/branches?per_page=100")!
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(url))
            branches = try JSONDecoder().decode([GHBranch].self, from: data)
        } catch {
            log.log(.error, category: "GitHub", message: "获取分支失败：\(error.localizedDescription)")
        }
    }

    func loadWorkflows(repo: GHRepo) async {
        log.log(.info, category: "GitHub", message: "获取 Workflow 列表：\(repo.fullName)")
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/actions/workflows")!
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(url))
            let decoded = try JSONDecoder().decode(WorkflowListResponse.self, from: data)
            workflows = decoded.workflows
        } catch {
            log.log(.error, category: "GitHub", message: "获取 Workflow 失败：\(error.localizedDescription)")
        }
    }

    /// 触发 workflow_dispatch
    func triggerBuild(repo: GHRepo, workflow: GHWorkflow, branch: GHBranch) async {
        log.log(.info, category: "GitHub", message: "触发编译：\(repo.fullName) @ \(branch.name) · \(workflow.name)")
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/actions/workflows/\(workflow.id)/dispatches")!
            var request = authorizedRequest(url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["ref": branch.name])
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                log.log(.success, category: "GitHub", message: "编译任务已触发")
            } else {
                log.log(.error, category: "GitHub", message: "触发失败，HTTP 状态码异常")
            }
        } catch {
            log.log(.error, category: "GitHub", message: "触发编译出错：\(error.localizedDescription)")
        }
    }

    func loadRuns(repo: GHRepo, workflow: GHWorkflow) async {
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/actions/workflows/\(workflow.id)/runs?per_page=20")!
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(url))
            let decoded = try JSONDecoder().decode(RunListResponse.self, from: data)
            runs = decoded.workflowRuns
        } catch {
            log.log(.error, category: "GitHub", message: "获取历史运行记录失败：\(error.localizedDescription)")
        }
    }

    func cancelRun(repo: GHRepo, runID: Int) async {
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/actions/runs/\(runID)/cancel")!
            var request = authorizedRequest(url)
            request.httpMethod = "POST"
            _ = try await URLSession.shared.data(for: request)
            log.log(.warning, category: "GitHub", message: "已请求取消运行 #\(runID)")
        } catch {
            log.log(.error, category: "GitHub", message: "取消失败：\(error.localizedDescription)")
        }
    }
}

private struct WorkflowListResponse: Decodable {
    let workflows: [GHWorkflow]
}

private struct RunListResponse: Decodable {
    let workflowRuns: [GHWorkflowRun]
    enum CodingKeys: String, CodingKey {
        case workflowRuns = "workflow_runs"
    }
}
