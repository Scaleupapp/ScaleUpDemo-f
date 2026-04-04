import SwiftUI

struct InterviewSetupView: View {
    @Bindable var viewModel: InterviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var objectives: [UserObjective] = []
    @State private var isLoadingObjectives = false

    private let objectiveService = ObjectiveService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headerSection
                    typeSelector
                    roleSection
                    difficultySection
                    objectiveSection
                    estimateText
                    startButton
                    Spacer().frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            closeButton
        }
        .task {
            await loadObjectives()
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 36, height: 36)
                .background(ColorTokens.surfaceElevated)
                .clipShape(Circle())
        }
        .padding(.leading, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Spacer().frame(height: Spacing.xl)

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text("Mock Interview")
                .font(Typography.displayMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Practice with an AI interviewer in a realistic voice conversation")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("INTERVIEW TYPE")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                ForEach(InterviewType.allCases) { type in
                    interviewTypeCard(type)
                }
            }
        }
    }

    private func interviewTypeCard(_ type: InterviewType) -> some View {
        let isSelected = viewModel.selectedType == type

        return Button {
            Haptics.selection()
            withAnimation(Motion.springSnappy) {
                viewModel.selectedType = type
            }
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(type.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(type.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(Typography.bodyBold)
                        .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    Text(type.description)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(type.color)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? type.color.opacity(0.08) : ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? type.color.opacity(0.4) : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Role Section

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TARGET DETAILS")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                // Target Role (required)
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 20)

                    TextField("Target Role", text: $viewModel.targetRole)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .tint(ColorTokens.gold)
                }
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )

                // Target Company (optional)
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 20)

                    TextField("Target Company (optional)", text: $viewModel.targetCompany)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .tint(ColorTokens.gold)
                }
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DIFFICULTY")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)

            HStack(spacing: 0) {
                ForEach(InterviewDifficulty.allCases, id: \.rawValue) { difficulty in
                    let isSelected = viewModel.selectedDifficulty == difficulty

                    Button {
                        Haptics.selection()
                        withAnimation(Motion.springSnappy) {
                            viewModel.selectedDifficulty = difficulty
                        }
                    } label: {
                        Text(difficulty.displayName)
                            .font(isSelected ? Typography.bodySmallBold : Typography.bodySmall)
                            .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? ColorTokens.gold : ColorTokens.surface)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Estimate

    private var estimateText: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("~15-20 minutes")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Objective Section

    private var objectiveSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("LINK TO OBJECTIVE")
                .font(Typography.captionBold)
                .foregroundStyle(ColorTokens.textTertiary)
                .tracking(1)

            if isLoadingObjectives {
                HStack {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                }
                .padding(.vertical, Spacing.md)
            } else {
                let columns = [GridItem(.adaptive(minimum: 140), spacing: Spacing.sm)]

                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    // None option
                    objectiveChip(title: "None", icon: "xmark.circle", color: ColorTokens.textTertiary, isSelected: viewModel.selectedObjectiveId == nil) {
                        Haptics.selection()
                        withAnimation(Motion.springSnappy) {
                            viewModel.selectedObjectiveId = nil
                        }
                    }

                    // Active objectives
                    ForEach(objectives.filter { $0.status == .active }) { obj in
                        objectiveChip(title: obj.specificTitle, icon: obj.typeIcon, color: ColorTokens.gold, isSelected: viewModel.selectedObjectiveId == obj.id) {
                            Haptics.selection()
                            withAnimation(Motion.springSnappy) {
                                viewModel.selectedObjectiveId = obj.id
                            }
                        }
                    }
                }
            }
        }
    }

    private func objectiveChip(title: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : color)

                Text(title)
                    .font(isSelected ? Typography.captionBold : Typography.caption)
                    .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? ColorTokens.gold : ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? ColorTokens.gold : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadObjectives() async {
        isLoadingObjectives = true
        do {
            objectives = try await objectiveService.list()
        } catch {
            objectives = []
        }
        isLoadingObjectives = false
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Haptics.medium()
            viewModel.proceedToCameraCheck()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                Text("Start Interview")
                    .font(Typography.bodyBold)
            }
            .foregroundStyle(viewModel.canStart ? ColorTokens.buttonPrimaryText : ColorTokens.buttonDisabledText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canStart ? ColorTokens.gold : ColorTokens.buttonDisabledBg)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .disabled(!viewModel.canStart)
        .buttonStyle(.plain)
    }
}
