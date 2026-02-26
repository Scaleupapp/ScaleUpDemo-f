import SwiftUI

// MARK: - Today Plan View

struct TodayPlanView: View {
    let todayPlan: TodayPlan

    @State private var markedComplete: Bool = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if todayPlan.plan.isRestDay {
                restDayContent
            } else {
                activeContent
            }
        }
        .navigationTitle("Today's Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Active Day Content

    private var activeContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Header Card
                headerCard

                // Topics Section
                topicsSection

                // Content Items Section
                contentItemsSection

                // Week Goals
                weekGoalsSection

                // Footer with total time
                totalTimeFooter

                // Mark Complete Button
                markCompleteButton

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Week \(todayPlan.weekNumber)")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Day \(todayPlan.day)")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.primary)
            }

            Spacer()

            // Estimated time badge
            VStack(spacing: Spacing.xs) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.primary)

                Text("\(todayPlan.plan.estimatedMinutes) min")
                    .font(Typography.mono)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
            }
            .padding(Spacing.md)
            .background(ColorTokens.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .cardStyle()
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Topics Section

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Topics")

            VStack(spacing: Spacing.sm) {
                ForEach(Array((todayPlan.plan.topics ?? []).enumerated()), id: \.offset) { index, topic in
                    topicRow(index: index + 1, topic: topic)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Topic Row

    @ViewBuilder
    private func topicRow(index: Int, topic: String) -> some View {
        let topics = todayPlan.plan.topics ?? []
        let estimatedPerTopic = topics.isEmpty
            ? 0
            : todayPlan.plan.estimatedMinutes / topics.count

        HStack(spacing: Spacing.md) {
            // Number circle
            ZStack {
                Circle()
                    .fill(ColorTokens.primary.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(topic)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("~\(estimatedPerTopic) min")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .cardStyle()
    }

    // MARK: - Content Items Section

    private var contentItemsSection: some View {
        Group {
            if !(todayPlan.plan.contentIds ?? []).isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader(title: "Content")

                    VStack(spacing: Spacing.sm) {
                        ForEach(todayPlan.plan.contentIds ?? [], id: \.self) { contentId in
                            contentIdCard(contentId)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    // MARK: - Content ID Card

    @ViewBuilder
    private func contentIdCard(_ contentId: String) -> some View {
        HStack(spacing: Spacing.md) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(ColorTokens.surfaceElevatedDark)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Content Item")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text(contentId)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.right.circle")
                .foregroundStyle(ColorTokens.primary)
        }
        .cardStyle()
    }

    // MARK: - Week Goals Section

    @ViewBuilder
    private var weekGoalsSection: some View {
        if let goals = todayPlan.weekGoals, !goals.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "This Week's Goals")

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(goals, id: \.self) { goal in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "target")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.warning)
                                .frame(width: 20)
                            Text(goal)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textPrimaryDark)
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Total Time Footer

    private var totalTimeFooter: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(ColorTokens.textSecondaryDark)
            Text("Total estimated time:")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
            Spacer()
            Text("\(todayPlan.plan.estimatedMinutes) minutes")
                .font(Typography.mono)
                .foregroundStyle(ColorTokens.primary)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Mark Complete Button

    private var markCompleteButton: some View {
        PrimaryButton(
            title: markedComplete ? "Completed!" : "Mark Day Complete",
            isDisabled: markedComplete
        ) {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                markedComplete = true
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Rest Day Content

    private var restDayContent: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.success)

            Text("Rest Day")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Week \(todayPlan.weekNumber), Day \(todayPlan.day)")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            VStack(spacing: Spacing.md) {
                Text("Take a well-deserved break today.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Rest is an essential part of the learning process. Your brain consolidates knowledge while you relax.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            // Week goals on rest days too
            if let goals = todayPlan.weekGoals, !goals.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("This Week's Goals")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    ForEach(goals, id: \.self) { goal in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "target")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.warning)
                            Text(goal)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Spacing.md)
            }

            Spacer()
        }
    }
}
