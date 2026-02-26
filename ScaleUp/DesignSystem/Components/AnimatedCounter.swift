import SwiftUI

// MARK: - AnimatedCounter

struct AnimatedCounter: View {
    let value: Int
    var font: Font = Typography.monoLarge
    var color: Color = ColorTokens.textPrimaryDark

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.4, bounce: 0.2), value: value)
    }
}
