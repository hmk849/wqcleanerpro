import SwiftUI

/// 基于 iOS 26 原生 Liquid Glass（glassEffect）的卡片容器。
/// 在不支持 glassEffect 的环境（旧 OS / 预览）下自动降级为 .ultraThinMaterial，
/// 保证不崩溃、不使用廉价的全屏模糊。
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}

/// 多个玻璃元素组合时使用的容器，保证过渡流畅、阴影统一。
/// iOS 26 以下降级为普通 VStack。
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            VStack(spacing: 12) { content }
        }
    }
}
