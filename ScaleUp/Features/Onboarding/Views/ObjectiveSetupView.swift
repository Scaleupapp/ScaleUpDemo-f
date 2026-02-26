import SwiftUI

struct ObjectiveSetupView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.objectiveSubPage {
            case 1:
                objectiveTypePicker
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 2:
                objectiveSpecifics
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case 3:
                timelineAndLevel
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            default:
                EmptyView()
            }
        }
        .animation(Animations.standard, value: viewModel.objectiveSubPage)
    }

    // MARK: - Sub-Page 1: Objective Type Picker

    private var objectiveTypePicker: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                ForEach(ObjectiveTypeItem.allItems, id: \.type) { item in
                    objectiveCard(item: item)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func objectiveCard(item: ObjectiveTypeItem) -> some View {
        let isSelected = viewModel.selectedObjectiveType == item.type

        return Button {
            withAnimation(Animations.quick) {
                viewModel.selectedObjectiveType = item.type
            }
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? ColorTokens.primary : ColorTokens.textSecondaryDark)
                    .frame(height: 36)

                Text(item.title)
                    .font(Typography.bodyBold)
                    .foregroundStyle(isSelected ? ColorTokens.textPrimaryDark : ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)

                Text(item.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.sm)
            .background(
                isSelected
                    ? ColorTokens.primary.opacity(0.08)
                    : ColorTokens.surfaceDark
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Sub-Page 2: Objective Specifics

    private var objectiveSpecifics: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Dynamic form based on selected objective type
                if let objectiveType = viewModel.selectedObjectiveType {
                    specificFields(for: objectiveType)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func specificFields(for type: ObjectiveType) -> some View {
        switch type {
        case .examPreparation:
            TextFieldStyled(
                label: "Exam Name",
                placeholder: "e.g., SAT, GRE, GMAT, CAT",
                text: $viewModel.examName,
                icon: "doc.text.fill"
            )

        case .upskilling:
            TextFieldStyled(
                label: "Target Skill",
                placeholder: "e.g., Product Management, Data Science",
                text: $viewModel.targetSkill,
                icon: "arrow.up.circle.fill"
            )

        case .interviewPreparation:
            VStack(spacing: Spacing.md) {
                TextFieldStyled(
                    label: "Target Role",
                    placeholder: "e.g., Software Engineer, PM",
                    text: $viewModel.targetRole,
                    icon: "person.badge.key.fill"
                )

                TextFieldStyled(
                    label: "Target Company (optional)",
                    placeholder: "e.g., Google, Amazon",
                    text: $viewModel.targetCompany,
                    icon: "building.2.fill"
                )
            }

        case .careerSwitch:
            VStack(spacing: Spacing.md) {
                TextFieldStyled(
                    label: "Current Domain",
                    placeholder: "e.g., Software Engineering",
                    text: $viewModel.fromDomain,
                    icon: "arrow.left.circle.fill"
                )

                TextFieldStyled(
                    label: "Target Domain",
                    placeholder: "e.g., Product Management",
                    text: $viewModel.toDomain,
                    icon: "arrow.right.circle.fill"
                )
            }

        case .academicExcellence:
            TextFieldStyled(
                label: "Subject / Area",
                placeholder: "e.g., Machine Learning, Organic Chemistry",
                text: $viewModel.targetSkill,
                icon: "graduationcap.fill"
            )

        case .casualLearning:
            TextFieldStyled(
                label: "What interests you?",
                placeholder: "e.g., Philosophy, World History",
                text: $viewModel.targetSkill,
                icon: "book.fill"
            )

        case .networking:
            TextFieldStyled(
                label: "Industry / Field",
                placeholder: "e.g., Tech, Finance, Healthcare",
                text: $viewModel.targetSkill,
                icon: "person.3.fill"
            )
        }
    }

    // MARK: - Sub-Page 3: Timeline, Level, Hours

    private var timelineAndLevel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Timeline Picker
                timelinePicker

                // Level Picker
                levelPicker

                // Weekly Hours Slider
                weeklyHoursSlider
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Timeline Picker

    private var timelinePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Timeline")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(TimelineItem.allItems, id: \.timeline) { item in
                        timelinePill(item: item)
                    }
                }
            }
        }
    }

    private func timelinePill(item: TimelineItem) -> some View {
        let isSelected = viewModel.selectedTimeline == item.timeline

        return Button {
            withAnimation(Animations.quick) {
                viewModel.selectedTimeline = item.timeline
            }
        } label: {
            Text(item.label)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(isSelected ? ColorTokens.primary : ColorTokens.surfaceDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Level Picker

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Current Level")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            HStack(spacing: Spacing.sm) {
                ForEach(LevelItem.allItems, id: \.difficulty) { item in
                    levelOption(item: item)
                }
            }
        }
    }

    private func levelOption(item: LevelItem) -> some View {
        let isSelected = viewModel.currentLevel == item.difficulty

        return Button {
            withAnimation(Animations.quick) {
                viewModel.currentLevel = item.difficulty
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: item.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? ColorTokens.primary : ColorTokens.textTertiaryDark)

                Text(item.label)
                    .font(Typography.bodySmall)
                    .foregroundStyle(isSelected ? ColorTokens.textPrimaryDark : ColorTokens.textSecondaryDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                isSelected
                    ? ColorTokens.primary.opacity(0.08)
                    : ColorTokens.surfaceDark
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(
                        isSelected ? ColorTokens.primary : ColorTokens.surfaceElevatedDark,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Hours Slider

    private var weeklyHoursSlider: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Weekly Commitment")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Spacer()

                Text("\(Int(viewModel.weeklyCommitHours)) hrs/week")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
            }

            Slider(
                value: $viewModel.weeklyCommitHours,
                in: 1...40,
                step: 1
            )
            .tint(ColorTokens.primary)

            HStack {
                Text("1 hr")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                Spacer()
                Text("40 hrs")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
    }
}

// MARK: - Objective Type Item

private struct ObjectiveTypeItem {
    let type: ObjectiveType
    let icon: String
    let title: String
    let subtitle: String

    static let allItems: [ObjectiveTypeItem] = [
        ObjectiveTypeItem(
            type: .examPreparation,
            icon: "doc.text",
            title: "Exam Prep",
            subtitle: "Prepare for standardized tests"
        ),
        ObjectiveTypeItem(
            type: .upskilling,
            icon: "arrow.up.circle",
            title: "Upskilling",
            subtitle: "Level up your existing skills"
        ),
        ObjectiveTypeItem(
            type: .interviewPreparation,
            icon: "person.badge.key",
            title: "Interview Prep",
            subtitle: "Ace your next interview"
        ),
        ObjectiveTypeItem(
            type: .careerSwitch,
            icon: "arrow.triangle.swap",
            title: "Career Switch",
            subtitle: "Transition to a new field"
        ),
        ObjectiveTypeItem(
            type: .academicExcellence,
            icon: "graduationcap",
            title: "Academic",
            subtitle: "Excel in your studies"
        ),
        ObjectiveTypeItem(
            type: .casualLearning,
            icon: "book",
            title: "Casual Learning",
            subtitle: "Learn at your own pace"
        ),
        ObjectiveTypeItem(
            type: .networking,
            icon: "person.3",
            title: "Networking",
            subtitle: "Build professional connections"
        )
    ]
}

// MARK: - Timeline Item

private struct TimelineItem {
    let timeline: Timeline
    let label: String

    static let allItems: [TimelineItem] = [
        TimelineItem(timeline: .oneMonth, label: "1 Month"),
        TimelineItem(timeline: .threeMonths, label: "3 Months"),
        TimelineItem(timeline: .sixMonths, label: "6 Months"),
        TimelineItem(timeline: .oneYear, label: "1 Year"),
        TimelineItem(timeline: .noDeadline, label: "No Deadline")
    ]
}

// MARK: - Level Item

private struct LevelItem {
    let difficulty: Difficulty
    let icon: String
    let label: String

    static let allItems: [LevelItem] = [
        LevelItem(difficulty: .beginner, icon: "leaf.fill", label: "Beginner"),
        LevelItem(difficulty: .intermediate, icon: "flame.fill", label: "Intermediate"),
        LevelItem(difficulty: .advanced, icon: "bolt.fill", label: "Advanced")
    ]
}

// MARK: - Preview

#Preview {
    ZStack {
        ColorTokens.backgroundDark.ignoresSafeArea()
        ObjectiveSetupView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
