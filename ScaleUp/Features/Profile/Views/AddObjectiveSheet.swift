import SwiftUI

// MARK: - Add Objective Sheet

struct AddObjectiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ProfileViewModel

    @State private var step = 1
    @State private var selectedType: ObjectiveType = .upskilling
    @State private var selectedTimeline: Timeline = .threeMonths
    @State private var selectedLevel: Difficulty = .beginner
    @State private var weeklyHours: Double = 5
    @State private var isSaving = false

    // Specifics fields
    @State private var examName = ""
    @State private var targetSkill = ""
    @State private var targetRole = ""
    @State private var targetCompany = ""
    @State private var fromDomain = ""
    @State private var toDomain = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Step indicator
                        stepIndicator

                        if step == 1 {
                            objectiveTypePicker
                        } else if step == 2 {
                            specificsForm
                        } else {
                            detailsForm
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 1 {
                        Button("Back") { step -= 1 }
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if step < 3 {
                        Button("Next") { step += 1 }
                            .foregroundStyle(ColorTokens.primary)
                            .disabled(step == 2 && !hasValidSpecifics)
                    } else {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(ColorTokens.primary)
                            } else {
                                Text("Save")
                                    .foregroundStyle(ColorTokens.primary)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...3, id: \.self) { s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(s <= step ? ColorTokens.primary : ColorTokens.surfaceElevatedDark)
                    .frame(height: 3)
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: return "Objective Type"
        case 2: return "Details"
        case 3: return "Commitment"
        default: return ""
        }
    }

    // MARK: - Step 1: Type Picker

    private var objectiveTypePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What's your learning goal?")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            ForEach(objectiveTypeOptions, id: \.type) { option in
                Button {
                    selectedType = option.type
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: option.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(selectedType == option.type ? ColorTokens.primary : ColorTokens.textTertiaryDark)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Text(option.subtitle)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }

                        Spacer()

                        if selectedType == option.type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ColorTokens.primary)
                        }
                    }
                    .padding(Spacing.md)
                    .background(
                        selectedType == option.type
                            ? ColorTokens.primary.opacity(0.1)
                            : ColorTokens.surfaceDark
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(
                                selectedType == option.type ? ColorTokens.primary.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 2: Specifics

    private var specificsForm: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Tell us more")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            switch selectedType {
            case .examPreparation:
                objectiveTextField("Exam Name", text: $examName, placeholder: "e.g. AWS Solutions Architect")

            case .upskilling, .casualLearning, .networking:
                objectiveTextField("Target Skill / Interest", text: $targetSkill, placeholder: "e.g. Machine Learning, React Native")

            case .interviewPreparation:
                objectiveTextField("Target Role", text: $targetRole, placeholder: "e.g. Senior iOS Developer")
                objectiveTextField("Target Company (optional)", text: $targetCompany, placeholder: "e.g. Apple, Google")

            case .careerSwitch:
                objectiveTextField("Current Domain", text: $fromDomain, placeholder: "e.g. Backend Development")
                objectiveTextField("Target Domain", text: $toDomain, placeholder: "e.g. iOS Development")

            case .academicExcellence:
                objectiveTextField("Subject / Area", text: $targetSkill, placeholder: "e.g. Data Structures, Algorithms")
            }
        }
    }

    private func objectiveTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            TextField(placeholder, text: text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(Spacing.md)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .tint(ColorTokens.primary)
        }
    }

    private var hasValidSpecifics: Bool {
        switch selectedType {
        case .examPreparation: return !examName.trimmingCharacters(in: .whitespaces).isEmpty
        case .upskilling, .casualLearning, .networking, .academicExcellence:
            return !targetSkill.trimmingCharacters(in: .whitespaces).isEmpty
        case .interviewPreparation: return !targetRole.trimmingCharacters(in: .whitespaces).isEmpty
        case .careerSwitch:
            return !fromDomain.trimmingCharacters(in: .whitespaces).isEmpty
                && !toDomain.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Step 3: Details

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Timeline
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Timeline")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                HStack(spacing: Spacing.xs) {
                    ForEach(timelineOptions, id: \.timeline) { option in
                        Button {
                            selectedTimeline = option.timeline
                        } label: {
                            Text(option.label)
                                .font(Typography.caption)
                                .foregroundStyle(
                                    selectedTimeline == option.timeline
                                        ? .white
                                        : ColorTokens.textSecondaryDark
                                )
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs + 2)
                                .background(
                                    selectedTimeline == option.timeline
                                        ? ColorTokens.primary
                                        : ColorTokens.surfaceDark
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Level
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Current Level")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                HStack(spacing: Spacing.sm) {
                    ForEach([Difficulty.beginner, .intermediate, .advanced], id: \.self) { level in
                        Button {
                            selectedLevel = level
                        } label: {
                            Text(level.rawValue.capitalized)
                                .font(Typography.bodySmall)
                                .foregroundStyle(
                                    selectedLevel == level ? .white : ColorTokens.textSecondaryDark
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    selectedLevel == level ? ColorTokens.primary : ColorTokens.surfaceDark
                                )
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Weekly Hours
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Weekly Commitment")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Spacer()

                    Text("\(Int(weeklyHours)) hrs/week")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.primary)
                }

                Slider(value: $weeklyHours, in: 1...40, step: 1)
                    .tint(ColorTokens.primary)

                HStack {
                    Text("1 hr")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                    Spacer()
                    Text("40 hrs")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        var specifics: [String: String] = [:]

        switch selectedType {
        case .examPreparation:
            specifics["examName"] = examName.trimmingCharacters(in: .whitespaces)
        case .upskilling, .casualLearning, .networking, .academicExcellence:
            specifics["targetSkill"] = targetSkill.trimmingCharacters(in: .whitespaces)
        case .interviewPreparation:
            specifics["targetRole"] = targetRole.trimmingCharacters(in: .whitespaces)
            if !targetCompany.trimmingCharacters(in: .whitespaces).isEmpty {
                specifics["targetCompany"] = targetCompany.trimmingCharacters(in: .whitespaces)
            }
        case .careerSwitch:
            specifics["fromDomain"] = fromDomain.trimmingCharacters(in: .whitespaces)
            specifics["toDomain"] = toDomain.trimmingCharacters(in: .whitespaces)
        }

        await viewModel.createObjective(
            objectiveType: selectedType,
            timeline: selectedTimeline,
            currentLevel: selectedLevel,
            weeklyCommitHours: Int(weeklyHours),
            specifics: specifics.isEmpty ? nil : specifics
        )

        isSaving = false
        dismiss()
    }

    // MARK: - Data

    private struct TypeOption {
        let type: ObjectiveType
        let icon: String
        let label: String
        let subtitle: String
    }

    private var objectiveTypeOptions: [TypeOption] {
        [
            TypeOption(type: .examPreparation, icon: "doc.text.fill", label: "Exam Prep", subtitle: "Prepare for a certification or exam"),
            TypeOption(type: .upskilling, icon: "arrow.up.circle.fill", label: "Upskilling", subtitle: "Level up a specific skill"),
            TypeOption(type: .interviewPreparation, icon: "person.crop.rectangle.fill", label: "Interview Prep", subtitle: "Prepare for job interviews"),
            TypeOption(type: .careerSwitch, icon: "arrow.triangle.swap", label: "Career Switch", subtitle: "Transition to a new domain"),
            TypeOption(type: .academicExcellence, icon: "graduationcap.fill", label: "Academic", subtitle: "Excel in academic subjects"),
            TypeOption(type: .casualLearning, icon: "book.fill", label: "Casual Learning", subtitle: "Learn at your own pace"),
            TypeOption(type: .networking, icon: "person.3.fill", label: "Networking", subtitle: "Build professional connections"),
        ]
    }

    private struct TimelineOption {
        let timeline: Timeline
        let label: String
    }

    private var timelineOptions: [TimelineOption] {
        [
            TimelineOption(timeline: .oneMonth, label: "1 mo"),
            TimelineOption(timeline: .threeMonths, label: "3 mo"),
            TimelineOption(timeline: .sixMonths, label: "6 mo"),
            TimelineOption(timeline: .oneYear, label: "1 yr"),
            TimelineOption(timeline: .noDeadline, label: "Open"),
        ]
    }
}
