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
                await viewModel.loadDashboard()
            }
        }
        .coachMark(
            .tabJourney,
            icon: "map.fill",
            title: "Learning Roadmap",
            message: "Set objectives and generate an AI-powered learning plan with daily goals and milestones."
        )
    }

    // MARK: - No Journey State (shows real objective + generate CTA)

    private var noJourneyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Show real objective if available
                if viewModel.userObjective != nil {
                    goalHeader
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

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // 1. GOAL — What am I working toward?
                goalHeader

                // 2. PROGRESS + PACE — How far am I? Am I on track?
                if viewModel.overallProgress >= 1.0 {
                    completionCelebration
                } else {
                    progressPaceCard
                }

                // 3. PHASE — Where am I in the journey?
                if viewModel.currentPhase != nil {
                    phaseSection
                }

                // 4. TODAY — What's on my plate?
                todaySection

                // 5. NEXT ACTION — What should I do right now?
                if let action = viewModel.primaryNextAction {
                    nextActionCard(action)
                }

                // 6. THIS WEEK — How's my week going?
                weekStripSection

                if !viewModel.weekGoals.isEmpty {
                    weekGoalsSection
                }

                // 7. SKILL / TOPIC MASTERY
                if !viewModel.objectiveCompetencies.isEmpty {
                    competencyMasterySection
                } else if !viewModel.topicMastery.isEmpty {
                    topicMasterySection
                }

                // 8. MILESTONES — What have I achieved / what's next?
                if !viewModel.milestones.isEmpty {
                    milestonesSection
                }

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - 1. Goal Header

    private var goalHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Streak badge row
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

            // Goal statement
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.gold)
                    Text("GOAL")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(ColorTokens.gold)
                }

                Text(viewModel.goalTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: Spacing.md) {
                    if !viewModel.timelineDisplay.isEmpty {
                        Label(viewModel.timelineDisplay, systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    if !viewModel.currentLevel.isEmpty {
                        Label(viewModel.currentLevel, systemImage: "gauge.with.dots.needle.33percent")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    if viewModel.weeklyHours > 0 {
                        Label("\(viewModel.weeklyHours)h/week", systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }

                // View Objective Brief button
                if let objId = viewModel.objectiveId {
                    NavigationLink(value: ObjectiveBriefDestination(objectiveId: objId)) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.fill")
                                .font(.system(size: 11))
                            Text("View Objective Brief")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - 2. Progress + Pace

    private var progressPaceCard: some View {
        VStack(spacing: Spacing.md) {
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.gold)

                    Text("complete")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textSecondary)

                    Spacer()

                    Text("Week \(viewModel.currentWeek) of \(viewModel.totalWeeks)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }

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
            }

            // Pace indicator + stats
            HStack(spacing: Spacing.lg) {
                // Pace status
                HStack(spacing: 6) {
                    Image(systemName: viewModel.paceIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.paceColor)

                    Text(viewModel.paceStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.paceColor)
                }

                Spacer()

                // Quick stats
                HStack(spacing: Spacing.md) {
                    miniStat(value: "\(viewModel.dashboard?.progress?.contentConsumed ?? 0)/\(viewModel.dashboard?.progress?.contentAssigned ?? 0)", label: "Lessons")

                    NavigationLink(value: QuizListDestination()) {
                        miniStat(value: "\(viewModel.dashboard?.progress?.quizzesCompleted ?? 0)/\(viewModel.dashboard?.progress?.quizzesAssigned ?? 0)", label: "Quizzes")
                    }
                    .buttonStyle(.plain)

                    miniStat(value: "\(viewModel.dashboard?.progress?.milestonesCompleted ?? 0)/\(viewModel.dashboard?.progress?.milestonesTotal ?? 0)", label: "Milestones")
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Completion Celebration

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
                miniStat(value: "\(viewModel.dashboard?.progress?.contentConsumed ?? 0)", label: "Lessons")
                miniStat(value: "\(viewModel.dashboard?.progress?.quizzesCompleted ?? 0)", label: "Quizzes")
                miniStat(value: "\(viewModel.dashboard?.progress?.milestonesCompleted ?? 0)", label: "Milestones")
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

    // MARK: - 3. Phase

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Current Phase")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("Phase \(viewModel.phaseProgress)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            if let phase = viewModel.currentPhase {
                VStack(alignment: .leading, spacing: 8) {
                    Text(phase.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    // Phase roadmap dots
                    HStack(spacing: 6) {
                        ForEach(viewModel.phases) { p in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(phaseColor(p.status))
                                    .frame(width: 8, height: 8)
                                if p.id == phase.id {
                                    Text(p.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    // Focus topics
                    if let topics = phase.focusTopics, !topics.isEmpty {
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
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.surface)
                )
            }
        }
    }

    private func phaseColor(_ status: String?) -> Color {
        switch status {
        case "completed": return ColorTokens.success
        case "active": return ColorTokens.gold
        default: return ColorTokens.textTertiary.opacity(0.5)
        }
    }

    // MARK: - 4. Next Action Card

    private func nextActionCard(_ action: NextActionItem) -> some View {
        Group {
            if action.type == "take_quiz", let _ = action.quizId {
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

    // MARK: - 4b. Quizzes Section

    private var quizzesSection: some View {
        let completed = viewModel.dashboard?.progress?.quizzesCompleted ?? 0
        let assigned = viewModel.dashboard?.progress?.quizzesAssigned ?? 0

        return NavigationLink(value: QuizListDestination()) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quizzes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    if assigned > 0 {
                        Text("\(completed)/\(assigned) completed")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                    } else {
                        Text("Test your knowledge")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTokens.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text("Today's Learning")
                    .font(Typography.titleMedium)
                    .foregroundStyle(.white)

                Spacer()

                if let stats = viewModel.todayStats {
                    Text("\(stats.completedItems ?? 0)/\(stats.totalItems ?? 0) done")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }
            }

            if viewModel.todayContent.isEmpty {
                restDayCard
            } else {
                VStack(spacing: 8) {
                    // Incomplete items first
                    ForEach(viewModel.incompleteContent) { content in
                        NavigationLink(value: content) {
                            todayContentRow(content)
                        }
                        .buttonStyle(.plain)
                    }

                    // Completed items below with visual distinction
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
        }
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

                // Completion badge
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

                // Progress bar for in-progress items
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

    private var restDayCard: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.gold)
            Text("Rest Day")
                .font(Typography.titleMedium)
                .foregroundStyle(.white)
            Text("Take a break and recharge!")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - 6. Week Strip

    private var weekStripSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("This Week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)

                if let theme = viewModel.dashboard?.currentWeek?.theme {
                    Text("· \(theme)")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            WeekStrip(
                days: viewModel.weekDays,
                currentDay: viewModel.currentDayOfWeek
            ) { _ in }
        }
    }

    // MARK: - Week Goals

    private var weekGoalsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Week Goals")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.weekGoals, id: \.self) { goal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 6))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.top, 5)
                        Text(goal)
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.gold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - 7. Competency Mastery (AI Skills)

    private var competencyMasterySection: some View {
        let sorted = viewModel.objectiveCompetencies.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
        let top6 = Array(sorted.prefix(6))

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Skill Readiness")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if let objId = viewModel.objectiveId {
                    NavigationLink(value: ObjectiveBriefDestination(objectiveId: objId)) {
                        Text("View Brief")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 8) {
                ForEach(top6) { comp in
                    if let objId = viewModel.objectiveId {
                        NavigationLink(value: ObjectiveBriefDestination(objectiveId: objId)) {
                            HStack {
                                CompetencyScoreBar(
                                    name: comp.name,
                                    score: Int(comp.currentScore ?? 0),
                                    category: comp.category,
                                    weight: comp.weight,
                                    trend: comp.trend
                                )
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        CompetencyScoreBar(
                            name: comp.name,
                            score: Int(comp.currentScore ?? 0),
                            category: comp.category,
                            weight: comp.weight,
                            trend: comp.trend
                        )
                    }
                }
            }

            if sorted.count > 6 {
                HStack {
                    Spacer()
                    Text("+\(sorted.count - 6) more skills")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - 7b. Topic Mastery (Fallback)

    private var topicMasterySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Topic Progress")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.topicMastery) { topic in
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
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
    }

    // MARK: - 8. Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
                Text("Milestones")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    viewModel.showAddMilestone = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.gold)
                }

                NavigationLink(value: MilestonesDestination()) {
                    Text("See All")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .sheet(isPresented: $viewModel.showAddMilestone) {
                AddMilestoneSheet(viewModel: viewModel)
            }

            VStack(spacing: 0) {
                ForEach(Array(viewModel.milestones.prefix(4).enumerated()), id: \.element.id) { _, milestone in
                    if let topic = milestone.targetCriteria?.targetTopic {
                        NavigationLink(value: TopicDetailDestination(topic: topic)) {
                            MilestoneCard(
                                milestone: milestone,
                                isNext: milestone.id == viewModel.nextMilestone?.id
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        MilestoneCard(
                            milestone: milestone,
                            isNext: milestone.id == viewModel.nextMilestone?.id
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
