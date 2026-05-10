import SwiftUI

struct JourneyTimelineStrip: View {
    let weeks: [APIPlanWeeklyEntry]
    let currentWeekNumber: Int?
    let onWeekTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR JOURNEY")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(weeks, id: \.weekNumber) { week in
                        weekCard(week)
                            .onTapGesture { onWeekTap(week.weekNumber) }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func weekCard(_ week: APIPlanWeeklyEntry) -> some View {
        let tasks = week.tasks ?? []
        let done = tasks.filter { $0.progress.status == .complete }.count
        let total = tasks.count
        let isCurrent = (week.weekNumber == currentWeekNumber)
        let isComplete = total > 0 && done == total

        VStack(alignment: .leading, spacing: 6) {
            Text("WEEK \(week.weekNumber)")
                .font(Typography.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(week.weekLabel)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                progressRing(done: done, total: total)
                Text(total > 0 ? "\(done)/\(total)" : "—")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(width: 168, height: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isCurrent ? ColorTokens.gold : ColorTokens.gold.opacity(0.10),
                            lineWidth: isCurrent ? 1.5 : 1
                        )
                )
        )
        .opacity(isComplete && !isCurrent ? 0.6 : 1.0)
    }

    private func progressRing(done: Int, total: Int) -> some View {
        let progress: Double = total > 0 ? Double(done) / Double(total) : 0
        return ZStack {
            Circle()
                .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
        .frame(width: 18, height: 18)
    }
}
