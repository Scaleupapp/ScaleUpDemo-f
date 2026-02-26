import SwiftUI

// MARK: - Journey View

struct JourneyView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: JourneyViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && !viewModel.hasJourney {
                        journeySkeletonView
                    } else if let error = viewModel.error, !viewModel.hasJourney {
                        ErrorStateView(
                            message: error.errorDescription ?? "Failed to load journey."
                        ) {
                            Task { await viewModel.loadJourney() }
                        }
                    } else if viewModel.hasJourney {
                        journeyContent(viewModel: viewModel)
                    } else {
                        emptyState(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if let viewModel, viewModel.hasJourney {
                    toolbarItems(viewModel: viewModel)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showGenerateSheet ?? false },
                set: { viewModel?.showGenerateSheet = $0 }
            )) {
                GenerateJourneyView { journey in
                    viewModel?.journey = journey
                    viewModel?.showGenerateSheet = false
                    Task { await viewModel?.refresh() }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = JourneyViewModel(
                    journeyService: dependencies.journeyService
                )
            }
        }
        .task {
            if let viewModel, !viewModel.hasJourney {
                await viewModel.loadJourney()
            }
        }
    }

    // MARK: - Toolbar Items

    @ToolbarContentBuilder
    private func toolbarItems(viewModel: JourneyViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Spacing.sm) {
                NavigationLink {
                    WeeklyPlanView(
                        weekNumber: viewModel.journey?.currentWeek ?? 1,
                        totalWeeks: viewModel.journey?.weeklyPlans.count ?? 1,
                        journeyService: dependencies.journeyService
                    )
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                NavigationLink {
                    MilestonesView()
                } label: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Button {
                    Task {
                        if viewModel.isPaused {
                            await viewModel.resumeJourney()
                        } else {
                            await viewModel.pauseJourney()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(viewModel.isPaused ? ColorTokens.success : ColorTokens.warning)
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyState(viewModel: JourneyViewModel) -> some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "map.fill",
                title: "Start Your Journey",
                subtitle: "Set an objective and we'll create a personalized learning path",
                buttonTitle: "Get Started"
            ) {
                viewModel.showGenerateSheet = true
            }
            Spacer()
        }
    }

    // MARK: - Journey Content

    @ViewBuilder
    private func journeyContent(viewModel: JourneyViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Journey Header
                journeyHeader(viewModel: viewModel)

                // Progress Overview Card
                progressOverviewCard(viewModel: viewModel)

                // Today's Plan Card
                todayPlanCard(viewModel: viewModel)

                // Phase Map Section
                phaseMapSection(viewModel: viewModel)

                // Milestones Preview
                milestonesPreview(viewModel: viewModel)

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Journey Header

    @ViewBuilder
    private func journeyHeader(viewModel: JourneyViewModel) -> some View {
        if let journey = viewModel.journey {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(journey.title)
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                HStack(spacing: Spacing.sm) {
                    // Phase badge
                    Text(phaseDisplayName(journey.currentPhase))
                        .font(Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(phaseColor(journey.currentPhase))
                        .clipShape(Capsule())

                    // Status indicator
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(statusColor(journey.status))
                            .frame(width: 8, height: 8)
                        Text(journey.status.rawValue.capitalized)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    Spacer()

                    // Streak badge
                    if (journey.progress.currentStreak ?? 0) > 0 {
                        StreakBadge(count: journey.progress.currentStreak ?? 0)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Progress Overview Card

    @ViewBuilder
    private func progressOverviewCard(viewModel: JourneyViewModel) -> some View {
        if let journey = viewModel.journey {
            let progress = journey.progress

            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.lg) {
                    ProgressRing(
                        progress: (progress.overallPercentage ?? 0) / 100.0,
                        size: 100,
                        lineWidth: 10
                    )

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Overall Progress")
                            .font(Typography.titleMedium)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        Text("Week \(journey.currentWeek) of \(journey.weeklyPlans.count)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }

                    Spacer()
                }

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Spacing.md) {
                    statItem(
                        value: "\(progress.contentConsumed ?? 0)/\(progress.contentAssigned ?? 0)",
                        label: "Content"
                    )
                    statItem(
                        value: "\(progress.quizzesCompleted ?? 0)/\(progress.quizzesAssigned ?? 0)",
                        label: "Quizzes"
                    )
                    statItem(
                        value: "\(progress.milestonesCompleted ?? 0)/\(progress.milestonesTotal ?? 0)",
                        label: "Milestones"
                    )
                }
            }
            .cardStyle()
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Stat Item

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(Typography.mono)
                .foregroundStyle(ColorTokens.primary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Today's Plan Card

    @ViewBuilder
    private func todayPlanCard(viewModel: JourneyViewModel) -> some View {
        if let todayPlan = viewModel.todayPlan {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    SectionHeader(title: "Today's Plan")
                    Spacer()
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Week \(todayPlan.weekNumber), Day \(todayPlan.day)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                        Spacer()
                        Text("\(todayPlan.plan.estimatedMinutes) min")
                            .font(Typography.mono)
                            .foregroundStyle(ColorTokens.primary)
                    }

                    if todayPlan.plan.isRestDay {
                        // Rest day message
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(ColorTokens.success)
                            Text("Rest day — take a break and recharge!")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimaryDark)
                        }
                        .padding(.vertical, Spacing.sm)
                    } else {
                        // Topics list
                        ForEach(todayPlan.plan.topics ?? [], id: \.self) { topic in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.primary)
                                Text(topic)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textPrimaryDark)
                            }
                        }

                        // Start Learning button
                        NavigationLink {
                            TodayPlanView(todayPlan: todayPlan)
                        } label: {
                            Text("Start Learning")
                                .font(Typography.bodyBold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(ColorTokens.heroGradient)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Phase Map Section

    @ViewBuilder
    private func phaseMapSection(viewModel: JourneyViewModel) -> some View {
        if let journey = viewModel.journey {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Learning Path") {
                    // Navigate to full phase map
                }

                NavigationLink {
                    PhaseMapView(journey: journey)
                        .environment(dependencies)
                } label: {
                    phaseMapPreview(journey: journey)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Phase Map Preview

    @ViewBuilder
    private func phaseMapPreview(journey: Journey) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(journey.phases.enumerated()), id: \.offset) { index, phase in
                let isCurrent = index == journey.currentPhaseIndex
                let isPast = index < journey.currentPhaseIndex

                HStack(spacing: Spacing.md) {
                    // Timeline node
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(isPast || isCurrent ? ColorTokens.primary : ColorTokens.textTertiaryDark.opacity(0.3))
                                .frame(width: 2, height: Spacing.md)
                        }
                        Circle()
                            .fill(isCurrent ? ColorTokens.primary : (isPast ? ColorTokens.success : ColorTokens.textTertiaryDark.opacity(0.3)))
                            .frame(width: isCurrent ? 16 : 12, height: isCurrent ? 16 : 12)
                            .overlay {
                                if isPast {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        if index < journey.phases.count - 1 {
                            Rectangle()
                                .fill(isPast ? ColorTokens.primary : ColorTokens.textTertiaryDark.opacity(0.3))
                                .frame(width: 2, height: Spacing.md)
                        }
                    }

                    // Phase info
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(phase.name.capitalized)
                            .font(isCurrent ? Typography.bodyBold : Typography.bodySmall)
                            .foregroundStyle(isCurrent ? ColorTokens.textPrimaryDark : ColorTokens.textSecondaryDark)

                        if isCurrent {
                            Text(phase.description)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if !phase.weekNumbers.isEmpty {
                        Text("W\(phase.weekNumbers.first ?? 0)-\(phase.weekNumbers.last ?? 0)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Milestones Preview

    @ViewBuilder
    private func milestonesPreview(viewModel: JourneyViewModel) -> some View {
        if let journey = viewModel.journey, !journey.milestones.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Milestones")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(journey.milestones.prefix(5)) { milestone in
                            MilestoneChip(
                                icon: milestoneIcon(for: milestone.type ?? ""),
                                title: milestone.title,
                                isCompleted: milestone.status == "completed"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Skeleton Loading View

    private var journeySkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Header skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 240, height: 24)
                    HStack(spacing: Spacing.sm) {
                        SkeletonLoader(width: 80, height: 24, cornerRadius: CornerRadius.full)
                        SkeletonLoader(width: 60, height: 16)
                    }
                }
                .padding(.horizontal, Spacing.md)

                // Progress card skeleton
                SkeletonLoader(height: 200, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Today's plan skeleton
                SkeletonLoader(height: 160, cornerRadius: CornerRadius.medium)
                    .padding(.horizontal, Spacing.md)

                // Phase map skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 140, height: 20)
                    SkeletonLoader(height: 180, cornerRadius: CornerRadius.medium)
                }
                .padding(.horizontal, Spacing.md)

                // Milestones skeleton
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonLoader(width: 120, height: 20)
                    HStack(spacing: Spacing.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonLoader(width: 120, height: 32, cornerRadius: CornerRadius.full)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Helpers

    private func phaseDisplayName(_ phase: JourneyPhase) -> String {
        switch phase {
        case .foundation: return "Foundation"
        case .building: return "Building"
        case .strengthening: return "Strengthening"
        case .mastery: return "Mastery"
        case .revision: return "Revision"
        case .examPrep: return "Exam Prep"
        }
    }

    private func phaseColor(_ phase: JourneyPhase) -> Color {
        switch phase {
        case .foundation: return ColorTokens.info
        case .building: return ColorTokens.primary
        case .strengthening: return ColorTokens.warning
        case .mastery: return ColorTokens.success
        case .revision: return Color(hex: "#FD79A8")
        case .examPrep: return ColorTokens.error
        }
    }

    private func statusColor(_ status: JourneyStatus) -> Color {
        switch status {
        case .active: return ColorTokens.success
        case .paused: return ColorTokens.warning
        case .completed: return ColorTokens.info
        case .generating: return ColorTokens.primary
        case .abandoned: return ColorTokens.error
        }
    }

    private func milestoneIcon(for type: String) -> String {
        switch type.lowercased() {
        case "content": return "book.fill"
        case "quiz": return "checkmark.seal.fill"
        case "streak": return "flame.fill"
        case "phase": return "flag.fill"
        case "completion": return "trophy.fill"
        default: return "star.fill"
        }
    }
}
