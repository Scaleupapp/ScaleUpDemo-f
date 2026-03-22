import SwiftUI
import Charts

// MARK: - Navigation Destinations

struct ConsumptionHistoryDestination: Hashable {}
struct GapsDestination: Hashable {}

struct ProgressTabView: View {
    @State private var viewModel = ProgressViewModel()
    @State private var showDetailedAnalytics = false
    @Environment(ObjectiveContext.self) private var objectiveContext

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.knowledgeProfile == nil {
                    loadingState
                } else if !viewModel.isLoading && viewModel.knowledgeProfile == nil && viewModel.quizHistory.isEmpty && viewModel.consumptionStats == nil {
                    progressEmptyState
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TopicDetailDestination.self) { dest in
                TopicDetailView(topic: dest.topic)
            }
            .navigationDestination(for: Content.self) { content in
                PlayerView(contentId: content.id)
            }
            .navigationDestination(for: QuizListDestination.self) { _ in
                QuizListView()
            }
            .navigationDestination(for: GapsDestination.self) { _ in
                GapsView()
            }
            .navigationDestination(for: ConsumptionHistoryDestination.self) { _ in
                ConsumptionHistoryView()
            }
            .task {
                await viewModel.loadProfile(objectiveId: viewModel.showAllObjectives ? nil : objectiveContext.activeObjectiveId)
            }
            .onChange(of: objectiveContext.activeObjective?.id) { _, _ in
                Task {
                    await viewModel.loadProfile(objectiveId: viewModel.showAllObjectives ? nil : objectiveContext.activeObjectiveId)
                }
            }
        }
        .coachMark(
            .tabProgress,
            icon: "chart.bar.fill",
            title: "Knowledge Profile",
            message: "Your knowledge profile builds as you take quizzes. See topic mastery, strengths, and growth."
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // 1. Knowledge Score Hero (with explanatory labels)
                scoreHeroSection

                // 2. Streaks & Activity
                if viewModel.currentStreak > 0 || !viewModel.activityHeatmap.isEmpty {
                    streaksActivitySection
                }

                // 3. Focus This Week (gaps-based actionable card)
                if !viewModel.gaps.isEmpty {
                    focusThisWeekCard
                }

                // 4. Weekly Growth
                if let growth = viewModel.weeklyGrowth {
                    weeklyGrowthBanner(growth)
                }

                // 5. Topic Mastery
                if !viewModel.topicMastery.isEmpty {
                    topicMasterySection
                }

                // 6. Strengths & Gaps (with Practice Now)
                strengthsGapsSection

                // 7. Quiz Performance
                quizHistorySection

                // 8. Recent Activity Timeline
                if !viewModel.timelineEvents.isEmpty {
                    timelineSection
                }

                // 9. Detailed Analytics (collapsed)
                detailedAnalyticsSection

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .refreshable {
            await viewModel.loadProfile(objectiveId: viewModel.showAllObjectives ? nil : objectiveContext.activeObjectiveId)
        }
    }

    // MARK: - Score Hero

    private var scoreHeroSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Progress")
                    .font(Typography.titleLarge)
                    .foregroundStyle(.white)

                Spacer()

                if objectiveContext.canSwitch {
                    Button {
                        viewModel.showAllObjectives.toggle()
                        Task { await viewModel.loadProfile(objectiveId: viewModel.showAllObjectives ? nil : objectiveContext.activeObjectiveId) }
                    } label: {
                        Text(viewModel.showAllObjectives ? "All" : "Filtered")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewModel.showAllObjectives ? ColorTokens.gold : ColorTokens.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.showAllObjectives ? ColorTokens.gold.opacity(0.15) : ColorTokens.card)
                            .clipShape(Capsule())
                    }
                }

                ObjectiveSwitcherView()
            }

            HStack(spacing: Spacing.xl) {
                ProgressRing(
                    score: viewModel.overallScore,
                    label: "Knowledge",
                    size: 110,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: Spacing.md) {
                    statRow(icon: "brain.head.profile", label: "Quizzes Taken", value: "\(viewModel.totalQuizzes)")
                    statRow(icon: "book.closed.fill", label: "Topics Covered", value: "\(viewModel.totalTopics)")

                    if viewModel.readinessScore > 0 {
                        statRow(icon: "gauge.open.with.lines.needle.33percent", label: "Readiness", value: "\(viewModel.readinessScore)%")
                    }
                }
            }

            // Explanatory labels
            VStack(spacing: 4) {
                scoreExplanation(
                    icon: "brain.head.profile",
                    text: "Knowledge Score is based on your quiz performance across all topics"
                )
                if viewModel.readinessScore > 0 {
                    scoreExplanation(
                        icon: "gauge.open.with.lines.needle.33percent",
                        text: "Readiness = 40% knowledge + 30% journey progress + 30% consistency"
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.surface)
        )
    }

    private func scoreExplanation(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Focus This Week

    private var focusThisWeekCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Focus This Week")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            ForEach(viewModel.gaps.prefix(2)) { gap in
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(gap.topic.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Score: \(gap.scoreValue)% · \(gap.level?.capitalized ?? "Beginner")")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()

                    // Practice Now CTA
                    if let content = viewModel.gapContent.first(where: { $0.topics?.contains(gap.topic) ?? false }) {
                        NavigationLink(value: content) {
                            Text("Practice")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: QuizListDestination()) {
                            Text("Quiz")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ColorTokens.gold.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Weekly Growth

    private func weeklyGrowthBanner(_ growth: WeeklyGrowth) -> some View {
        NavigationLink(value: ConsumptionHistoryDestination()) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)

                    HStack(spacing: 4) {
                        Text("\(growth.contentThisWeek ?? 0) lessons")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        if let delta = growth.contentDelta, delta > 0 {
                            Text("+\(delta) from last week")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.success)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTokens.success.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTokens.success.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Topic Mastery

    private var topicMasterySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Your Topics")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("Based on quizzes")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.topicMastery.prefix(6)) { topic in
                    NavigationLink(value: TopicDetailDestination(topic: topic.topic)) {
                        HStack {
                            ScoreBar(
                                topic: topic.topic,
                                score: topic.scoreValue,
                                level: topic.level,
                                trend: topic.trend
                            )
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Strengths & Gaps

    private var strengthsGapsSection: some View {
        VStack(spacing: Spacing.md) {
            // Strengths
            if !viewModel.strengths.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.success)
                        Text("Strengths")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.strengths, id: \.self) { strength in
                            NavigationLink(value: TopicDetailDestination(topic: strength)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ColorTokens.success)
                                    Text(strength)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ColorTokens.success.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Gaps with Practice Now
            if !viewModel.gaps.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            Text("Areas to Improve")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        NavigationLink(value: GapsDestination()) {
                            Text("See All")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }

                    ForEach(viewModel.gaps.prefix(3)) { gap in
                        gapCard(gap)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private func gapCard(_ gap: KnowledgeGap) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(gap.topic.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(gap.scoreValue)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if let suggestion = gap.suggestion {
                Text(suggestion)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(2)
            }

            // Practice Now CTA — prominent button
            if let content = viewModel.gapContent.first(where: { $0.topics?.contains(gap.topic) ?? false }) {
                NavigationLink(value: content) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                        Text("Practice Now")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: QuizListDestination()) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Take a Quiz")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTokens.gold.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Quiz History

    private var quizHistorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Quiz Performance")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                NavigationLink(value: QuizListDestination()) {
                    Text("Take a Quiz")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }

            if viewModel.quizHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("No quizzes taken yet")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("Quiz scores build your Knowledge Score")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                        NavigationLink(value: QuizListDestination()) {
                            Text("Take Your First Quiz")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ColorTokens.gold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(ColorTokens.gold.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                    Spacer()
                }
            } else {
                if viewModel.quizHistory.count >= 2 {
                    scoreTrendChart
                }

                VStack(spacing: 6) {
                    ForEach(viewModel.quizHistory.prefix(5)) { attempt in
                        quizHistoryRow(attempt)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private func quizHistoryRow(_ attempt: QuizAttempt) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(quizScoreColor(attempt.score?.percentage).opacity(0.15))
                    .frame(width: 40, height: 40)

                Text("\(Int(attempt.score?.percentage ?? 0))%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(quizScoreColor(attempt.score?.percentage))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.quizId?.topic?.capitalized ?? attempt.quizId?.title ?? "Quiz")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(attempt.score?.correct ?? 0)/\(attempt.score?.total ?? 0) correct")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)

                    if let date = attempt.completedAt {
                        Text(date, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surfaceElevated)
        )
    }

    private func quizScoreColor(_ percentage: Double?) -> Color {
        let pct = percentage ?? 0
        if pct >= 70 { return ColorTokens.success }
        if pct >= 40 { return .orange }
        return .red
    }

    // MARK: - Streaks & Activity

    private var streaksActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.streakActive)
                Text("Streaks & Activity")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(viewModel.currentStreak > 0 ? ColorTokens.streakActive : ColorTokens.streakInactive)
                        Text("\(viewModel.currentStreak)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Current Streak")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.gold)
                        Text("\(viewModel.longestStreak)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Longest Streak")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.sm)

            Text("Completing content or quizzes builds your streak")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            if !viewModel.activityHeatmap.isEmpty {
                activityHeatmapGrid
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private var activityHeatmapGrid: some View {
        let calendar = Calendar.current
        let today = Date()
        let daysToShow = 91

        let countMap: [String: Int] = Dictionary(
            uniqueKeysWithValues: viewModel.activityHeatmap.map { ($0.date, $0.count) }
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startDate = calendar.date(byAdding: .day, value: -(daysToShow - 1), to: today)!

        return VStack(alignment: .leading, spacing: 4) {
            Text("Last 90 Days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            HStack(spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .frame(width: 10, height: 10)
                    }
                }

                LazyHGrid(rows: Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7), spacing: 3) {
                    ForEach(0..<daysToShow, id: \.self) { dayOffset in
                        let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                        let key = formatter.string(from: date)
                        let count = countMap[key] ?? 0

                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(count: count))
                            .frame(width: 10, height: 10)
                    }
                }
            }

            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.system(size: 8))
                    .foregroundStyle(ColorTokens.textTertiary)
                ForEach([0, 1, 2, 3], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(count: level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.system(size: 8))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private func heatmapColor(count: Int) -> Color {
        switch count {
        case 0: return ColorTokens.surfaceElevated
        case 1: return ColorTokens.gold.opacity(0.3)
        case 2: return ColorTokens.gold.opacity(0.6)
        default: return ColorTokens.gold
        }
    }

    // MARK: - Score Trend Chart

    private var scoreTrendChart: some View {
        let attempts = viewModel.quizHistory
            .filter { $0.completedAt != nil && $0.score != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            .suffix(15)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Score Trend")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            Chart {
                ForEach(Array(attempts), id: \.id) { attempt in
                    LineMark(
                        x: .value("Date", attempt.completedAt ?? Date()),
                        y: .value("Score", attempt.score?.percentage ?? 0)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", attempt.completedAt ?? Date()),
                        y: .value("Score", attempt.score?.percentage ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTokens.gold.opacity(0.3), ColorTokens.gold.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", attempt.completedAt ?? Date()),
                        y: .value("Score", attempt.score?.percentage ?? 0)
                    )
                    .foregroundStyle(ColorTokens.gold)
                    .symbolSize(20)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(ColorTokens.surfaceElevated)
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .font(.system(size: 8))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 8))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Learning Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Recent Activity")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 0) {
                let events = Array(viewModel.timelineEvents.prefix(10))
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(event.iconColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: event.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(event.iconColor)
                            }

                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(ColorTokens.surfaceElevated)
                                    .frame(width: 2)
                                    .frame(minHeight: 24)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if let subtitle = event.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .lineLimit(1)
                            }

                            if let date = event.date {
                                Text(date, style: .relative)
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        .padding(.bottom, Spacing.sm)

                        Spacer()
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - Detailed Analytics (Collapsed)

    @ViewBuilder
    private var detailedAnalyticsSection: some View {
        let hasVelocity = viewModel.velocity != nil
        let hasStats = viewModel.consumptionStats != nil
        let hasBehavioral = viewModel.behavioral != nil

        if hasVelocity || hasStats || hasBehavioral {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showDetailedAnalytics.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.dots.scatter")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Detailed Analytics")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: showDetailedAnalytics ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(Spacing.md)
                }
                .buttonStyle(.plain)

                if showDetailedAnalytics {
                    VStack(spacing: Spacing.md) {
                        if let velocity = viewModel.velocity {
                            velocityContent(velocity)
                        }

                        if let stats = viewModel.consumptionStats {
                            consumptionContent(stats)
                        }

                        if let behavioral = viewModel.behavioral {
                            behavioralContent(behavioral)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surface)
            )
        }
    }

    // MARK: - Velocity (inside Detailed Analytics)

    private func velocityContent(_ velocity: LearningVelocity) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.gold)
                Text("Learning Velocity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                velocityMetric(
                    value: String(format: "%.1f", velocity.topicsPerWeek ?? 0),
                    label: "Topics/Week",
                    icon: "book.fill"
                )
                velocityMetric(
                    value: String(format: "+%.1f%%", velocity.averageScoreImprovement ?? 0),
                    label: "Avg Improvement",
                    icon: "arrow.up.right"
                )
                velocityMetric(
                    value: String(format: "%.1f", velocity.contentToMasteryRatio ?? 0),
                    label: "Content/Mastery",
                    icon: "chart.xyaxis.line"
                )
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surfaceElevated)
        )
    }

    private func velocityMetric(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)

            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Consumption Stats (inside Detailed Analytics)

    private func consumptionContent(_ stats: ConsumptionStats) -> some View {
        NavigationLink(value: ConsumptionHistoryDestination()) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.gold)
                    Text("Learning Stats")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("View History")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.gold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }

                HStack(spacing: 0) {
                    consumptionMetric(
                        value: "\(stats.totalContentConsumed ?? 0)",
                        label: "Content",
                        icon: "play.rectangle.fill"
                    )
                    consumptionMetric(
                        value: stats.formattedTimeSpent,
                        label: "Time Spent",
                        icon: "clock.fill"
                    )
                    consumptionMetric(
                        value: "\(stats.topicCount ?? 0)",
                        label: "Topics",
                        icon: "folder.fill"
                    )
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ColorTokens.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
    }

    private func consumptionMetric(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Behavioral Insights (inside Detailed Analytics)

    private func behavioralContent(_ behavioral: BehavioralProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.gold)
                Text("Learning Style")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(behavioral.typeDisplay)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)

                    if let avgTime = behavioral.averageAnswerTime {
                        insightRow(label: "Avg Answer Time", value: String(format: "%.0fs", avgTime))
                    }

                    if let consistency = behavioral.consistencyScore {
                        insightRow(label: "Consistency", value: "\(Int(consistency * 100))%")
                    }

                    if let hours = behavioral.peakHours, !hours.isEmpty {
                        insightRow(label: "Peak Hours", value: hours.prefix(2).map { "\($0):00" }.joined(separator: ", "))
                    }
                }

                Spacer()
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surfaceElevated)
        )
    }

    private func insightRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Empty State

    private var progressEmptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text("No progress data yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("Watch content and take quizzes to see\nyour knowledge profile and progress here.")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("Knowledge scores are built from quiz results.\nContent you watch builds your streak.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }

            NavigationLink(value: QuizListDestination()) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                    Text("Take a Quiz")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.gold)
            Text("Loading your progress...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}

// FlowLayout is defined in InterestsStepView.swift and shared across the app
