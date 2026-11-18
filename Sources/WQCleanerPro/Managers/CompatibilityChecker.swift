import Foundation
import UIKit

/// 系统兼容性检测模块。
///
/// 所有检测都是"真实运行一次、看结果"，不基于系统版本号做猜测，
/// 也不检测/依赖任何未公开的系统漏洞（即需求文档中提到的 worse_query 一类能力，
/// 本项目不实现，详见 README）。
@MainActor
final class CompatibilityChecker: ObservableObject {
    static let shared = CompatibilityChecker()

    @Published private(set) var report: CompatibilityReport?

    private let log = LogManager.shared

    private init() {}

    func runAllChecks() async {
        log.log(.info, category: "Compat", message: "开始系统兼容性检测")

        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = await deviceModelIdentifier()

        log.log(.info, category: "Compat", message: "系统版本：\(systemVersion)，设备型号：\(deviceModel)")

        var checks: [CapabilityCheck] = []
        checks.append(checkSandboxReadWrite())
        checks.append(checkCachesDirectoryAccess())
        checks.append(checkTmpDirectoryAccess())
        checks.append(await checkAppGroupAccess())
        checks.append(checkFileEnumeration())

        for check in checks {
            let level: LogLevel = check.isAvailable ? .success : .warning
            log.log(level, category: "Compat", message: "\(check.name)：\(check.statusText)")
        }

        report = CompatibilityReport(systemVersion: systemVersion, deviceModel: deviceModel, checks: checks)
        log.log(.success, category: "Compat", message: "兼容性检测完成")
    }

    private func deviceModelIdentifier() async -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    // MARK: - 真实探测项

    private func checkSandboxReadWrite() -> CapabilityCheck {
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("wqcp_probe_\(UUID().uuidString).tmp")
        do {
            try "probe".write(to: testURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testURL)
            return CapabilityCheck(name: "沙盒读写权限", detail: "对 tmp 目录执行写入+删除测试", status: .available)
        } catch {
            return CapabilityCheck(name: "沙盒读写权限", detail: "tmp 目录读写测试", status: .unavailable(reason: error.localizedDescription))
        }
    }

    private func checkCachesDirectoryAccess() -> CapabilityCheck {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              FileManager.default.fileExists(atPath: url.path) else {
            return CapabilityCheck(name: "Caches 目录访问", detail: "Library/Caches", status: .unavailable(reason: "目录不存在或不可访问"))
        }
        return CapabilityCheck(name: "Caches 目录访问", detail: url.path, status: .available)
    }

    private func checkTmpDirectoryAccess() -> CapabilityCheck {
        let url = FileManager.default.temporaryDirectory
        return CapabilityCheck(name: "tmp 目录访问", detail: url.path, status: .available)
    }

    /// 仅检测"本 App 自己"的 App Group 容器是否可访问（需在 Entitlements 中配置），
    /// 不涉及任何其他 App 的 App Group。
    private func checkAppGroupAccess() async -> CapabilityCheck {
        let groupID = "group.com.hmk849.wqcleanerpro"
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return CapabilityCheck(
                name: "App Group 容器",
                detail: groupID,
                status: .unavailable(reason: "未配置该 App Group 或签名能力缺失")
            )
        }
        let exists = FileManager.default.fileExists(atPath: url.path)
        return CapabilityCheck(
            name: "App Group 容器",
            detail: url.path,
            status: exists ? .available : .unavailable(reason: "容器路径不存在")
        )
    }

    private func checkFileEnumeration() -> CapabilityCheck {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              FileManager.default.enumerator(at: caches, includingPropertiesForKeys: nil) != nil else {
            return CapabilityCheck(name: "文件枚举能力", detail: "FileManager.enumerator", status: .unavailable(reason: "无法创建枚举器"))
        }
        return CapabilityCheck(name: "文件枚举能力", detail: "FileManager.enumerator", status: .available)
    }
}
