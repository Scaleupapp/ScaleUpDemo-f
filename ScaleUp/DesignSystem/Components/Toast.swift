import SwiftUI

// MARK: - ToastStyle

enum ToastStyle {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return ColorTokens.success
        case .error: return ColorTokens.error
        case .warning: return ColorTokens.warning
        case .info: return ColorTokens.info
        }
    }
}

// MARK: - Toast

struct Toast: Equatable {
    let message: String
    let style: ToastStyle
}

// MARK: - ToastView

struct ToastView: View {
    let message: String
    let style: ToastStyle

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: style.icon)
                .font(Typography.bodyBold)
                .foregroundStyle(style.color)

            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceElevatedDark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - ToastModifier

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Self.Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastView(message: toast.message, style: toast.style)
                        .padding(.top, Spacing.xl)
                        .padding(.horizontal, Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if value.translation.height < -10 {
                                        dismiss()
                                    }
                                }
                        )
                        .onAppear {
                            scheduleDismiss()
                        }
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: toast)
    }

    // MARK: - Private

    private func scheduleDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            dismiss()
        }
    }

    private func dismiss() {
        toast = nil
    }
}

// MARK: - View Extension

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}
