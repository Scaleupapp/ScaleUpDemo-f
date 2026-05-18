import SwiftUI

// MARK: - LEGACY V1 — slated for removal
/// **DEPRECATED — Legacy V1 surface.** Plan tab component, unreachable from v2.
/// Scheduled for removal after 2026-06-15. See LEGACY_V1.md.
@available(*, deprecated, message: "Legacy V1 — see LEGACY_V1.md")
struct ThisWeekTasksList: View {
    let weekNumber: Int
    let weekLabel: String
    let tasks: [APIPlanTask]
    let onTaskTap: (APIPlanTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK · WEEK \(weekNumber)")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
                Spacer()
                if !tasks.isEmpty {
                    let done = tasks.filter { $0.progress.status == .complete }.count
                    Text("\(done) / \(tasks.count) done")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            Text(weekLabel)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            if tasks.isEmpty {
                Text("No tasks for this week. Open a topic from your plan and start anywhere.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.vertical, Spacing.md)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(orderedTasks, id: \.taskId) { task in
                        TaskRow(task: task, onTap: { onTaskTap(task) })
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var orderedTasks: [APIPlanTask] {
        let priority: (APIPlanTaskProgress.Status) -> Int = {
            switch $0 {
            case .pending: return 0
            case .inProgress: return 1
            case .complete: return 2
            case .skipped: return 3
            }
        }
        return tasks.sorted { priority($0.progress.status) < priority($1.progress.status) }
    }
}
