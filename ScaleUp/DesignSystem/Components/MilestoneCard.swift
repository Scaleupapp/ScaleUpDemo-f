import SwiftUI

struct MilestoneCard: View {
    let milestone: Milestone
    var isNext: Bool = false

    private var isTappable: Bool {
        milestone.targetCriteria?.targetTopic != nil
    }

    private var statusIcon: String {
        switch milestone.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        case "overdue": return "exclamationmark.circle.fill"
        case "skipped": return "forward.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch milestone.status {
        case "completed": return ColorTokens.success
        case "in_progress": return ColorTokens.gold
        case "overdue": return .red
        case "skipped": return ColorTokens.textTertiary
        default: return ColorTokens.textTertiary
        }
    }

    private var typeIcon: String {
        switch milestone.type {
        case "topic_completion": return "book.closed.fill"
        case "score_target": return "target"
        case "streak": return "flame.fill"
        case "phase_completion": return "flag.fill"
        case "project": return "hammer.fill"
        case "final_assessment": return "graduationcap.fill"
        default: return "star.fill"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Status indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                if !isNext {
                    Rectangle()
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 2, height: 24)
                }
            }

            // Content
            HStack(spacing: Spacing.sm) {
                Image(systemName: typeIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor)
                    .frame(width: 32, height: 32)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let target = milestone.targetCriteria?.targetScore {
                        Text("Target: \(target)%")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    } else if let topic = milestone.targetCriteria?.targetTopic {
                        HStack(spacing: 3) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 8))
                            Text(topic.capitalized)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.gold)
                    }

                    if milestone.status == "completed" {
                        Text("Completed")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.success)
                    } else if let week = milestone.scheduledWeek {
                        Text("Unlocks in Week \(week)")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                Spacer()

                if isTappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(statusColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isNext ? ColorTokens.gold.opacity(0.08) : ColorTokens.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isNext ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
    }
}
