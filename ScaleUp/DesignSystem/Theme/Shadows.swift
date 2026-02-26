import SwiftUI

// MARK: - Shadow Modifiers

private struct SmallShadow: ViewModifier {
    func body(content: Self.Content) -> some View {
        content.shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

private struct MediumShadow: ViewModifier {
    func body(content: Self.Content) -> some View {
        content.shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

private struct LargeShadow: ViewModifier {
    func body(content: Self.Content) -> some View {
        content.shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}

private struct GlowShadow: ViewModifier {
    var color: Color

    func body(content: Self.Content) -> some View {
        content.shadow(color: color.opacity(0.5), radius: 12, x: 0, y: 0)
    }
}

// MARK: - Shadows

enum Shadows {
    static var small: some ViewModifier { SmallShadow() }
    static var medium: some ViewModifier { MediumShadow() }
    static var large: some ViewModifier { LargeShadow() }
    static var glow: some ViewModifier { GlowShadow(color: ColorTokens.primary) }
}

// MARK: - View Extension

extension View {
    func shadowSmall() -> some View {
        modifier(SmallShadow())
    }

    func shadowMedium() -> some View {
        modifier(MediumShadow())
    }

    func shadowLarge() -> some View {
        modifier(LargeShadow())
    }

    func glowEffect(color: Color = ColorTokens.primary) -> some View {
        modifier(GlowShadow(color: color))
    }
}
