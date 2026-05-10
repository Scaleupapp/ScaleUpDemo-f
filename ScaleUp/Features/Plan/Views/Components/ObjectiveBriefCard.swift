import SwiftUI

struct ObjectiveBriefCard: View {
    let plan: PlanDTO
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Eyebrow
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR OBJECTIVE")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Text(plan.planHeadline)
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.sm) {
                statChip(icon: "calendar", label: "\(plan.totalWeeks) weeks")
                statChip(icon: "clock", label: hoursLabel)
                statChip(icon: "flag", label: "\(plan.milestoneCount) milestones")
            }

            if isExpanded {
                Divider().padding(.vertical, Spacing.xs)
                Text(plan.bufferRecommendation ?? "We've reserved ~15% of your weekly time as buffer for life events.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }

    // Format hours without trailing ".0" if it's a whole number.
    private var hoursLabel: String {
        let hours = plan.totalHours
        if hours == floor(hours) {
            return "\(Int(hours)) hours"
        }
        return String(format: "%.1f hours", hours)
    }

    private func statChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(Typography.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorTokens.gold.opacity(0.10)))
        .foregroundStyle(ColorTokens.textPrimary)
    }
}
