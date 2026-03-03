import SwiftUI

struct AddObjectiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    // Step 0: Type
    @State private var objectiveType = ""

    // Step 1: Specifics (varies by type)
    @State private var targetRole = ""
    @State private var targetSkill = ""
    @State private var examName = ""
    @State private var targetCompany = ""
    @State private var fromDomain = ""
    @State private var toDomain = ""

    // Step 2: Details
    @State private var timeline = "3_months"
    @State private var currentLevel = "intermediate"
    @State private var weeklyHours = 10
    @State private var learningStyle = "mix"

    // Step 3: Topics
    @State private var topicInput = ""
    @State private var topics: [String] = []

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let objectiveService = ObjectiveService()
    var onCreated: (UserObjective) -> Void

    private let objectiveTypes: [(id: String, label: String, icon: String)] = [
        ("exam_preparation", "Exam Preparation", "doc.text.fill"),
        ("upskilling", "Upskilling", "arrow.up.circle.fill"),
        ("interview_preparation", "Interview Prep", "person.fill.questionmark"),
        ("career_switch", "Career Switch", "arrow.triangle.swap"),
        ("academic_excellence", "Academic Excellence", "graduationcap.fill"),
        ("casual_learning", "Casual Learning", "book.fill"),
        ("networking", "Networking", "person.3.fill"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress
                    progressBar

                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            switch currentStep {
                            case 0: typeStep
                            case 1: specificsStep
                            case 2: detailsStep
                            case 3: topicsStep
                            default: EmptyView()
                            }
                        }
                        .padding(Spacing.md)
                    }

                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("New Objective")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? ColorTokens.gold : ColorTokens.surfaceElevated)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Step 0: Type Selection

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What's your goal?")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Choose the type of objective you want to pursue")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

            ForEach(objectiveTypes, id: \.id) { type in
                Button {
                    Haptics.selection()
                    objectiveType = type.id
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: type.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(objectiveType == type.id ? ColorTokens.gold : ColorTokens.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(objectiveType == type.id ? ColorTokens.gold.opacity(0.15) : ColorTokens.surfaceElevated)
                            .clipShape(Circle())

                        Text(type.label)
                            .font(Typography.body)
                            .foregroundStyle(objectiveType == type.id ? ColorTokens.textPrimary : ColorTokens.textSecondary)

                        Spacer()

                        if objectiveType == type.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                    .padding(Spacing.md)
                    .background(objectiveType == type.id ? ColorTokens.gold.opacity(0.08) : ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(objectiveType == type.id ? ColorTokens.gold.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 1: Specifics

    private var specificsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Tell us more")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            switch objectiveType {
            case "exam_preparation":
                styledField("Exam Name", placeholder: "e.g. AWS Solutions Architect", text: $examName)
            case "upskilling":
                styledField("Target Skill", placeholder: "e.g. System Design", text: $targetSkill)
            case "interview_preparation":
                styledField("Target Role", placeholder: "e.g. Senior Engineer", text: $targetRole)
                styledField("Target Company (optional)", placeholder: "e.g. Google", text: $targetCompany)
            case "career_switch":
                styledField("From Domain", placeholder: "e.g. Frontend", text: $fromDomain)
                styledField("To Domain", placeholder: "e.g. Backend", text: $toDomain)
            case "academic_excellence":
                styledField("Subject / Course", placeholder: "e.g. Data Structures", text: $targetSkill)
            case "casual_learning":
                styledField("What do you want to learn?", placeholder: "e.g. Machine Learning", text: $targetSkill)
            case "networking":
                styledField("Domain of Interest", placeholder: "e.g. Product Management", text: $targetSkill)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Learning preferences")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            // Timeline
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Timeline")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                chipSelector(
                    options: [("1_month", "1 Month"), ("3_months", "3 Months"), ("6_months", "6 Months"), ("1_year", "1 Year"), ("no_deadline", "No Deadline")],
                    selection: $timeline
                )
            }

            // Level
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Current Level")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                chipSelector(
                    options: [("beginner", "Beginner"), ("intermediate", "Intermediate"), ("advanced", "Advanced")],
                    selection: $currentLevel
                )
            }

            // Weekly hours
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Weekly Commitment")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.md) {
                    Button {
                        if weeklyHours > 1 { weeklyHours -= 1; Haptics.light() }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Text("\(weeklyHours) hrs/week")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 120)

                    Button {
                        if weeklyHours < 40 { weeklyHours += 1; Haptics.light() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Learning style
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Preferred Learning Style")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                chipSelector(
                    options: [("videos", "Videos"), ("articles", "Articles"), ("interactive", "Interactive"), ("mix", "Mix")],
                    selection: $learningStyle
                )
            }
        }
    }

    // MARK: - Step 3: Topics

    private var topicsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Topics of Interest")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Add topics you'd like to focus on")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)

            HStack(spacing: Spacing.sm) {
                TextField("Add a topic", text: $topicInput)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(Spacing.sm)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
                    .onSubmit { addTopic() }

                Button { addTopic() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.gold)
                }
                .disabled(topicInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !topics.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(topics, id: \.self) { topic in
                        HStack(spacing: 4) {
                            Text(topic)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.gold)
                            Button {
                                topics.removeAll { $0 == topic }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: Spacing.md) {
            if currentStep > 0 {
                Button {
                    Haptics.selection()
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).stroke(ColorTokens.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.medium()
                if currentStep < 3 {
                    withAnimation { currentStep += 1 }
                } else {
                    Task { await createObjective() }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isSaving {
                        ProgressView().tint(.black).scaleEffect(0.8)
                    }
                    Text(currentStep < 3 ? "Next" : "Create Objective")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canProceed ? ColorTokens.gold : ColorTokens.gold.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)
            .disabled(!canProceed || isSaving)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
    }

    // MARK: - Helpers

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !objectiveType.isEmpty
        case 1: return hasValidSpecifics
        case 2: return true
        case 3: return !topics.isEmpty
        default: return false
        }
    }

    private var hasValidSpecifics: Bool {
        switch objectiveType {
        case "exam_preparation": return !examName.trimmingCharacters(in: .whitespaces).isEmpty
        case "upskilling", "academic_excellence", "casual_learning", "networking":
            return !targetSkill.trimmingCharacters(in: .whitespaces).isEmpty
        case "interview_preparation": return !targetRole.trimmingCharacters(in: .whitespaces).isEmpty
        case "career_switch":
            return !fromDomain.trimmingCharacters(in: .whitespaces).isEmpty && !toDomain.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func addTopic() {
        let trimmed = topicInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
        topicInput = ""
        Haptics.light()
    }

    private func createObjective() async {
        isSaving = true
        errorMessage = nil

        var specifics: ObjectiveSpecificsInput?
        switch objectiveType {
        case "exam_preparation":
            specifics = ObjectiveSpecificsInput(examName: examName)
        case "upskilling", "academic_excellence", "casual_learning", "networking":
            specifics = ObjectiveSpecificsInput(targetSkill: targetSkill)
        case "interview_preparation":
            specifics = ObjectiveSpecificsInput(targetRole: targetRole, targetCompany: targetCompany.isEmpty ? nil : targetCompany)
        case "career_switch":
            specifics = ObjectiveSpecificsInput(fromDomain: fromDomain, toDomain: toDomain)
        default: break
        }

        let body = CreateObjectiveRequest(
            objectiveType: objectiveType,
            specifics: specifics,
            timeline: timeline,
            currentLevel: currentLevel,
            weeklyCommitHours: weeklyHours,
            preferredLearningStyle: learningStyle,
            topicsOfInterest: topics
        )

        do {
            let newObj = try await objectiveService.create(body: body)
            Haptics.success()
            isSaving = false
            onCreated(newObj)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
            isSaving = false
        } catch {
            errorMessage = "Failed to create objective"
            Haptics.error()
            isSaving = false
        }
    }

    private func styledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
            TextField(placeholder, text: text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(Spacing.sm)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.small).stroke(ColorTokens.border, lineWidth: 1))
        }
    }

    private func chipSelector(options: [(id: String, label: String)], selection: Binding<String>) -> some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(options, id: \.id) { option in
                Button {
                    Haptics.selection()
                    selection.wrappedValue = option.id
                } label: {
                    Text(option.label)
                        .font(Typography.bodySmall)
                        .foregroundStyle(selection.wrappedValue == option.id ? .black : ColorTokens.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(selection.wrappedValue == option.id ? ColorTokens.gold : ColorTokens.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
