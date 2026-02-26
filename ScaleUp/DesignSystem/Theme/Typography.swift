import SwiftUI

enum Typography {
    /// 34pt Bold — Hero titles
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)

    /// 28pt Semibold — Section headers
    static let displayMedium = Font.system(size: 28, weight: .semibold, design: .default)

    /// 22pt Semibold — Screen titles
    static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)

    /// 18pt Semibold — Card titles
    static let titleMedium = Font.system(size: 18, weight: .semibold, design: .default)

    /// 16pt Regular — Primary text
    static let body = Font.system(size: 16, weight: .regular, design: .default)

    /// 16pt Semibold — Body emphasis
    static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)

    /// 14pt Regular — Secondary text
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    /// 12pt Regular — Metadata, timestamps
    static let caption = Font.system(size: 12, weight: .regular, design: .default)

    /// 10pt Medium — Tags, badges
    static let micro = Font.system(size: 10, weight: .medium, design: .default)

    /// 14pt Mono Regular — Scores, timers
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)

    /// 20pt Mono Bold — Large score displays
    static let monoLarge = Font.system(size: 20, weight: .bold, design: .monospaced)
}
