import SwiftUI

/// V2-specific design tokens. Reuses ColorTokens (gold/dark teal) but tightens
/// type, spacing, and shape language for the v2 redesign.
enum V2Theme {

    // MARK: - Type

    static let h1 = Font.system(size: 26, weight: .bold, design: .default)
    static let h2 = Font.system(size: 20, weight: .bold, design: .default)
    static let h3 = Font.system(size: 16, weight: .semibold, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)
    static let small = Font.system(size: 12, weight: .regular, design: .default)
    static let tiny = Font.system(size: 10, weight: .semibold, design: .default)

    // MARK: - Spacing

    static let pad: CGFloat = 20
    static let gap: CGFloat = 12
    static let cardRadius: CGFloat = 16

    // MARK: - Surfaces

    static let cardBg = ColorTokens.surface
    static let cardBorder = ColorTokens.surfaceElevated.opacity(0.7)
    static let heroGradient = LinearGradient(
        colors: [ColorTokens.card, ColorTokens.surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Common modifiers

    struct CardStyle: ViewModifier {
        var padding: CGFloat = 18
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                        .fill(V2Theme.cardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                        .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    struct PillStyle: ViewModifier {
        var color: Color = ColorTokens.gold
        func body(content: Content) -> some View {
            content
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(color)
        }
    }
}

extension View {
    func v2Card(padding: CGFloat = 18) -> some View {
        modifier(V2Theme.CardStyle(padding: padding))
    }

    func v2Eyebrow(_ color: Color = ColorTokens.gold) -> some View {
        modifier(V2Theme.PillStyle(color: color))
    }
}
