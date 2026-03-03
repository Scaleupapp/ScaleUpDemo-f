import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            Haptics.light()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.buttonPrimaryText)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(Typography.bodyBold)
                }
            }
            .foregroundStyle(isDisabled ? ColorTokens.buttonDisabledText : ColorTokens.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isDisabled
                    ? AnyShapeStyle(ColorTokens.buttonDisabledBg)
                    : AnyShapeStyle(ColorTokens.goldGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Social Auth Button

struct SocialAuthButton: View {
    let title: String
    let iconName: String
    var isSystemIcon: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                if isSystemIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                } else {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
