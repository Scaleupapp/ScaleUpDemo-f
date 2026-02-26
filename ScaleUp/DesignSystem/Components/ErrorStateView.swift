import SwiftUI

struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.error)

            Text(message)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)

            if let retryAction {
                SecondaryButton(title: "Try Again", action: retryAction)
                    .frame(width: 160)
            }
        }
        .padding(Spacing.xl)
    }
}
