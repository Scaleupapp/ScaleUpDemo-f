import SwiftUI

// MARK: - Quiz Alert Banner

struct QuizAlertBanner: View {
    let count: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Spacing.sm) {
                // Pulsing icon
                ZStack {
                    Circle()
                        .fill(ColorTokens.primary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ColorTokens.primary)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) Quiz\(count == 1 ? "" : "zes") Ready")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text("Test your knowledge now")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()

                // CTA arrow
                HStack(spacing: 4) {
                    Text("Take Quiz")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.primary)
                .clipShape(Capsule())
            }
            .padding(Spacing.sm)
            .padding(.leading, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(ColorTokens.surfaceDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(ColorTokens.primary.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }
}
