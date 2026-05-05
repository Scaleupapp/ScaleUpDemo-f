import SwiftUI

struct CalibrationBannerView: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("Get your real proficiency in 9 minutes")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Your plan will adapt to it.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                Button(action: { Haptics.success(); onTap() }) {
                    Text("Start calibration")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 8)
                        .background(ColorTokens.gold)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Spacing.md)
        .background(ColorTokens.surfaceElevated)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }
}
