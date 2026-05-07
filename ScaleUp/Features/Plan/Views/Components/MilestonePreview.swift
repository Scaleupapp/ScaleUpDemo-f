import SwiftUI

struct MilestonePreview: View {
    let milestones: [PlanMilestone]

    @State private var revealedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                milestoneRow(milestone: milestone, index: index, isLast: index == milestones.count - 1)
                    .opacity(revealedCount > index ? 1 : 0)
                    .offset(y: revealedCount > index ? 0 : 12)
            }
        }
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled {
                revealedCount = milestones.count
            } else {
                revealProgressively()
            }
        }
    }

    private func revealProgressively() {
        for index in milestones.indices {
            let delay = Double(index) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    revealedCount = index + 1
                }
            }
        }
    }

    private func milestoneRow(milestone: PlanMilestone, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Timeline column
            VStack(spacing: 0) {
                Circle()
                    .fill(ColorTokens.gold)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(ColorTokens.gold.opacity(0.3))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 10)

            // Content column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    Text("Week \(milestone.weekTarget)")
                        .font(Typography.captionBold)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if milestone.isUserStated {
                        Text("YOUR GOAL")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(ColorTokens.buttonPrimaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.gold)
                            .clipShape(Capsule())
                    }
                }

                Text(milestone.title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(milestone.measurableCriteria)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Spacing.lg)
        }
    }
}
