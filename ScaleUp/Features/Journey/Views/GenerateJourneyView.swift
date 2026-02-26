import SwiftUI

// MARK: - Generate Journey View

/// Sheet view that allows the user to select an active objective
/// and generate a personalized learning journey from it.
struct GenerateJourneyView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var objectives: [Objective] = []
    @State private var selectedObjectiveId: String?
    @State private var isLoadingObjectives: Bool = false
    @State private var isGenerating: Bool = false
    @State private var error: APIError?

    /// Called when a journey has been successfully generated.
    var onJourneyGenerated: ((Journey) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if isLoadingObjectives {
                    objectivesSkeletonView
                } else if let error, objectives.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await loadObjectives() }
                        }
                    )
                } else if objectives.isEmpty {
                    noObjectivesView
                } else {
                    sheetContent
                }

                // Generation overlay
                if isGenerating {
                    generatingOverlay
                }
            }
            .navigationTitle("Generate Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .disabled(isGenerating)
                }
            }
        }
        .task {
            await loadObjectives()
        }
    }

    // MARK: - Sheet Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {

                    // Instructions
                    instructionsHeader

                    // Objectives list
                    objectivesList

                    // Error message
                    if let error, !objectives.isEmpty {
                        Text(error.localizedDescription)
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.vertical, Spacing.md)
            }

            // Generate button
            generateButton
        }
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.primary)

            Text("Choose an Objective")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Select an objective to create a personalized learning journey tailored to your goals.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Objectives List

    private var objectivesList: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(objectives) { objective in
                objectiveCard(objective)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Objective Card

    @ViewBuilder
    private func objectiveCard(_ objective: Objective) -> some View {
        let isSelected = selectedObjectiveId == objective.id

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedObjectiveId = isSelected ? nil : objective.id
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                // Type icon
                Image(systemName: objectiveTypeIcon(objective.objectiveType))
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? ColorTokens.primary : ColorTokens.textSecondaryDark)
                    .frame(width: 40, height: 40)
                    .background(
                        isSelected
                            ? ColorTokens.primary.opacity(0.12)
                            : ColorTokens.surfaceElevatedDark
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                // Details
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(objectiveTitle(for: objective))
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    HStack(spacing: Spacing.sm) {
                        // Timeline
                        Label {
                            Text(timelineLabel(objective.timeline ?? .noDeadline))
                                .font(Typography.caption)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                        // Level
                        Label {
                            Text((objective.currentLevel ?? .beginner).rawValue.capitalized)
                                .font(Typography.caption)
                        } icon: {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                    }

                    // Objective type label
                    Text(objectiveTypeLabel(objective.objectiveType))
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(ColorTokens.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected ? ColorTokens.primary : ColorTokens.textTertiaryDark
                    )
            }
            .padding(Spacing.md)
            .background(ColorTokens.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isSelected ? ColorTokens.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        PrimaryButton(
            title: "Generate Journey",
            isLoading: isGenerating,
            isDisabled: selectedObjectiveId == nil,
            action: {
                Task { await generateJourney() }
            }
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            ColorTokens.backgroundDark
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
        )
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        ZStack {
            ColorTokens.backgroundDark.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                ProgressView()
                    .controlSize(.large)
                    .tint(ColorTokens.primary)

                VStack(spacing: Spacing.sm) {
                    Text("Creating your personalized journey...")
                        .font(Typography.titleMedium)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .multilineTextAlignment(.center)

                    Text("This may take a moment while we craft the perfect learning path for you.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Spacing.xl)
        }
        .transition(.opacity)
    }

    // MARK: - No Objectives View

    private var noObjectivesView: some View {
        EmptyStateView(
            icon: "target",
            title: "No Objectives Found",
            subtitle: "Create a learning objective first, then come back to generate your journey."
        )
    }

    // MARK: - Skeleton Loading View

    private var objectivesSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Instructions skeleton
                VStack(spacing: Spacing.sm) {
                    SkeletonLoader(width: 40, height: 40, cornerRadius: CornerRadius.small)
                    SkeletonLoader(width: 180, height: 20)
                    SkeletonLoader(width: 260, height: 14)
                }
                .padding(.horizontal, Spacing.lg)

                // Objective card skeletons
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: Spacing.sm) {
                        SkeletonLoader(width: 40, height: 40, cornerRadius: CornerRadius.small)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonLoader(width: 160, height: 16)
                            SkeletonLoader(width: 120, height: 12)
                            SkeletonLoader(width: 80, height: 18, cornerRadius: CornerRadius.full)
                        }
                        Spacer()
                        SkeletonLoader(width: 22, height: 22, cornerRadius: 11)
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadObjectives() async {
        isLoadingObjectives = true
        error = nil

        do {
            let allObjectives = try await dependencies.objectiveService.list()
            objectives = allObjectives.filter { $0.status == .active }
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoadingObjectives = false
    }

    @MainActor
    private func generateJourney() async {
        guard let objectiveId = selectedObjectiveId else { return }
        isGenerating = true
        error = nil

        do {
            let journey = try await dependencies.journeyService.generate(objectiveId: objectiveId)
            onJourneyGenerated?(journey)
            dismiss()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isGenerating = false
    }

    // MARK: - Helpers

    private func objectiveTitle(for objective: Objective) -> String {
        if let exam = objective.specifics?.examName, !exam.isEmpty {
            return exam
        } else if let skill = objective.specifics?.targetSkill, !skill.isEmpty {
            return skill
        } else if let role = objective.specifics?.targetRole, !role.isEmpty {
            return role
        } else if let fromDomain = objective.specifics?.fromDomain,
                  let toDomain = objective.specifics?.toDomain,
                  !fromDomain.isEmpty, !toDomain.isEmpty {
            return "\(fromDomain) → \(toDomain)"
        } else {
            return objectiveTypeLabel(objective.objectiveType)
        }
    }

    private func objectiveTypeIcon(_ type: ObjectiveType) -> String {
        switch type {
        case .examPreparation:
            return "doc.text.fill"
        case .upskilling:
            return "arrow.up.circle.fill"
        case .interviewPreparation:
            return "person.fill.questionmark"
        case .networking:
            return "person.3.fill"
        case .careerSwitch:
            return "arrow.triangle.swap"
        case .academicExcellence:
            return "graduationcap.fill"
        case .casualLearning:
            return "book.fill"
        }
    }

    private func objectiveTypeLabel(_ type: ObjectiveType) -> String {
        switch type {
        case .examPreparation:
            return "Exam Prep"
        case .upskilling:
            return "Upskilling"
        case .interviewPreparation:
            return "Interview Prep"
        case .networking:
            return "Networking"
        case .careerSwitch:
            return "Career Switch"
        case .academicExcellence:
            return "Academic"
        case .casualLearning:
            return "Casual Learning"
        }
    }

    private func timelineLabel(_ timeline: Timeline) -> String {
        switch timeline {
        case .oneMonth:
            return "1 month"
        case .threeMonths:
            return "3 months"
        case .sixMonths:
            return "6 months"
        case .oneYear:
            return "1 year"
        case .noDeadline:
            return "No deadline"
        }
    }
}
