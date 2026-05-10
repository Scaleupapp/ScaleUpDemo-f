import SwiftUI

struct NextCheckInPill: View {
    let nextCheckInAt: Date?
    let isEligibleNow: Bool
    let onRecalibrateTap: () -> Void

    var body: some View {
        if isEligibleNow {
            Button(action: onRecalibrateTap) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Recalibrate now")
                        .font(Typography.bodyBold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .foregroundStyle(ColorTokens.gold)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ColorTokens.gold.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(label)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.surface.opacity(0.5))
            )
        }
    }

    private var label: String {
        guard let date = nextCheckInAt else { return "Next check-in pending" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days <= 0 { return "Check-in available" }
        if days == 1 { return "Next check-in tomorrow" }
        return "Next check-in in \(days) days"
    }
}
