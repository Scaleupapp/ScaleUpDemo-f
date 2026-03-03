import SwiftUI

enum Typography {
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .semibold, design: .default)
    static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 18, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmallBold = Font.system(size: 14, weight: .semibold, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)
    static let micro = Font.system(size: 10, weight: .medium, design: .default)
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monoLarge = Font.system(size: 20, weight: .semibold, design: .monospaced)
}
