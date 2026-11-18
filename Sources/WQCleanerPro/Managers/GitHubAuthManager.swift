import Foundation
import Security

/// GitHub 账号信息（登录后展示用）
struct GitHubUser: Codable, Equatable {
    let login: String
    let name: String?
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarURL = "avatar_url"
    }
}

/// GitHub OAuth 管理：使用 Device Authorization Flow（无需在 App 内嵌入 Client Secret），
/// Token 只存 Keychain，不写入 UserDefaults / 日志 / 硬编码。
@MainActor
final class GitHubAuthManager: ObservableObject {
    static let shared = GitHubAuthManager()

    @Published private(set) var currentUser: GitHubUser?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var deviceCode: String?
    @Published private(set) var userCode: String?
    @Published private(set) var verificationURL: String?

    /// 需要在你自己的 GitHub OAuth App 设置里创建，并作为 Build Setting / xcconfig 注入，
    /// 绝不硬编码真实值提交到仓库。
    private let clientID: String = ProcessInfo.processInfo.environment["GITHUB_OAUTH_CLIENT_ID"] ?? ""

    private let keychainService = "com.hmk849.wqcleanerpro.github"
    private let keychainAccount = "oauth_token"
    private let log = LogManager.shared

    private init() {
        if let _ = loadToken() {
            Task { await fetchCurrentUser() }
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - Device Flow

    func startDeviceFlow() async {
        guard !clientID.isEmpty else {
            log.log(.error, category: "GitHub", message: "未配置 GITHUB_OAUTH_CLIENT_ID，无法发起登录")
            return
        }
        isAuthenticating = true
        log.log(.info, category: "GitHub", message: "发起 Device Authorization 请求")

        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "client_id=\(clientID)&scope=repo%20workflow".data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
            deviceCode = result.deviceCode
            userCode = result.userCode
            verificationURL = result.verificationUri
            log.log(.success, category: "GitHub", message: "请在浏览器打开 \(result.verificationUri) 并输入代码 \(result.userCode)")
            await pollForToken(deviceCode: result.deviceCode, interval: result.interval)
        } catch {
            log.log(.error, category: "GitHub", message: "Device Flow 启动失败：\(error.localizedDescription)")
            isAuthenticating = false
        }
    }

    private func pollForToken(deviceCode: String, interval: Int) async {
        var delay = UInt64(max(interval, 5)) * 1_000_000_000
        for _ in 0..<60 { // 最多轮询 ~5-10 分钟
            try? await Task.sleep(nanoseconds: delay)
            do {
                var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)

                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(TokenPollResponse.self, from: data)

                if let token = result.accessToken {
                    saveToken(token)
                    log.log(.success, category: "GitHub", message: "登录成功")
                    await fetchCurrentUser()
                    isAuthenticating = false
                    return
                }

                if result.error == "slow_down" {
                    delay += 5_000_000_000
                } else if let err = result.error, err != "authorization_pending" {
                    log.log(.error, category: "GitHub", message: "登录失败：\(err)")
                    isAuthenticating = false
                    return
                }
            } catch {
                log.log(.error, category: "GitHub", message: "轮询 Token 出错：\(error.localizedDescription)")
            }
        }
        log.log(.warning, category: "GitHub", message: "登录等待超时，请重试")
        isAuthenticating = false
    }

    private func fetchCurrentUser() async {
        guard let token = loadToken() else { return }
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            currentUser = try JSONDecoder().decode(GitHubUser.self, from: data)
            log.log(.info, category: "GitHub", message: "当前登录用户：\(currentUser?.login ?? "-")")
        } catch {
            log.log(.error, category: "GitHub", message: "获取用户信息失败：\(error.localizedDescription)")
        }
    }

    func logout() {
        deleteToken()
        currentUser = nil
        log.log(.info, category: "GitHub", message: "已退出登录")
    }

    func token() -> String? { loadToken() }

    // MARK: - Keychain

    private func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - DTOs

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case interval
    }
}

private struct TokenPollResponse: Decodable {
    let accessToken: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
    }
}
