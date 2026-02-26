import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, action: action)
                    .frame(width: 200)
            }
        }
        .padding(Spacing.xl)
    }
}
