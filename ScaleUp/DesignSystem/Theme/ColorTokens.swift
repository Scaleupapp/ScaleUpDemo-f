import SwiftUI

// MARK: - ScaleUp Color System
// Gold + dark teal — premium dark palette from brand logo

enum ColorTokens {

    // MARK: - Primary Gold

    static let gold = Color(hex: 0xE8B84B)
    static let goldLight = Color(hex: 0xF5D980)
    static let goldDark = Color(hex: 0xC99A2E)

    static let goldGradient = LinearGradient(
        colors: [goldDark, gold, goldLight, gold, goldDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldShimmer = LinearGradient(
        colors: [gold, goldLight, gold],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Backgrounds

    static let background = Color(hex: 0x0B1E28)
    static let surface = Color(hex: 0x122D3A)
    static let surfaceElevated = Color(hex: 0x1A3B4D)
    static let card = Color(hex: 0x1F4456)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xA3C4D4)
    static let textTertiary = Color(hex: 0x6B94A6)
    static let textGold = gold

    // MARK: - Accents

    static let success = Color(hex: 0x34D399)
    static let warning = Color(hex: 0xFBBF24)
    static let error = Color(hex: 0xEF4444)
    static let info = Color(hex: 0x60A5FA)

    // MARK: - Creator Tiers

    static let tierAnchor = gold
    static let tierCore = Color(hex: 0xC0C0C0)
    static let tierRising = Color(hex: 0xCD7F32)

    // MARK: - Progress & Journey

    static let progressGradient = LinearGradient(
        colors: [gold, success],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let streakActive = Color(hex: 0xFB923C)
    static let streakInactive = Color(hex: 0x547584)

    // MARK: - Gradients

    static let heroGradient = LinearGradient(
        colors: [gold.opacity(0.4), background],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardOverlay = LinearGradient(
        colors: [.clear, background.opacity(0.95)],
        startPoint: .init(x: 0.5, y: 0.3),
        endPoint: .bottom
    )

    static let achievementGlow = RadialGradient(
        colors: [gold.opacity(0.3), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 120
    )

    // MARK: - Borders & Dividers

    static let border = Color.white.opacity(0.10)
    static let divider = Color.white.opacity(0.12)
    static let tabBarBorder = Color.white.opacity(0.06)

    // MARK: - Interactive States

    static let buttonPrimaryBg = gold
    static let buttonPrimaryText = Color(hex: 0x0B1E28)
    static let buttonSecondaryBg = surfaceElevated
    static let buttonSecondaryText = Color.white
    static let buttonDisabledBg = Color(hex: 0x1B3040)
    static let buttonDisabledText = textTertiary
}

// MARK: - SwiftUI Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
