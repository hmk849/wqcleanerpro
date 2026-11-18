import SwiftUI
import Combine

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 全局设置，使用 AppStorage 持久化到 UserDefaults（不含任何敏感信息）。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("wqcp.colorScheme") var colorSchemeRaw: String = AppColorScheme.system.rawValue
    @AppStorage("wqcp.hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("wqcp.animationsEnabled") var animationsEnabled: Bool = true
    @AppStorage("wqcp.autoScanOnLaunch") var autoScanOnLaunch: Bool = true
    @AppStorage("wqcp.confirmBeforeClean") var confirmBeforeClean: Bool = true
    @AppStorage("wqcp.verboseLogging") var verboseLogging: Bool = false
    @AppStorage("wqcp.accentColorHex") var accentColorHex: String = "#007AFF"

    var colorScheme: AppColorScheme {
        get { AppColorScheme(rawValue: colorSchemeRaw) ?? .system }
        set { colorSchemeRaw = newValue.rawValue }
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }

    private init() {}
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
