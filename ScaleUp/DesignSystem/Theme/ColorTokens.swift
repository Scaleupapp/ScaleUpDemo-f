import SwiftUI
import UIKit

// MARK: - ScaleUp Color System
// Gold + adaptive dark/light — premium palette from brand logo

enum ColorTokens {

    // MARK: - Primary Gold

    static let gold = Color(adaptive(dark: 0xE8B84B, light: 0xB8891A))
    static let goldLight = Color(adaptive(dark: 0xF5D980, light: 0xD4A42E))
    static let goldDark = Color(adaptive(dark: 0xC99A2E, light: 0x8E6A10))

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [goldDark, gold, goldLight, gold, goldDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldShimmer: LinearGradient {
        LinearGradient(
            colors: [gold, goldLight, gold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Backgrounds

    static let background = Color(adaptive(dark: 0x0B1E28, light: 0xF2EFE9))
    static let surface = Color(adaptive(dark: 0x122D3A, light: 0xFFFFFF))
    static let surfaceElevated = Color(adaptive(dark: 0x1A3B4D, light: 0xEAE7E0))
    static let card = Color(adaptive(dark: 0x1F4456, light: 0xFFFFFF))

    // MARK: - Text

    static let textPrimary = Color(adaptive(dark: 0xFFFFFF, light: 0x1A1A1A))
    static let textSecondary = Color(adaptive(dark: 0xA3C4D4, light: 0x44444A))
    static let textTertiary = Color(adaptive(dark: 0x6B94A6, light: 0x6B6B72))
    static let textGold = gold

    // MARK: - Accents (adaptive for contrast on both backgrounds)

    static let success = Color(adaptive(dark: 0x34D399, light: 0x059669))
    static let warning = Color(adaptive(dark: 0xFBBF24, light: 0xD97706))
    static let error = Color(adaptive(dark: 0xEF4444, light: 0xDC2626))
    static let info = Color(adaptive(dark: 0x60A5FA, light: 0x2563EB))

    // MARK: - Creator Tiers

    static let tierAnchor = gold
    static let tierCore = Color(adaptive(dark: 0xC0C0C0, light: 0x808080))
    static let tierRising = Color(adaptive(dark: 0xCD7F32, light: 0xA0622A))

    // MARK: - Progress & Journey

    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [gold, success],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let streakActive = Color(adaptive(dark: 0xFB923C, light: 0xEA7A1A))
    static let streakInactive = Color(adaptive(dark: 0x547584, light: 0xB0B0B0))

    // MARK: - Gradients

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [gold.opacity(0.4), background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardOverlay: LinearGradient {
        LinearGradient(
            colors: [.clear, background.opacity(0.95)],
            startPoint: .init(x: 0.5, y: 0.3),
            endPoint: .bottom
        )
    }

    static var achievementGlow: RadialGradient {
        RadialGradient(
            colors: [gold.opacity(0.3), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 120
        )
    }

    // MARK: - Borders & Dividers

    static let border = Color(adaptive(
        darkColor: UIColor.white.withAlphaComponent(0.10),
        lightColor: UIColor.black.withAlphaComponent(0.14)
    ))
    static let divider = Color(adaptive(
        darkColor: UIColor.white.withAlphaComponent(0.12),
        lightColor: UIColor.black.withAlphaComponent(0.12)
    ))
    static let tabBarBorder = Color(adaptive(
        darkColor: UIColor.white.withAlphaComponent(0.06),
        lightColor: UIColor.black.withAlphaComponent(0.10)
    ))

    // MARK: - Interactive States

    static let buttonPrimaryBg = gold
    static let buttonPrimaryText = Color(adaptive(dark: 0x0B1E28, light: 0xFFFFFF))
    static let buttonSecondaryBg = surfaceElevated
    static let buttonSecondaryText = textPrimary
    static let buttonDisabledBg = Color(adaptive(dark: 0x1B3040, light: 0xD5D1CA))
    static let buttonDisabledText = textTertiary

    // MARK: - Adaptive Color Helpers

    private static func adaptive(dark: UInt, light: UInt) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        }
    }

    private static func adaptive(darkColor: UIColor, lightColor: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
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
