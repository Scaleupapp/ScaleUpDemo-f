import SwiftUI

// MARK: - Journey Stats View

/// Detailed statistics view for the active learning journey.
/// Shows progress breakdown by phase, content/quiz stats,
/// streak information, time stats, and a weekly activity heatmap.
struct JourneyStatsView: View {

    let journey: Journey

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Overall progress header
                    overallProgressSection

                    // Phase breakdown
                    phaseBreakdownSection

                    // Content stats
                    contentStatsSection

                    // Quiz stats
                    quizStatsSection

                    // Streak section
                    streakSection

                    // Time stats
                    timeStatsSection

                    // Weekly activity heatmap
                    weeklyActivitySection

                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("Journey Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Overall Progress Section

    private var overallProgressSection: some View {
        VStack(spacing: Spacing.md) {
            ProgressRing(
                progress: (journey.progress.overallPercentage ?? 0) / 100.0,
                size: 120,
                lineWidth: 12
            )

            VStack(spacing: Spacing.xs) {
                Text("Overall Progress")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Week \(journey.currentWeek) \u{2022} \(journey.currentPhase.rawValue.capitalized)")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surfaceDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.primary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Phase Breakdown Section

    private var phaseBreakdownSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Phase Progress")

            VStack(spacing: Spacing.sm) {
                ForEach(journey.phases, id: \.name) { phase in
                    phaseRow(phase: phase)
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func phaseRow(phase: JourneyPhaseDetail) -> some View {
        let phaseType = phase.type.flatMap { JourneyPhase(rawValue: $0) } ?? .foundation
        let isCurrentPhase = phaseType == journey.currentPhase
        let phaseProgress = calculatePhaseProgress(phase)

        VStack(spacing: Spacing.sm) {
            HStack {
                // Phase icon
                Image(systemName: phaseIcon(for: phaseType))
                    .font(.system(size: 14))
                    .foregroundStyle(phaseColor(for: phaseType))

                Text(phase.name.capitalized)
                    .font(Typography.bodySmall)
                    .foregroundStyle(
                        isCurrentPhase
                            ? ColorTokens.textPrimaryDark
                            : ColorTokens.textSecondaryDark
                    )

                if isCurrentPhase {
                    Text("Current")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(ColorTokens.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(Int(phaseProgress * 100))%")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.surfaceElevatedDark)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(phaseColor(for: phaseType))
                        .frame(width: geo.size.width * phaseProgress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Content Stats Section

    private var contentStatsSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Content Progress")

            VStack(spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.info)

                    Text("Lessons")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    Text("\(journey.progress.contentConsumed ?? 0) / \(journey.progress.contentAssigned ?? 0)")
                        .font(Typography.mono)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                progressBar(
                    value: journey.progress.contentConsumed ?? 0,
                    total: journey.progress.contentAssigned ?? 0,
                    color: ColorTokens.info
                )
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Quiz Stats Section

    private var quizStatsSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Quiz Progress")

            VStack(spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.primary)

                    Text("Quizzes")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    Text("\(journey.progress.quizzesCompleted ?? 0) / \(journey.progress.quizzesAssigned ?? 0)")
                        .font(Typography.mono)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                progressBar(
                    value: journey.progress.quizzesCompleted ?? 0,
                    total: journey.progress.quizzesAssigned ?? 0,
                    color: ColorTokens.primary
                )
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Streak")

            HStack(spacing: Spacing.md) {
                // Current streak
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorTokens.warning, ColorTokens.error],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )

                    Text("\(journey.progress.currentStreak ?? 0)")
                        .font(Typography.monoLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text("Current Streak")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(ColorTokens.cardDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                // Milestones completed
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.warning)

                    Text("\(journey.progress.milestonesCompleted ?? 0)")
                        .font(Typography.monoLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text("Milestones")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(ColorTokens.cardDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Time Stats Section

    private var timeStatsSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Time Investment")

            HStack(spacing: Spacing.md) {
                // Total learning time (estimated from content consumed)
                timeStatCard(
                    icon: "clock.fill",
                    value: estimatedTotalTime,
                    label: "Total Time",
                    color: ColorTokens.success
                )

                // Average daily time
                timeStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: estimatedDailyAverage,
                    label: "Daily Average",
                    color: ColorTokens.info
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func timeStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.monoLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Weekly Activity Section

    private var weeklyActivitySection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "Weekly Activity")

            VStack(spacing: Spacing.sm) {
                // Day labels
                HStack(spacing: Spacing.xs) {
                    ForEach(dayLabels, id: \.self) { day in
                        Text(day)
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Heatmap grid
                if let currentWeekPlan = currentWeeklyPlan {
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let assignment = currentWeekPlan.dailyAssignments.first {
                                $0.day == dayIndex + 1
                            }
                            activityCell(assignment: assignment, dayIndex: dayIndex)
                        }
                    }
                } else {
                    // Placeholder when no current week plan
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<7, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Spacing.xs)
                                .fill(ColorTokens.surfaceElevatedDark)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }

                // Legend
                HStack(spacing: Spacing.md) {
                    legendItem(color: ColorTokens.surfaceElevatedDark, label: "Rest")
                    legendItem(color: ColorTokens.primary.opacity(0.3), label: "Light")
                    legendItem(color: ColorTokens.primary.opacity(0.6), label: "Moderate")
                    legendItem(color: ColorTokens.primary, label: "Intense")
                }
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func activityCell(assignment: DailyAssignment?, dayIndex: Int) -> some View {
        let intensity = activityIntensity(for: assignment)
        let isToday = Calendar.current.component(.weekday, from: Date()) == adjustedWeekday(dayIndex)

        RoundedRectangle(cornerRadius: Spacing.xs)
            .fill(intensityColor(intensity))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: Spacing.xs)
                        .stroke(ColorTokens.textPrimaryDark, lineWidth: 1.5)
                    : nil
            )
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Shared Progress Bar

    @ViewBuilder
    private func progressBar(value: Int, total: Int, color: Color) -> some View {
        let progress = total > 0 ? min(Double(value) / Double(total), 1.0) : 0.0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorTokens.surfaceElevatedDark)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Computed Helpers

    private var dayLabels: [String] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    private var currentWeeklyPlan: WeeklyPlan? {
        journey.weeklyPlans.first { $0.weekNumber == journey.currentWeek }
    }

    private var estimatedTotalTime: String {
        // Estimate based on content consumed (average 15 min per content piece)
        let totalMinutes = (journey.progress.contentConsumed ?? 0) * 15
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var estimatedDailyAverage: String {
        // Estimate daily average based on current week and content consumed
        let totalDays = max(journey.currentWeek * 7, 1)
        let totalMinutes = (journey.progress.contentConsumed ?? 0) * 15
        let avgMinutes = totalMinutes / totalDays
        if avgMinutes >= 60 {
            return "\(avgMinutes / 60)h \(avgMinutes % 60)m"
        }
        return "\(avgMinutes)m"
    }

    private func calculatePhaseProgress(_ phase: JourneyPhaseDetail) -> Double {
        guard !phase.weekNumbers.isEmpty else { return 0 }
        let lastWeekInPhase = phase.weekNumbers.max() ?? 0
        let firstWeekInPhase = phase.weekNumbers.min() ?? 0
        let totalWeeks = lastWeekInPhase - firstWeekInPhase + 1

        if journey.currentWeek > lastWeekInPhase {
            return 1.0 // Completed phase
        } else if journey.currentWeek < firstWeekInPhase {
            return 0.0 // Future phase
        } else {
            let weeksCompleted = journey.currentWeek - firstWeekInPhase
            return Double(weeksCompleted) / Double(totalWeeks)
        }
    }

    private func phaseIcon(for phase: JourneyPhase) -> String {
        switch phase {
        case .foundation:
            return "building.columns"
        case .building:
            return "hammer.fill"
        case .strengthening:
            return "dumbbell.fill"
        case .mastery:
            return "crown.fill"
        case .revision:
            return "arrow.counterclockwise"
        case .examPrep:
            return "doc.text.fill"
        }
    }

    private func phaseColor(for phase: JourneyPhase) -> Color {
        switch phase {
        case .foundation:
            return ColorTokens.info
        case .building:
            return ColorTokens.primary
        case .strengthening:
            return ColorTokens.warning
        case .mastery:
            return ColorTokens.success
        case .revision:
            return ColorTokens.primaryLight
        case .examPrep:
            return ColorTokens.error
        }
    }

    private func activityIntensity(for assignment: DailyAssignment?) -> Int {
        guard let assignment, !assignment.isRestDay else { return 0 }
        switch assignment.estimatedMinutes {
        case 0:
            return 0
        case 1..<30:
            return 1
        case 30..<60:
            return 2
        default:
            return 3
        }
    }

    private func intensityColor(_ intensity: Int) -> Color {
        switch intensity {
        case 0:
            return ColorTokens.surfaceElevatedDark
        case 1:
            return ColorTokens.primary.opacity(0.3)
        case 2:
            return ColorTokens.primary.opacity(0.6)
        default:
            return ColorTokens.primary
        }
    }

    /// Converts a 0-based day index (Mon=0) to Calendar weekday (Sun=1, Mon=2, ...).
    private func adjustedWeekday(_ dayIndex: Int) -> Int {
        // dayIndex: 0=Mon, 1=Tue, ..., 6=Sun
        // Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat
        return dayIndex == 6 ? 1 : dayIndex + 2
    }
}
