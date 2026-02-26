import SwiftUI

enum ColorTokens {

    // MARK: - Primary

    static let primary = Color(hex: "#6C5CE7")
    static let primaryLight = Color(hex: "#A29BFE")
    static let primaryDark = Color(hex: "#4A3ABA")

    // MARK: - Background (Dark Mode)

    static let backgroundDark = Color(hex: "#0A0A0F")
    static let surfaceDark = Color(hex: "#16161E")
    static let surfaceElevatedDark = Color(hex: "#1E1E2A")
    static let cardDark = Color(hex: "#22222E")

    // MARK: - Background (Light Mode)

    static let backgroundLight = Color(hex: "#F8F9FA")
    static let surfaceLight = Color.white
    static let surfaceElevatedLight = Color.white
    static let cardLight = Color.white

    // MARK: - Text (Dark Mode)

    static let textPrimaryDark = Color.white
    static let textSecondaryDark = Color(hex: "#8E8EA0")
    static let textTertiaryDark = Color(hex: "#52526B")

    // MARK: - Text (Light Mode)

    static let textPrimaryLight = Color(hex: "#1A1A2E")
    static let textSecondaryLight = Color(hex: "#6B7280")
    static let textTertiaryLight = Color(hex: "#9CA3AF")

    // MARK: - Accents

    static let success = Color(hex: "#00C48C")
    static let warning = Color(hex: "#FFB347")
    static let error = Color(hex: "#FF6B6B")
    static let info = Color(hex: "#4DA6FF")

    // MARK: - Creator Tiers

    static let anchorGold = Color(hex: "#FFD700")
    static let coreSilver = Color(hex: "#C0C0C0")
    static let risingBronze = Color(hex: "#CD7F32")

    // MARK: - Gradients

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#6C5CE7"), Color(hex: "#A29BFE"), Color(hex: "#FD79A8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardOverlayGradient = LinearGradient(
        colors: [.clear, Color.black.opacity(0.85)],
        startPoint: .init(x: 0.5, y: 0.4),
        endPoint: .bottom
    )

    static let progressGradient = LinearGradient(
        colors: [Color(hex: "#6C5CE7"), Color(hex: "#00C48C")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Adaptive Colors (resolve based on color scheme)

    @MainActor
    static var background: Color {
        resolveColor(dark: backgroundDark, light: backgroundLight)
    }

    @MainActor
    static var surface: Color {
        resolveColor(dark: surfaceDark, light: surfaceLight)
    }

    @MainActor
    static var surfaceElevated: Color {
        resolveColor(dark: surfaceElevatedDark, light: surfaceElevatedLight)
    }

    @MainActor
    static var card: Color {
        resolveColor(dark: cardDark, light: cardLight)
    }

    @MainActor
    static var textPrimary: Color {
        resolveColor(dark: textPrimaryDark, light: textPrimaryLight)
    }

    @MainActor
    static var textSecondary: Color {
        resolveColor(dark: textSecondaryDark, light: textSecondaryLight)
    }

    @MainActor
    static var textTertiary: Color {
        resolveColor(dark: textTertiaryDark, light: textTertiaryLight)
    }

    // MARK: - Helper

    @MainActor
    private static func resolveColor(dark: Color, light: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
