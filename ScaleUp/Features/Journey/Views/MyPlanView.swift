import SwiftUI

// MARK: - Navigation Destinations

struct TopicDetailDestination: Hashable {
    let topic: String
}

struct MilestonesDestination: Hashable {
    // Just a trigger — viewModel passed directly
    static func == (lhs: MilestonesDestination, rhs: MilestonesDestination) -> Bool { true }
    func hash(into hasher: inout Hasher) { hasher.combine("milestones") }
}

struct WeekDetailDestination: Hashable {
    let weekNumber: Int
}

struct ObjectiveBriefDestination: Hashable {
    let objectiveId: String
}

struct MyPlanView: View {
    @State private var viewModel = MyPlanViewModel()
    @Environment(ObjectiveContext.self) private var objectiveContext

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.dashboard == nil && viewModel.userObjective == nil {
                    loadingState
                } else if !viewModel.hasActiveJourney {
                    noJourneyContent
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Content.self) { content in
                PlayerView(contentId: content.id)
            }
            .navigationDestination(for: TopicDetailDestination.self) { dest in
                TopicDetailView(topic: dest.topic)
            }
            .navigationDestination(for: MilestonesDestination.self) { _ in
                MilestonesView(viewModel: viewModel)
            }
            .navigationDestination(for: QuizListDestination.self) { _ in
                QuizListView()
            }
            .navigationDestination(for: Quiz.self) { quiz in
                QuizDetailView(quiz: quiz)
            }
            .navigationDestination(for: ObjectiveBriefDestination.self) { dest in
                ObjectiveBriefView(objectiveId: dest.objectiveId)
            }
            .task {
                viewModel.activeObjectiveId = objectiveContext.activeObjectiveId
                await viewModel.loadDashboard()
                objectiveContext.updateFromDashboard(viewModel.allObjectives)
            }
            .onChange(of: objectiveContext.activeObjective?.id) { oldId, newId in
                guard newId != oldId, newId != nil else { return }
                viewModel.activeObjectiveId = newId
                Task {
                    await viewModel.loadDashboard()
                }
            }
            .onChange(of: objectiveContext.needsJourneyGeneration) { _, needsGen in
                if needsGen, let id = objectiveContext.activeObjectiveId {
                    Task {
                        await viewModel.generateJourney(objectiveId: id)
                        objectiveContext.needsJourneyGeneration = false
                    }
                }
            }
        }
    }

    // MARK: - No Journey State

    private var noJourneyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                if viewModel.userObjective != nil {
                    headerSection
                }
                GenerateJourneyView(viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Main Content (5 sections)

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // 1. HEADER — Goal + progress + pace (all in one)
                headerSection

                // 2. TODAY — What should I do right now?
                todaySection

                // 3. THIS WEEK — How's my week going?
                thisWeekSection

                // 4. YOUR JOURNEY — Phase progress + next milestone
                journeySection

                // 5. SKILLS — Compact readiness with inline actions
                skillsSection

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - 1. Header (Goal + Progress + Pace — merged)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title row
            HStack {
                Text("My Plan")
                    .font(Typography.titleLarge)
                    .foregroundStyle(.white)

                Spacer()

                if viewModel.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.streakActive)
                        Text("\(viewModel.streak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorTokens.streakActive.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            if viewModel.overallProgress >= 1.0 {
                completionCelebration
            } else {
                // Goal card with integrated progress
                VStack(alignment: .leading, spacing: 10) {
                    // Goal title
                    Text(viewModel.goalTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    // Progress bar
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(ColorTokens.surfaceElevated)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(colors: [ColorTokens.gold.opacity(0.8), ColorTokens.gold], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * viewModel.overallProgress)
                            }
                        }
                        .frame(height: 8)

                        // Progress details — human-readable
                        HStack(spacing: 0) {
                            Text(viewModel.progressSummary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            // Pace as estimated date
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.paceIcon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(viewModel.paceColor)
                                Text(viewModel.paceLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(viewModel.paceColor)
                            }
                        }
                    }

                    // Meta row
                    HStack(spacing: Spacing.md) {
                        metaChip("Week \(viewModel.currentWeek)/\(viewModel.totalWeeks)", icon: "calendar")

                        if !viewModel.currentLevel.isEmpty {
                            metaChip(viewModel.currentLevel, icon: "gauge.with.dots.needle.33percent")
                        }

                        if !viewModel.timelineDisplay.isEmpty {
                            metaChip(viewModel.timelineDisplay, icon: "clock")
                        }
                    }
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorTokens.gold.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(ColorTokens.gold.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func metaChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11))
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private var completionCelebration: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.gold)

            Text("Journey Complete!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("You've completed your learning roadmap.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.xl) {
                statBadge("\(viewModel.dashboard?.progress?.contentConsumed ?? 0)", "Lessons")
                statBadge("\(viewModel.dashboard?.progress?.quizzesCompleted ?? 0)", "Quizzes")
                statBadge("\(viewModel.dashboard?.progress?.milestonesCompleted ?? 0)", "Milestones")
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.gold.opacity(0.15), ColorTokens.gold.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - 2. Today Section (content + rest day + next action — merged)

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header with today's date
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text(viewModel.todayDateString)
                    .font(Typography.titleMedium)
                    .foregroundStyle(.white)

                Spacer()

                if let stats = viewModel.todayStats, (stats.totalItems ?? 0) > 0 {
                    Text("\(stats.completedItems ?? 0)/\(stats.totalItems ?? 0) done")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }
            }

            if viewModel.todayContent.isEmpty {
                // No content today — show informative rest card
                noContentTodayCard
            } else {
                // Today's content items
                VStack(spacing: 8) {
                    ForEach(viewModel.incompleteContent) { content in
                        NavigationLink(value: content) {
                            todayContentRow(content)
                        }
                        .buttonStyle(.plain)
                    }

                    if !viewModel.completedContent.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.success)
                            Text("\(viewModel.completedContent.count) completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.success)
                            Spacer()
                        }
                        .padding(.top, 4)

                        ForEach(viewModel.completedContent) { content in
                            NavigationLink(value: content) {
                                todayContentRow(content)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.6)
                        }
                    }
                }
            }

            // Up Next action (always show if available, even on rest days)
            if let action = viewModel.primaryNextAction {
                nextActionCard(action)
            }
        }
    }

    private var noContentTodayCard: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.gold)

            Text("No lessons scheduled")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            // Show when next lesson is
            Text(viewModel.nextLessonMessage)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            // Suggest actions
            VStack(spacing: 8) {
                NavigationLink(value: QuizListDestination()) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Take a quiz to test your knowledge")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ColorTokens.surfaceElevated)
                    )
                }
                .buttonStyle(.plain)

                if viewModel.hasCompletedContent {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("Review completed lessons")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ColorTokens.surfaceElevated.opacity(0.5))
                    )
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private func todayContentRow(_ content: Content) -> some View {
        let isCompleted = content._progress?.isCompleted == true
        let isInProgress = content._progress?.isInProgress == true
        let progressPct = content._progress?.progressPercentage ?? 0

        return HStack(spacing: Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.surfaceElevated)
                        .frame(width: 60, height: 42)

                    if let url = content.thumbnailURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .frame(width: 60, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !isCompleted {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(4)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.success)
                        .background(Circle().fill(ColorTokens.surface).frame(width: 14, height: 14))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let duration = content.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    if isInProgress {
                        Text("\(progressPct)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    if let topic = content.topics?.first {
                        Text(topic)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.gold.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                if isInProgress && progressPct > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTokens.surfaceElevated)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTokens.gold)
                                .frame(width: geo.size.width * CGFloat(progressPct) / 100)
                        }
                    }
                    .frame(height: 3)
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.success)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTokens.surface)
        )
    }

    private func nextActionCard(_ action: NextActionItem) -> some View {
        Group {
            if action.type == "take_quiz" {
                NavigationLink(value: QuizListDestination()) {
                    nextActionContent(action)
                }
                .buttonStyle(.plain)
            } else if let contentId = action.contentId,
                      let content = action.content ?? viewModel.todayContent.first(where: { $0.id == contentId }) {
                NavigationLink(value: content) {
                    nextActionContent(action)
                }
                .buttonStyle(.plain)
            } else {
                nextActionContent(action)
            }
        }
    }

    private func nextActionContent(_ action: NextActionItem) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: action.icon)
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 40, height: 40)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("UP NEXT")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(ColorTokens.gold.opacity(0.7))

                Text(action.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(Circle())
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - 3. This Week (week strip + goals — merged)

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("This Week")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Quick stats for the week
                let consumed = viewModel.dashboard?.progress?.contentConsumed ?? 0
                let assigned = viewModel.dashboard?.progress?.contentAssigned ?? 0
                HStack(spacing: Spacing.sm) {
                    miniStat(value: "\(consumed)/\(assigned)", label: "Lessons")
                    miniStat(value: "\(viewModel.dashboard?.progress?.quizzesCompleted ?? 0)/\(viewModel.dashboard?.progress?.quizzesAssigned ?? 0)", label: "Quizzes")
                }
            }

            // Week theme
            if let theme = viewModel.dashboard?.currentWeek?.theme {
                Text(theme)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // Week strip
            WeekStrip(
                days: viewModel.weekDays,
                currentDay: viewModel.currentDayOfWeek
            ) { _ in }

            // Goals (inline, not separate section)
            if !viewModel.weekGoals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.gold)
                        Text("Goals")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                    }

                    ForEach(viewModel.weekGoals, id: \.self) { goal in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 5))
                                .foregroundStyle(ColorTokens.gold)
                                .padding(.top, 5)
                            Text(goal)
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - 4. Your Journey (phase + next milestone — merged)

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Your Journey")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: MilestonesDestination()) {
                    Text("All milestones")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .buttonStyle(.plain)
            }

            // Phase roadmap — visual timeline
            if !viewModel.phases.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // Phase dots with labels
                    HStack(spacing: 0) {
                        ForEach(Array(viewModel.phases.enumerated()), id: \.element.id) { index, phase in
                            let isCurrent = phase.status == "active"
                            let isCompleted = phase.status == "completed"

                            HStack(spacing: 0) {
                                // Dot
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(isCompleted ? ColorTokens.success : isCurrent ? ColorTokens.gold : ColorTokens.textTertiary.opacity(0.3))
                                            .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)

                                        if isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 6, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(phase.name)
                                        .font(.system(size: isCurrent ? 10 : 9, weight: isCurrent ? .bold : .regular))
                                        .foregroundStyle(isCurrent ? .white : ColorTokens.textTertiary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 70)
                                }

                                // Connector line
                                if index < viewModel.phases.count - 1 {
                                    Rectangle()
                                        .fill(isCompleted ? ColorTokens.success : ColorTokens.textTertiary.opacity(0.2))
                                        .frame(height: 2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 30) // Align with dots, not labels
                                }
                            }
                        }
                    }

                    // Current phase focus
                    if let phase = viewModel.currentPhase, let topics = phase.focusTopics, !topics.isEmpty {
                        HStack(spacing: 6) {
                            Text("Focus:")
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textTertiary)
                            ForEach(topics, id: \.self) { topic in
                                Text(topic)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ColorTokens.gold.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // Next milestone — inline, compact
            if let milestone = viewModel.nextMilestone {
                Divider()
                    .background(ColorTokens.textTertiary.opacity(0.2))

                HStack(spacing: 10) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Milestone")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .textCase(.uppercase)

                        Text(milestone.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let detail = viewModel.milestoneDetail(milestone) {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }

                    Spacer()

                    if let week = milestone.scheduledWeek {
                        Text("Week \(week)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(Capsule())
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

    // MARK: - 5. Skills Section (compact + actionable)

    private var skillsSection: some View {
        let competencies = viewModel.objectiveCompetencies
        let topicMastery = viewModel.topicMastery

        // Use competencies if available, otherwise topic mastery
        let hasCompetencies = !competencies.isEmpty
        let hasTopics = !topicMastery.isEmpty

        return Group {
            if hasCompetencies {
                competencySkillsCard(competencies)
            } else if hasTopics {
                topicSkillsCard(topicMastery)
            }
        }
    }

    private func competencySkillsCard(_ competencies: [ObjectiveCompetency]) -> some View {
        let sorted = competencies.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
        let overallReadiness = viewModel.overallReadiness
        let assessedCount = sorted.filter { ($0.currentScore ?? 0) > 0 }.count
        let needsAttention = sorted.filter { ($0.currentScore ?? 0) < 50 }.prefix(3)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "brain.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Skills You Need")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if let objId = viewModel.objectiveId {
                    NavigationLink(value: ObjectiveBriefDestination(objectiveId: objId)) {
                        Text("See all \(sorted.count) skills")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Overall readiness bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Readiness")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                    Text("\(overallReadiness)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(readinessColor(overallReadiness))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surfaceElevated)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(readinessColor(overallReadiness))
                            .frame(width: geo.size.width * CGFloat(overallReadiness) / 100)
                    }
                }
                .frame(height: 6)

                Text("\(assessedCount) of \(sorted.count) skills assessed")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Needs attention — top 3 weakest
            if !needsAttention.isEmpty {
                Divider()
                    .background(ColorTokens.textTertiary.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Needs attention")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)

                    ForEach(Array(needsAttention)) { comp in
                        HStack(spacing: 8) {
                            // Category dot
                            Circle()
                                .fill(categoryColor(comp.category))
                                .frame(width: 6, height: 6)

                            Text(comp.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            let score = Int(comp.currentScore ?? 0)
                            if score == 0 {
                                NavigationLink(value: ObjectiveBriefDestination(objectiveId: viewModel.objectiveId ?? "")) {
                                    Text("Assess")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(ColorTokens.gold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(ColorTokens.gold.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("\(score)%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
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

    private func topicSkillsCard(_ topics: [KnowledgeSnapshot]) -> some View {
        let sorted = topics.sorted { $0.score > $1.score }
        let needsWork = sorted.filter { $0.score < 50 }.prefix(3)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Topic Progress")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                ForEach(Array(sorted.prefix(5))) { topic in
                    NavigationLink(value: TopicDetailDestination(topic: topic.topic)) {
                        HStack {
                            ScoreBar(
                                topic: topic.topic,
                                score: topic.score,
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

            if !needsWork.isEmpty {
                HStack {
                    Spacer()
                    NavigationLink(value: QuizListDestination()) {
                        Text("Take a quiz to improve scores")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.gold)
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

    // MARK: - Helpers

    private func readinessColor(_ score: Int) -> Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return ColorTokens.gold }
        if score > 0 { return .orange }
        return ColorTokens.textTertiary
    }

    private func categoryColor(_ category: String?) -> Color {
        switch category {
        case "core": return ColorTokens.gold
        case "advanced": return .purple
        case "soft_skill": return .cyan
        default: return ColorTokens.gold
        }
    }

    private func statBadge(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ColorTokens.gold)
            Text("Loading your plan...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins) min"
    }
}
