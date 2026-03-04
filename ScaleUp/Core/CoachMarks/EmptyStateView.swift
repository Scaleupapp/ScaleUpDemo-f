import SwiftUI

// MARK: - Reusable Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var actionIcon: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Icon with subtle glow
            ZStack {
                RadialGradient(
                    colors: [ColorTokens.gold.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 5,
                    endRadius: 60
                )
                .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let label = actionLabel, let onTap = action {
                Button {
                    Haptics.light()
                    onTap()
                } label: {
                    HStack(spacing: 6) {
                        if let icon = actionIcon {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                        }
                        Text(label)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, 40)
    }
}

// MARK: - Error State (network/API failures)

struct ErrorStateView: View {
    let message: String
    var retryLabel: String = "Try Again"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text("Something went wrong")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let retry = onRetry {
                Button {
                    Haptics.light()
                    retry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                        Text(retryLabel)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(ColorTokens.buttonPrimaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, 40)
    }
}
