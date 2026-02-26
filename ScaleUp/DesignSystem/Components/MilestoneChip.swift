import SwiftUI

struct MilestoneChip: View {
    let icon: String
    let title: String
    var isCompleted: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isCompleted ? ColorTokens.success : ColorTokens.primary)

            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .lineLimit(1)

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.success)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(
            isCompleted
                ? ColorTokens.success.opacity(0.1)
                : ColorTokens.surfaceElevatedDark
        )
        .clipShape(Capsule())
    }
}
