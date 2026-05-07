import SwiftUI

struct PlanTabView: View {
    @State private var viewModel = PlanTabViewModel()
    @State private var recalVM = RecalibrationViewModel()
    @State private var showRecalibration = false

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

                case .error(let message):
                    errorState(message)
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
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonLoader(height: 120)
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
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.gold)

            Text("Crafting your personalised plan…")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("Usually takes about 45 seconds")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.warning)

            Text("Couldn't load your plan")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await viewModel.retry() }
            }
            .font(Typography.bodyBold)
            .foregroundStyle(ColorTokens.buttonPrimaryText)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(ColorTokens.gold)
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Plan Content

    private func planContent(_ plan: PlanDTO) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let eligibility = recalVM.eligibility, eligibility.eligible {
                    RecalibrationNudge(eligibility: eligibility) {
                        showRecalibration = true
                    }
                    .padding(.horizontal, Spacing.lg)
                }

                heroCard(plan)
                    .padding(.horizontal, Spacing.lg)

                if !plan.weeklySchedule.isEmpty {
                    weeklySection(plan.weeklySchedule)
                }

                if !plan.milestones.isEmpty {
                    milestonesSection(plan.milestones)
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ plan: PlanDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(plan.planHeadline)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            HStack(spacing: Spacing.lg) {
                statBadge(value: "\(plan.totalWeeks)", label: "weeks")
                statBadge(value: String(format: "%.0fh", plan.totalHours), label: "total")
                statBadge(value: "\(plan.milestoneCount)", label: "milestones")
            }

            if let buffer = plan.bufferRecommendation {
                Text(buffer)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorTokens.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.gold)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Weekly Schedule Section

    private func weeklySection(_ schedule: [WeeklyEntry]) -> some View {
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

    private func milestonesSection(_ milestones: [PlanMilestone]) -> some View {
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
