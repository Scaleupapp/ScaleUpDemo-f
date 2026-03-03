import SwiftUI

struct ObjectiveStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Heading
                VStack(spacing: Spacing.sm) {
                    Text("What's your goal?")
                        .font(Typography.displayMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("This drives your entire learning journey")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.top, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Objective Grid
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(ObjectiveType.allCases) { objective in
                        objectiveCard(objective)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Specifics sub-form (slides in when objective is selected)
                if let objective = viewModel.selectedObjective, objective.requiresSpecifics {
                    specificsForm(for: objective)
                        .padding(.horizontal, Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Timeline + Level + Hours (always shown after selection)
                if viewModel.selectedObjective != nil {
                    detailsSection
                        .padding(.horizontal, Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: Spacing.xxl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Objective Card

    private func objectiveCard(_ objective: ObjectiveType) -> some View {
        let isSelected = viewModel.selectedObjective == objective

        return Button {
            Haptics.light()
            withAnimation(Motion.springSmooth) {
                viewModel.selectedObjective = objective
            }
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: objective.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? ColorTokens.gold : ColorTokens.textSecondary)

                Text(objective.displayName)
                    .font(Typography.bodyBold)
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)

                Text(objective.description)
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background(isSelected ? ColorTokens.gold.opacity(0.08) : ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? ColorTokens.gold : ColorTokens.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isSelected ? 1.0 : 0.98)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Specifics Form

    @ViewBuilder
    private func specificsForm(for objective: ObjectiveType) -> some View {
        VStack(spacing: Spacing.md) {
            switch objective {
            case .examPreparation:
                ScaleUpTextField(
                    label: "Exam Name",
                    icon: "pencil.and.list.clipboard",
                    text: $viewModel.examName,
                    autocapitalization: .words
                )

            case .upskilling:
                ScaleUpTextField(
                    label: "Target Skill",
                    icon: "star.fill",
                    text: $viewModel.targetSkill,
                    autocapitalization: .words
                )

            case .interviewPreparation:
                ScaleUpTextField(
                    label: "Target Role",
                    icon: "person.text.rectangle",
                    text: $viewModel.targetRole,
                    autocapitalization: .words
                )
                ScaleUpTextField(
                    label: "Target Company (optional)",
                    icon: "building.2.fill",
                    text: $viewModel.targetCompany,
                    autocapitalization: .words
                )

            case .careerSwitch:
                ScaleUpTextField(
                    label: "Current Domain",
                    icon: "arrow.left.circle",
                    text: $viewModel.fromDomain,
                    autocapitalization: .words
                )
                ScaleUpTextField(
                    label: "Target Domain",
                    icon: "arrow.right.circle",
                    text: $viewModel.toDomain,
                    autocapitalization: .words
                )

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Details Section (Timeline, Level, Hours)

    private var detailsSection: some View {
        VStack(spacing: Spacing.xl) {
            // Timeline
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Timeline")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Timeline.allCases) { tl in
                            chipButton(
                                title: tl.displayName,
                                isSelected: viewModel.timeline == tl
                            ) {
                                viewModel.timeline = tl
                            }
                        }
                    }
                }
            }

            // Level
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Current Level")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.sm) {
                    ForEach(CurrentLevel.allCases) { level in
                        chipButton(
                            title: level.displayName,
                            isSelected: viewModel.currentLevel == level
                        ) {
                            viewModel.currentLevel = level
                        }
                    }
                }
            }

            // Weekly Hours
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Weekly Commitment")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.weeklyHours)) hrs/week")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.gold)
                }

                Slider(value: $viewModel.weeklyHours, in: 1...40, step: 1)
                    .tint(ColorTokens.gold)

                HStack {
                    Text("1 hr")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Spacer()
                    Text("40 hrs")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Chip Button

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.springSnappy) {
                action()
            }
        } label: {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? ColorTokens.gold : ColorTokens.surfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : ColorTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
