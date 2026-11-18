import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    private let accentOptions: [(name: String, hex: String)] = [
        ("蓝", "#007AFF"), ("紫", "#AF52DE"), ("绿", "#34C759"),
        ("橙", "#FF9500"), ("粉", "#FF2D55")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    Picker("外观模式", selection: Binding(
                        get: { settings.colorScheme },
                        set: { settings.colorScheme = $0 }
                    )) {
                        ForEach(AppColorScheme.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    HStack {
                        Text("主题色")
                        Spacer()
                        ForEach(accentOptions, id: \.hex) { option in
                            Circle()
                                .fill(Color(hex: option.hex) ?? .blue)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if settings.accentColorHex == option.hex {
                                        Circle().stroke(.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { settings.accentColorHex = option.hex }
                        }
                    }

                    Toggle("触觉反馈", isOn: $settings.hapticsEnabled)
                    Toggle("动画效果", isOn: $settings.animationsEnabled)
                }

                Section("清理行为") {
                    Toggle("启动时自动扫描", isOn: $settings.autoScanOnLaunch)
                    Toggle("清理前二次确认", isOn: $settings.confirmBeforeClean)
                }

                Section("日志") {
                    Toggle("详细日志（Debug 级别）", isOn: $settings.verboseLogging)
                }

                Section("关于") {
                    NavigationLink("隐私政策") { PlainTextInfoView(title: "隐私政策", text: privacyPolicyText) }
                    NavigationLink("开源许可") { OpenSourceLicensesView() }
                    NavigationLink("关于本应用") { AboutView() }
                }
            }
            .navigationTitle("设置")
        }
    }

    private var privacyPolicyText: String {
        """
        WQ Cleaner Pro 仅在本机处理数据：

        · 缓存扫描与清理范围限定在本 App 自身的 Library/Caches、tmp 目录，以及用户手动选择并授权的外部目录；不会读取、枚举或上传其他 App 的数据。
        · GitHub 登录采用官方 OAuth Device Flow，访问令牌仅保存在系统 Keychain，不上传至任何第三方服务器。
        · 本应用不包含广告 SDK、不进行跨 App 追踪。
        """
    }
}

private struct PlainTextInfoView: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote)
                .padding()
        }
        .navigationTitle(title)
    }
}

private struct OpenSourceLicensesView: View {
    var body: some View {
        List {
            Section("本项目") {
                Text("WQ Cleaner Pro — 独立实现，未搬运任何第三方仓库代码。")
                    .font(.footnote)
            }
            Section("参考资料（仅设计思路，非代码引用）") {
                Text("Apple Liquid Glass 官方文档与设计规范")
                    .font(.footnote)
            }
        }
        .navigationTitle("开源许可")
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section("开发者") {
                Link("hmk849 · GitHub", destination: URL(string: "https://github.com/hmk849")!)
            }
            Section("AI 开发支持") {
                Link("ChatGPT", destination: URL(string: "https://chatgpt.com")!)
                Link("Claude", destination: URL(string: "https://claude.ai")!)
                Link("Muse", destination: URL(string: "https://museapp.com")!)
            }
            Section("版本") {
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
    }
}
