import SwiftUI

struct WeekStrip: View {
    let days: [DayState]
    let currentDay: Int
    var onDayTap: ((Int) -> Void)?

    struct DayState: Identifiable {
        var id: Int { day }
        let day: Int
        let completed: Bool
        let hasQuiz: Bool
        let contentCount: Int

        init(day: Int, completed: Bool = false, hasQuiz: Bool = false, contentCount: Int = 0) {
            self.day = day
            self.completed = completed
            self.hasQuiz = hasQuiz
            self.contentCount = contentCount
        }
    }

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                Button {
                    Haptics.selection()
                    onDayTap?(day.day)
                } label: {
                    VStack(spacing: 4) {
                        Text(dayLabel(for: day.day))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)

                        ZStack {
                            Circle()
                                .fill(dayFill(day))
                                .frame(width: 36, height: 36)

                            if day.day == currentDay {
                                Circle()
                                    .stroke(ColorTokens.gold, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }

                            if day.completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if day.hasQuiz {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 12))
                                    .foregroundStyle(day.day == currentDay ? ColorTokens.gold : ColorTokens.textSecondary)
                            } else {
                                Text("\(day.contentCount)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(day.day == currentDay ? .white : ColorTokens.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private func dayLabel(for day: Int) -> String {
        guard day >= 1, day <= 7 else { return "" }
        return dayLabels[day - 1]
    }

    private func dayFill(_ day: DayState) -> Color {
        if day.completed { return ColorTokens.success }
        if day.day == currentDay { return ColorTokens.gold.opacity(0.2) }
        return ColorTokens.surfaceElevated
    }
}
