import SwiftUI

// MARK: - Weekly Plan View

struct WeeklyPlanView: View {
    let weekNumber: Int
    let totalWeeks: Int
    let journeyService: JourneyService

    @State private var viewModel: WeeklyPlanViewModel?
    @State private var currentWeekNumber: Int

    // MARK: - Init

    init(weekNumber: Int, totalWeeks: Int, journeyService: JourneyService) {
        self.weekNumber = weekNumber
        self.totalWeeks = totalWeeks
        self.journeyService = journeyService
        self._currentWeekNumber = State(initialValue: weekNumber)
    }

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.weeklyPlan == nil {
                    weekSkeletonView
                } else if let error = viewModel.error, viewModel.weeklyPlan == nil {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadWeek(number: currentWeekNumber) }
                        }
                    )
                } else if let plan = viewModel.weeklyPlan {
                    weekContent(plan: plan, viewModel: viewModel)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            weekNavigationToolbar
        }
        .onAppear {
            if viewModel == nil {
                viewModel = WeeklyPlanViewModel(journeyService: journeyService)
            }
        }
        .task(id: currentWeekNumber) {
            if let viewModel {
                await viewModel.loadWeek(number: currentWeekNumber)
            }
        }
    }

    // MARK: - Computed

    private var navigationTitle: String {
        if let plan = viewModel?.weeklyPlan {
            return "Week \(plan.weekNumber): \(plan.theme)"
        }
        return "Week \(currentWeekNumber)"
    }

    // MARK: - Week Navigation Toolbar

    @ToolbarContentBuilder
    private var weekNavigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Spacing.md) {
                Button {
                    navigateToPreviousWeek()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(
                            currentWeekNumber > 1
                                ? ColorTokens.textSecondaryDark
                                : ColorTokens.textTertiaryDark.opacity(0.3)
                        )
                }
                .disabled(currentWeekNumber <= 1)

                Text("\(currentWeekNumber)/\(totalWeeks)")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Button {
                    navigateToNextWeek()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(
                            currentWeekNumber < totalWeeks
                                ? ColorTokens.textSecondaryDark
                                : ColorTokens.textTertiaryDark.opacity(0.3)
                        )
                }
                .disabled(currentWeekNumber >= totalWeeks)
            }
        }
    }

    // MARK: - Week Content

    @ViewBuilder
    private func weekContent(plan: WeeklyPlan, viewModel: WeeklyPlanViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Week summary header
                weekSummary(plan: plan, viewModel: viewModel)

                // Daily assignments
                dailyAssignmentsList(plan: plan, viewModel: viewModel)

                // Total time footer
                weekTimeFooter(viewModel: viewModel)

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Week Summary

    @ViewBuilder
    private func weekSummary(plan: WeeklyPlan, viewModel: WeeklyPlanViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            // Theme
            Text(plan.theme)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .multilineTextAlignment(.center)

            // Stats row
            HStack(spacing: Spacing.xl) {
                weekStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(viewModel.completedDays)",
                    label: "Done",
                    color: ColorTokens.success
                )
                weekStatItem(
                    icon: "circle.dotted",
                    value: "\(viewModel.remainingDays)",
                    label: "Remaining",
                    color: ColorTokens.primary
                )
                weekStatItem(
                    icon: "clock.fill",
                    value: "\(viewModel.totalMinutes)",
                    label: "Minutes",
                    color: ColorTokens.warning
                )
                weekStatItem(
                    icon: "calendar",
                    value: "\(viewModel.activeDays)",
                    label: "Active Days",
                    color: ColorTokens.info
                )
            }
        }
        .cardStyle()
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Week Stat Item

    @ViewBuilder
    private func weekStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Daily Assignments List

    @ViewBuilder
    private func dailyAssignmentsList(plan: WeeklyPlan, viewModel: WeeklyPlanViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Daily Schedule")

            ForEach(plan.dailyAssignments, id: \.day) { assignment in
                let isToday = assignment.day == viewModel.currentDayInWeek && currentWeekNumber == weekNumber
                let isCompleted = assignment.day < viewModel.currentDayInWeek && currentWeekNumber == weekNumber

                dayCard(
                    assignment: assignment,
                    isToday: isToday,
                    isCompleted: isCompleted
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Day Card

    @ViewBuilder
    private func dayCard(assignment: DailyAssignment, isToday: Bool, isCompleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Day header
            HStack {
                HStack(spacing: Spacing.sm) {
                    // Status icon
                    Image(systemName: dayStatusIcon(
                        isRestDay: assignment.isRestDay,
                        isCompleted: isCompleted,
                        isToday: isToday
                    ))
                    .font(.system(size: 16))
                    .foregroundStyle(dayStatusColor(
                        isRestDay: assignment.isRestDay,
                        isCompleted: isCompleted,
                        isToday: isToday
                    ))

                    Text(dayName(assignment.day))
                        .font(isToday ? Typography.bodyBold : Typography.body)
                        .foregroundStyle(
                            isToday ? ColorTokens.textPrimaryDark :
                            (isCompleted ? ColorTokens.textSecondaryDark : ColorTokens.textPrimaryDark)
                        )

                    if isToday {
                        Text("Today")
                            .font(Typography.micro)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.primary)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                if !assignment.isRestDay {
                    Text("\(assignment.estimatedMinutes) min")
                        .font(Typography.mono)
                        .foregroundStyle(
                            isCompleted ? ColorTokens.textTertiaryDark : ColorTokens.primary
                        )
                }
            }

            if assignment.isRestDay {
                // Rest day indicator
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.success)
                    Text("Rest & Recharge")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            } else {
                // Topics
                ForEach(assignment.topics ?? [], id: \.self) { topic in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(isCompleted ? ColorTokens.success.opacity(0.5) : ColorTokens.primary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(topic)
                            .font(Typography.bodySmall)
                            .foregroundStyle(
                                isCompleted
                                    ? ColorTokens.textTertiaryDark
                                    : ColorTokens.textSecondaryDark
                            )
                            .strikethrough(isCompleted, color: ColorTokens.textTertiaryDark)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            isToday
                ? ColorTokens.primary.opacity(0.08)
                : (assignment.isRestDay ? ColorTokens.success.opacity(0.04) : ColorTokens.cardDark)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(
                    isToday ? ColorTokens.primary.opacity(0.3) : .clear,
                    lineWidth: 1
                )
        )
        .opacity(isCompleted ? 0.7 : 1.0)
    }

    // MARK: - Week Time Footer

    @ViewBuilder
    private func weekTimeFooter(viewModel: WeeklyPlanViewModel) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "timer")
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                Text("Total week time:")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            Spacer()

            let hours = viewModel.totalMinutes / 60
            let mins = viewModel.totalMinutes % 60

            Text(hours > 0 ? "\(hours)h \(mins)m" : "\(mins) min")
                .font(Typography.mono)
                .foregroundStyle(ColorTokens.primary)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Skeleton View

    private var weekSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Summary skeleton
                SkeletonLoader(height: 120, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Section header skeleton
                SkeletonLoader(width: 140, height: 20)
                    .padding(.horizontal, Spacing.md)

                // Day cards skeleton
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonLoader(height: 80, cornerRadius: CornerRadius.medium)
                        .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Navigation

    private func navigateToPreviousWeek() {
        guard currentWeekNumber > 1 else { return }
        currentWeekNumber -= 1
    }

    private func navigateToNextWeek() {
        guard currentWeekNumber < totalWeeks else { return }
        currentWeekNumber += 1
    }

    // MARK: - Helpers

    private func dayName(_ day: Int) -> String {
        switch day {
        case 1: return "Monday"
        case 2: return "Tuesday"
        case 3: return "Wednesday"
        case 4: return "Thursday"
        case 5: return "Friday"
        case 6: return "Saturday"
        case 7: return "Sunday"
        default: return "Day \(day)"
        }
    }

    private func dayStatusIcon(isRestDay: Bool, isCompleted: Bool, isToday: Bool) -> String {
        if isRestDay {
            return "leaf.circle.fill"
        } else if isCompleted {
            return "checkmark.circle.fill"
        } else if isToday {
            return "circle.inset.filled"
        } else {
            return "circle"
        }
    }

    private func dayStatusColor(isRestDay: Bool, isCompleted: Bool, isToday: Bool) -> Color {
        if isRestDay {
            return ColorTokens.success
        } else if isCompleted {
            return ColorTokens.success
        } else if isToday {
            return ColorTokens.primary
        } else {
            return ColorTokens.textTertiaryDark
        }
    }
}
