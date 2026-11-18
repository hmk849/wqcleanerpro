import SwiftUI

enum GlassButtonStyleKind {
    case primary
    case destructive
    case plain
}

/// 玻璃悬浮按钮
struct GlassButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: GlassButtonStyleKind = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button {
            if settings.hapticsEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(foregroundColor)
        }
        .background {
            if #available(iOS 26.0, *) {
                Capsule().glassEffect(.regular.tint(tintColor), in: Capsule())
            } else {
                Capsule().fill(tintColor.opacity(0.85))
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private var tintColor: Color {
        switch kind {
        case .primary: return settings.accentColor
        case .destructive: return .red
        case .plain: return .gray
        }
    }

    private var foregroundColor: Color {
        kind == .plain ? .primary : .white
    }
}
