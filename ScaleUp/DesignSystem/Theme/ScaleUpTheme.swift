import SwiftUI

@Observable
final class ScaleUpTheme {
    var colorScheme: ColorScheme = .dark

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Resolved Colors

    var background: Color { isDark ? ColorTokens.backgroundDark : ColorTokens.backgroundLight }
    var surface: Color { isDark ? ColorTokens.surfaceDark : ColorTokens.surfaceLight }
    var surfaceElevated: Color { isDark ? ColorTokens.surfaceElevatedDark : ColorTokens.surfaceElevatedLight }
    var card: Color { isDark ? ColorTokens.cardDark : ColorTokens.cardLight }
    var textPrimary: Color { isDark ? ColorTokens.textPrimaryDark : ColorTokens.textPrimaryLight }
    var textSecondary: Color { isDark ? ColorTokens.textSecondaryDark : ColorTokens.textSecondaryLight }
    var textTertiary: Color { isDark ? ColorTokens.textTertiaryDark : ColorTokens.textTertiaryLight }
}
