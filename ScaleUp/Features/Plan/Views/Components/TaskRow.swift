import SwiftUI

// MARK: - LEGACY V1 — slated for removal
/// **DEPRECATED — Legacy V1 surface.** Plan tab component, unreachable from v2.
/// Scheduled for removal after 2026-06-15. See LEGACY_V1.md.
@available(*, deprecated, message: "Legacy V1 — see LEGACY_V1.md")
struct TaskRow: View {
    let task: APIPlanTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(typeLabel + " · " + task.topic.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()

                statusChip
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.surface)
            )
            .opacity(isComplete ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var isComplete: Bool { task.progress.status == .complete }
    private var isInProgress: Bool { task.progress.status == .inProgress }

    private var rowTitle: String {
        switch task.type {
        case .quiz: return "Quiz: \(task.topic.displayName)"
        case .inAppContent: return "Read: \(task.topic.displayName)"
        case .aiInterview: return "Mock interview: \(task.topic.displayName)"
        case .externalLink:
            if let title = task.payload?["title"]?.value as? String { return title }
            return task.topic.displayName
        case .competition: return "Compete: \(task.topic.displayName)"
        case .manual:
            if let title = task.payload?["title"]?.value as? String { return title }
            return task.topic.displayName
        }
    }

    private var typeLabel: String {
        switch task.type {
        case .quiz: return "Quiz"
        case .inAppContent: return "Content"
        case .aiInterview: return "Interview"
        case .externalLink: return "External"
        case .competition: return "Competition"
        case .manual: return "Off-platform"
        }
    }

    private var iconName: String {
        switch task.type {
        case .quiz: return "checkmark.circle"
        case .inAppContent: return "book"
        case .aiInterview: return "mic"
        case .externalLink: return "arrow.up.right.square"
        case .competition: return "trophy"
        case .manual: return "hand.raised"
        }
    }

    private var iconBackground: Color {
        isComplete ? ColorTokens.gold.opacity(0.05) : ColorTokens.gold.opacity(0.15)
    }

    private var iconForeground: Color {
        isComplete ? ColorTokens.textTertiary : ColorTokens.gold
    }

    @ViewBuilder
    private var statusChip: some View {
        if isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(ColorTokens.gold)
        } else if isInProgress {
            Text("In progress")
                .font(Typography.micro)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(ColorTokens.gold.opacity(0.10)))
                .foregroundStyle(ColorTokens.gold)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}
