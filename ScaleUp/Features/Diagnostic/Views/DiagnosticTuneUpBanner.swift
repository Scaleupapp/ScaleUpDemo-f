import SwiftUI

struct DiagnosticTuneUpBanner: View {
    let onTap: () -> Void
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .foregroundStyle(ColorTokens.gold)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Personalise your plan")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Take 5 min — we'll tune what we teach you.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.gold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .onTapGesture { onTap() }
    }
}
