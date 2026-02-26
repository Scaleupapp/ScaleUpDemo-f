import SwiftUI

struct CardStyleModifier: ViewModifier {
    var padding: CGFloat = Spacing.md

    func body(content: Self.Content) -> some View {
        content
            .padding(padding)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.md) -> some View {
        modifier(CardStyleModifier(padding: padding))
    }
}
