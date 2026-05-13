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
}

// Note: We use View extensions instead of ViewModifier types because the
// module has a top-level `Content` model struct that shadows ViewModifier's
// `Content` associatedtype when ViewModifier types are nested in another type.

extension View {
    /// Wraps the view in a v2 card chrome (background + border + rounded corners).
    func v2Card(padding: CGFloat = 18) -> some View {
        self
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

    /// Styles text as a small-caps eyebrow above headings.
    func v2Eyebrow(_ color: Color = ColorTokens.gold) -> some View {
        self
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
