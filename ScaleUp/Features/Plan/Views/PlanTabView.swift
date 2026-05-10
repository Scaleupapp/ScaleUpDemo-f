import SwiftUI

struct PlanTabView: View {
    @State private var viewModel = PlanTabViewModel()
    @State private var recalVM = RecalibrationViewModel()
    @State private var showRecalibration = false
    @State private var presentedQuizId: String?
    @State private var presentedContentId: String?
    @State private var presentedContentType: String?
    @State private var presentedManualTask: APIPlanTask?
    @State private var presentedInterviewScenario: String?
    @State private var presentingCompetitionHub = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                switch viewModel.loadState {
                case .idle, .loading:
                    loadingState

                case .generating:
                    generatingState

                case .ready(let plan):
                    planContent(plan)

                case .error(let kind, let message):
                    errorState(kind: kind, message: message)
                }
            }
            .navigationTitle("My Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.load()
            await recalVM.checkEligibility()
        }
        .fullScreenCover(isPresented: $showRecalibration) {
            RecalibrationOrchestrationView(viewModel: recalVM)
        }
        .sheet(item: Binding(
            get: { presentedQuizId.map(IdentifiedString.init) },
            set: { presentedQuizId = $0?.value }
        )) { wrap in
            PlanTaskQuizLoaderSheet(quizId: wrap.value, onDismiss: { presentedQuizId = nil })
        }
        .sheet(item: Binding(
            get: { presentedContentId.map(IdentifiedString.init) },
            set: { newValue in
                presentedContentId = newValue?.value
                if newValue == nil { presentedContentType = nil }
            }
        )) { wrap in
            contentSheetView(contentId: wrap.value, contentType: presentedContentType)
        }
        .sheet(item: $presentedManualTask) { task in
            ManualCompletionSheet(task: task) {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: Binding(
            get: { presentedInterviewScenario.map(IdentifiedString.init) },
            set: { presentedInterviewScenario = $0?.value }
        )) { wrap in
            interviewSheet(scenario: wrap.value)
        }
        .sheet(isPresented: $presentingCompetitionHub) {
            NavigationStack {
                CompetitionHubView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { presentingCompetitionHub = false }
                        }
                    }
            }
        }
    }

    // MARK: - Interview Sheet

    /// Presents the interview flow for an `.aiInterview` plan task.
    /// `InterviewSessionView` requires an `InterviewViewModel`; the user picks
    /// the scenario inside `InterviewSetupView`. The scenario string from the
    /// plan task payload is forwarded for analytics; routing it directly into
    /// the setup view requires a richer InterviewViewModel API not present in
    /// Phase 3. See report for follow-up.
    @ViewBuilder
    private func interviewSheet(scenario: String) -> some View {
        NavigationStack {
            InterviewSessionView(viewModel: InterviewViewModel())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { presentedInterviewScenario = nil }
                    }
                }
        }
    }

    // MARK: - Content Sheet

    @ViewBuilder
    private func contentSheetView(contentId: String, contentType: String?) -> some View {
        NavigationStack {
            // Route to NotesDetailView if the content is notes-shaped; otherwise PlayerView.
            // The contentType string comes from the task payload (set by the backend
            // generator) so we don't need to fetch the full Content document.
            if contentType == "notes" {
                NotesDetailView(contentId: contentId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                presentedContentId = nil
                                presentedContentType = nil
                            }
                        }
                    }
            } else {
                PlayerView(contentId: contentId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                presentedContentId = nil
                                presentedContentType = nil
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 160)
                .padding(.horizontal, Spacing.lg)
            HStack(spacing: Spacing.sm) {
                SkeletonLoader(height: 90)
                SkeletonLoader(height: 90)
                SkeletonLoader(height: 90)
            }
            .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 80)
                .padding(.horizontal, Spacing.lg)
            SkeletonLoader(height: 80)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - Generating State

    private var generatingState: some View {
        GeneratingPlanView()
    }

    // MARK: - Error State

    private func errorState(kind: PlanErrorKind, message: String) -> some View {
        let (title, subtitle): (String, String) = {
            switch kind {
            case .diagnosticIncomplete:
                return ("Your plan isn't ready yet", "Finish your diagnostic and we'll build it for you in a minute.")
            case .planGenerationFailed:
                return ("We couldn't build your plan", "Something went wrong on our end. Tap below to try again.")
            case .loadFailed:
                return ("Couldn't load your plan", "Check your connection and try again.")
            }
        }()

        return VStack(spacing: Spacing.lg) {
            Spacer()

            // Soft warm glow behind icon — less alarming than a yellow triangle
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.10))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(ColorTokens.gold.opacity(0.20), lineWidth: 1)
                    .frame(width: 140, height: 140)
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(ColorTokens.gold)
            }

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xl)
            }

            // Tiny diagnostic note for advanced users / loadFailed details
            if !message.isEmpty {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xs)
            }

            PrimaryButton(title: "Try again") {
                Task { await viewModel.retry() }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Task Tap

    private func handleTaskTap(_ task: APIPlanTask) {
        let typeRaw = task.type.rawValue
        AnalyticsService.shared.track(.planTaskTapped(taskType: typeRaw, taskId: task.taskId))

        switch task.type {
        case .quiz:
            if let quizId = task.payload?["quizId"]?.value as? String {
                presentedQuizId = quizId
            }
        case .inAppContent:
            if let contentId = task.payload?["contentId"]?.value as? String {
                // Set type before id so the sheet's body sees both on first render.
                presentedContentType = task.payload?["contentType"]?.value as? String
                presentedContentId = contentId
            }
        case .aiInterview:
            let scenario = (task.payload?["scenario"]?.value as? String)
                ?? "placement_behavioral"
            presentedInterviewScenario = scenario
        case .competition:
            presentingCompetitionHub = true
        case .manual, .externalLink:
            presentedManualTask = task
        }
    }

    // MARK: - Plan Content

    private func planContent(_ plan: PlanDTO) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ObjectiveBriefCard(plan: plan)
                    .padding(.horizontal, Spacing.lg)

                NextCheckInPill(
                    nextCheckInAt: plan.nextCheckInAt,
                    isEligibleNow: recalVM.eligibility?.eligible == true,
                    onRecalibrateTap: { showRecalibration = true }
                )
                .padding(.horizontal, Spacing.lg)

                if let current = viewModel.currentWeekTasks(in: plan) {
                    ThisWeekTasksList(
                        weekNumber: current.weekNumber,
                        weekLabel: current.weekLabel,
                        tasks: current.tasks,
                        onTaskTap: { task in handleTaskTap(task) }
                    )
                }

                if !plan.milestones.isEmpty {
                    milestonesSection(plan.milestones)
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Weekly Schedule Section

    private func weeklySection(_ schedule: [APIPlanWeeklyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text("Weekly Schedule")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.sm) {
                ForEach(schedule, id: \.weekNumber) { entry in
                    WeeklyAllocationCard(entry: entry)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    // MARK: - Milestones Section

    private func milestonesSection(_ milestones: [APIPlanMilestone]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
                Text("Milestones")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)

            MilestonePreview(milestones: milestones)
                .padding(.horizontal, Spacing.lg)
        }
    }
}

// MARK: - Sheet Item Helper

/// Identifiable wrapper around String so we can drive `.sheet(item:)` from a
/// plain `String?` state. Used for quiz/content sheets where the item identity
/// is just the id.
private struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - APIPlanTask Identifiable

/// Generated `APIPlanTask` doesn't conform to `Identifiable`. We need it to
/// drive `.sheet(item:)` for the manual completion flow. Conformance is
/// declared here (rather than mutating the generated file) so regen doesn't
/// blow it away.
extension APIPlanTask: Identifiable {
    public var id: String { taskId }
}
