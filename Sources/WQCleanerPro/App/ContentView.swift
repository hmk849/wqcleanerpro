import SwiftUI

struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            HomeLogView()
                .tabItem { Label("日志", systemImage: "doc.text.magnifyingglass") }

            CacheCleanView()
                .tabItem { Label("缓存清理", systemImage: "externaldrive.fill.badge.minus") }

            GitHubActionsView()
                .tabItem { Label("云编译", systemImage: "icloud.and.arrow.up") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(settings.accentColor)
        .preferredColorScheme(settings.colorScheme.colorScheme)
        .environmentObject(settings)
    }
}

#Preview {
    ContentView()
}
