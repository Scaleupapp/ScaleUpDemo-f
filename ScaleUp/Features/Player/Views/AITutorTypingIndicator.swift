import SwiftUI

// MARK: - AI Tutor Typing Indicator

struct AITutorTypingIndicator: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
            }

            // Bouncing dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ColorTokens.textTertiary)
                        .frame(width: 8, height: 8)
                        .offset(y: reduceMotion ? 0 : (animating ? -4 : 0))
                        .animation(
                            reduceMotion ? nil :
                                .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

            Spacer(minLength: 60)
        }
        .accessibilityLabel("AI Tutor is typing")
        .onAppear {
            animating = true
        }
    }
}
