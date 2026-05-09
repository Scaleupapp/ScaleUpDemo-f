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

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
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
                Text("Your plan isn't ready yet")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Finish your diagnostic and we'll build it for you in a minute.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xl)
            }

            // Tiny diagnostic note for advanced users
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Eyebrow
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR PLAN")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
            }

            Text(plan.planHeadline)
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Stats row: bigger numbers, dividers between, animated count-in.
            HStack(spacing: 0) {
                statPill(value: "\(plan.totalWeeks)", label: plan.totalWeeks == 1 ? "week" : "weeks", icon: "calendar")
                Divider().frame(height: 36).background(ColorTokens.border)
                statPill(value: String(format: "%.0fh", plan.totalHours), label: "total", icon: "clock")
                Divider().frame(height: 36).background(ColorTokens.border)
                statPill(value: "\(plan.milestoneCount)", label: plan.milestoneCount == 1 ? "milestone" : "milestones", icon: "flag.fill")
            }
            .padding(.top, Spacing.xs)

            if let buffer = plan.bufferRecommendation, !buffer.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.gold.opacity(0.8))
                        .padding(.top, 2)
                    Text(buffer)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Layered gradient: dark teal base + gold glow top-right
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(ColorTokens.surface)

                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        RadialGradient(
                            colors: [ColorTokens.gold.opacity(0.18), .clear],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )

                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .strokeBorder(
                        LinearGradient(
                            colors: [ColorTokens.gold.opacity(0.45), ColorTokens.gold.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.gold.opacity(0.85))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
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
