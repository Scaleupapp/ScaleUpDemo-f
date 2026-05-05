import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentStep: Int
    var isLoading = false
    var errorMessage: String?
    var isMovingForward = true

    // MARK: - Step 1: Profile

    var firstName = ""
    var lastName = ""

    // MARK: - Step 2: Background

    var educationEntries: [EducationEntry] = []
    var workEntries: [WorkEntry] = []

    // MARK: - Step 3: Objective

    var selectedObjective: ObjectiveType?
    var examName = ""
    var targetSkill = ""
    var targetRole = ""
    var targetCompany = ""
    var fromDomain = ""
    var toDomain = ""
    var timeline: Timeline = .threeMonths
    var currentLevel: CurrentLevel = .beginner
    var weeklyHours: Double = 10

    // MARK: - Step 4: Preferences

    var learningStyle: LearningStyle = .mix

    // MARK: - Step 5: Interests

    /// Topics fetched from BE taxonomy. Pre-selected by default.
    var suggestedTopics: [SuggestedTopic] = []
    /// Topics the user added manually (capped so total ≤ 8).
    var customTopics: [SuggestedTopic] = []
    /// Canonical names of topics currently selected. Mirrors prior `selectedTopics` semantics.
    var selectedCanonicals: Set<String> = []
    /// Current draft for "+ Add a topic".
    var customTopic: String = ""
    /// Loading state for taxonomy fetch.
    var isLoadingTopics = false
    /// Per-topic self-rating; key is canonicalName.
    var topicSelfRatings: [String: ProficiencyLevel] = [:]
    /// Within Step 5, are we on the rating sub-step?
    var isOnRatingSubStep = false
    /// Optional syllabus ID returned by upload flow.
    var syllabusId: String?
    /// Topic descriptions extracted from a syllabus upload (replace taxonomy when present).
    var syllabusExtractedTopics: [SuggestedTopic] = []
    /// Whether to gate Step 5 on the syllabus upload card before topic selection.
    var showSyllabusUpload: Bool = false
    /// File extension (lowercased) of the uploaded syllabus, captured for analytics.
    var syllabusFileTypeForAnalytics: String?

    // MARK: - Dependencies

    private let service: OnboardingService
    private let topicServiceFactory: (String?) -> OnboardingTopicService
    private weak var appState: AppState?

    // MARK: - Init

    init(
        initialStep: Int,
        appState: AppState,
        service: OnboardingService = OnboardingService(),
        topicServiceFactory: ((String?) -> OnboardingTopicService)? = nil
    ) {
        self.currentStep = initialStep
        self.appState = appState
        self.service = service
        self.topicServiceFactory = topicServiceFactory ?? { token in
            OnboardingTopicService(authToken: { token })
        }

        // Pre-fill from user data
        if let user = appState.currentUser {
            self.firstName = user.firstName
            self.lastName = user.lastName ?? ""
        }
    }

    /// Builds an `OnboardingTopicService` with the current keychain access token
    /// captured in its `authToken` closure. The token is read on the calling actor
    /// so the service stays MainActor-safe and synchronous.
    private func makeTopicService() async -> OnboardingTopicService {
        let token = await KeychainManager.shared.accessToken
        return topicServiceFactory(token)
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case 1: return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true // optional
        case 3: return selectedObjective != nil
        case 4: return true // always has default
        case 5:
            return isOnRatingSubStep ? canFinishStep5 : canProceedFromTopicSelection
        default: return true
        }
    }

    var isOptionalStep: Bool {
        [1, 2, 4].contains(currentStep)
    }

    // MARK: - Step 5 helpers

    /// Evaluates whether the syllabus upload card should be shown before topic
    /// selection. Called by `InterestsStepView.task` on entry to Step 5.
    func evaluateSyllabusGate() {
        guard let obj = selectedObjective else { return }
        showSyllabusUpload = obj.shouldOfferSyllabusUpload(examName: examName.isEmpty ? nil : examName)
    }

    func loadSuggestedTopics() async {
        guard let objective = selectedObjective else { return }
        isLoadingTopics = true
        errorMessage = nil
        let specifics = currentSpecificsDictionary()
        do {
            let service = await makeTopicService()
            let response = try await service.fetchSuggestedTopics(
                objectiveType: objective,
                specifics: specifics,
                company: targetCompany.isEmpty ? nil : targetCompany
            )
            self.suggestedTopics = response.topics
            // Pre-select all suggested topics.
            for t in response.topics { selectedCanonicals.insert(t.canonicalName) }
            AnalyticsService.shared.track(.onboardingTopicTaxonomyLoaded(
                cacheHit: response.cacheHit,
                source: response.source,
                topicCount: response.topics.count
            ))
        } catch {
            errorMessage = (error as? OnboardingTopicError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingTopics = false
    }

    func toggleTopic(_ topic: SuggestedTopic) {
        if selectedCanonicals.contains(topic.canonicalName) {
            selectedCanonicals.remove(topic.canonicalName)
            topicSelfRatings.removeValue(forKey: topic.canonicalName)
            let topicSource = customTopics.contains(where: { $0.canonicalName == topic.canonicalName }) ? "custom" : "taxonomy"
            AnalyticsService.shared.track(.onboardingTopicRemoved(
                canonicalName: topic.canonicalName,
                source: topicSource
            ))
        } else if totalSelectedCount < 8 {
            selectedCanonicals.insert(topic.canonicalName)
        }
        Haptics.selection()
    }

    func addCustomTopic() {
        let trimmed = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, totalSelectedCount < 8 else { return }
        let canonical = trimmed.lowercased().replacingOccurrences(of: " ", with: "-")
        let topic = SuggestedTopic(
            canonicalName: canonical,
            name: trimmed,
            description: "Custom topic you added.",
            isFutureProofing: false,
            baseDifficulty: "intermediate"
        )
        customTopics.append(topic)
        selectedCanonicals.insert(canonical)
        customTopic = ""
        AnalyticsService.shared.track(.onboardingTopicAddedCustom(canonicalName: canonical))
    }

    func setRating(_ rating: ProficiencyLevel, for topic: SuggestedTopic) {
        topicSelfRatings[topic.canonicalName] = rating
    }

    var totalSelectedCount: Int { selectedCanonicals.count }

    var allDisplayableTopics: [SuggestedTopic] {
        let pool = syllabusExtractedTopics.isEmpty ? suggestedTopics : syllabusExtractedTopics
        let extras = customTopics
        var seen = Set<String>()
        return (pool + extras).filter { seen.insert($0.canonicalName).inserted }
    }

    var canProceedFromTopicSelection: Bool {
        totalSelectedCount >= 3 && totalSelectedCount <= 8
    }

    var canFinishStep5: Bool {
        canProceedFromTopicSelection &&
        selectedCanonicals.allSatisfy { topicSelfRatings[$0] != nil }
    }

    private func currentSpecificsDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if !examName.isEmpty       { dict["examName"]       = examName }
        if !targetSkill.isEmpty    { dict["targetSkill"]    = targetSkill }
        if !targetRole.isEmpty     { dict["targetRole"]     = targetRole }
        if !targetCompany.isEmpty  { dict["targetCompany"]  = targetCompany }
        if !fromDomain.isEmpty     { dict["fromDomain"]     = fromDomain }
        if !toDomain.isEmpty       { dict["toDomain"]       = toDomain }
        return dict
    }

    // MARK: - Navigation Actions

    func next() async {
        guard canProceed else { return }

        isLoading = true
        errorMessage = nil

        // Save current step (tolerate failure — still navigate)
        do {
            try await saveCurrentStep()
        } catch {
            // Don't block navigation on API failure
            print("Onboarding step \(currentStep) save failed: \(error)")
        }

        isLoading = false
        isMovingForward = true

        if currentStep < 6 {
            currentStep += 1
        }
    }

    func skip() async {
        isMovingForward = true
        if currentStep < 6 {
            currentStep += 1
        }
    }

    func back() {
        if currentStep > 1 {
            isMovingForward = false
            currentStep -= 1
        }
    }

    func completeOnboarding() async {
        await submitOnboarding()
    }

    // MARK: - Add/Remove Education & Work

    func addEducation() {
        educationEntries.append(EducationEntry())
    }

    func removeEducation(_ entry: EducationEntry) {
        educationEntries.removeAll { $0.id == entry.id }
    }

    func addWork() {
        workEntries.append(WorkEntry())
    }

    func removeWork(_ entry: WorkEntry) {
        workEntries.removeAll { $0.id == entry.id }
    }

    // MARK: - Save Steps

    private func saveCurrentStep() async throws {
        switch currentStep {
        case 1:
            try await service.updateProfile(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lastName.trimmingCharacters(in: .whitespaces)
            )
        case 2:
            let education = educationEntries
                .filter { !$0.degree.isEmpty && !$0.institution.isEmpty }
                .map { Education(degree: $0.degree, institution: $0.institution, yearOfCompletion: $0.yearOfCompletion, currentlyPursuing: $0.currentlyPursuing) }
            let work = workEntries
                .filter { !$0.role.isEmpty && !$0.company.isEmpty }
                .map { WorkExperience(role: $0.role, company: $0.company, years: $0.years, currentlyWorking: $0.currentlyWorking) }
            try await service.updateBackground(education: education, workExperience: work)
        case 3:
            guard let objective = selectedObjective else { return }
            var specifics: ObjectiveSpecifics?
            if objective.requiresSpecifics {
                specifics = ObjectiveSpecifics(
                    examName: objective == .examPreparation ? examName.nilIfEmpty : nil,
                    targetSkill: objective == .upskilling ? targetSkill.nilIfEmpty : nil,
                    targetRole: objective == .interviewPreparation ? targetRole.nilIfEmpty : nil,
                    targetCompany: objective == .interviewPreparation ? targetCompany.nilIfEmpty : nil,
                    fromDomain: objective == .careerSwitch ? fromDomain.nilIfEmpty : nil,
                    toDomain: objective == .careerSwitch ? toDomain.nilIfEmpty : nil
                )
            }
            try await service.setObjective(
                type: objective,
                specifics: specifics,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: Int(weeklyHours)
            )
            AnalyticsService.shared.track(.onboardingObjectiveSelected(objective: String(describing: objective)))
            var userProps = AnalyticsUserProperties()
            userProps.objective = String(describing: objective)
            userProps.currentLevel = String(describing: currentLevel)
            userProps.targetExam = objective == .examPreparation ? examName.nilIfEmpty : nil
            userProps.targetRole = objective == .interviewPreparation ? targetRole.nilIfEmpty : nil
            userProps.targetCompany = objective == .interviewPreparation ? targetCompany.nilIfEmpty : nil
            userProps.weeklyCommitHours = Int(weeklyHours)
            AnalyticsService.shared.setUserProperties(userProps)
        case 4:
            try await service.updatePreferences(
                style: learningStyle,
                weeklyCommitHours: Int(weeklyHours)
            )
        case 5:
            // Step 5 finalization is handled in `submitOnboarding` (called by Completion step)
            // since the new flow posts a single consolidated payload to /onboarding/complete.
            break
        default:
            break
        }
    }

    // MARK: - Submit Onboarding

    func submitOnboarding() async {
        isLoading = true
        defer { isLoading = false }

        let topicsPayload: [OnboardingCompletePayload.TopicSelectionPayload] = allDisplayableTopics
            .filter { selectedCanonicals.contains($0.canonicalName) }
            .map { topic in
                let isCustom = customTopics.contains { $0.canonicalName == topic.canonicalName }
                return .init(
                    canonicalName: topic.canonicalName,
                    name: topic.name,
                    source: isCustom ? TopicSource.custom.rawValue : TopicSource.taxonomy.rawValue,
                    isFutureProofing: topic.isFutureProofing
                )
            }

        let ratings = topicSelfRatings.mapValues { $0.rawValue }

        let educationPayload = educationEntries
            .filter { !$0.degree.isEmpty && !$0.institution.isEmpty }
            .map { OnboardingCompletePayload.EducationPayload(degree: $0.degree, institution: $0.institution, yearOfCompletion: $0.yearOfCompletion, currentlyPursuing: $0.currentlyPursuing) }
        let workPayload = workEntries
            .filter { !$0.role.isEmpty && !$0.company.isEmpty }
            .map { OnboardingCompletePayload.WorkPayload(role: $0.role, company: $0.company, years: $0.years, currentlyWorking: $0.currentlyWorking) }

        let payload = OnboardingCompletePayload(
            firstName: firstName,
            lastName: lastName,
            educationEntries: educationPayload,
            workEntries: workPayload,
            objectiveType: selectedObjective?.rawValue ?? ObjectiveType.upskilling.rawValue,
            specifics: currentSpecificsDictionary(),
            timeline: timeline.rawValue,
            currentLevel: currentLevel.rawValue,
            weeklyHours: weeklyHours,
            learningStyle: learningStyle.rawValue,
            topicsOfInterest: topicsPayload,
            topicSelfRatings: ratings,
            syllabusId: syllabusId
        )

        do {
            let service = await makeTopicService()
            _ = try await service.submitOnboarding(payload)
            AnalyticsService.shared.track(.onboardingSelfRatingCompleted(
                topicCount: ratings.count,
                ratingDistribution: ratingDistribution(from: ratings)
            ))
            AnalyticsService.shared.track(.onboardingCompleted)
            appState?.completeOnboarding()
        } catch {
            errorMessage = (error as? OnboardingTopicError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func ratingDistribution(from ratings: [String: String]) -> [String: Int] {
        var counts: [String: Int] = ["novice": 0, "familiar": 0, "proficient": 0, "expert": 0]
        for value in ratings.values { counts[value, default: 0] += 1 }
        return counts
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
