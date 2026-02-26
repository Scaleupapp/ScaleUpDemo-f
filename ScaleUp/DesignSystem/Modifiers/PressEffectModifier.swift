import SwiftUI

// MARK: - PressEffectButtonStyle

private struct PressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: - PressEffectModifier

struct PressEffectModifier: ViewModifier {
    func body(content: Self.Content) -> some View {
        Button {
            // No-op; the view itself handles actions
        } label: {
            content
        }
        .buttonStyle(PressEffectButtonStyle())
    }
}

// MARK: - View Extension

extension View {
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }
}
