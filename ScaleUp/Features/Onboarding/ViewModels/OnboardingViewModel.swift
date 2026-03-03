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

    var selectedTopics: Set<String> = []
    var customTopic = ""

    // MARK: - Dependencies

    private let service = OnboardingService()
    private weak var appState: AppState?

    // MARK: - Init

    init(initialStep: Int, appState: AppState) {
        self.currentStep = initialStep
        self.appState = appState

        // Pre-fill from user data
        if let user = appState.currentUser {
            self.firstName = user.firstName
            self.lastName = user.lastName ?? ""
        }
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case 1: return !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true // optional
        case 3: return selectedObjective != nil
        case 4: return true // always has default
        case 5: return selectedTopics.count >= 3
        default: return true
        }
    }

    var isOptionalStep: Bool {
        [1, 2, 4].contains(currentStep)
    }

    // MARK: - Topic Suggestions

    var suggestedTopics: [String] {
        guard let objective = selectedObjective else {
            return Self.generalTopics
        }

        switch objective {
        case .examPreparation:
            return ["Test Strategy", "Time Management", "Practice Tests", "Study Planning",
                    "Note Taking", "Memory Techniques", "Revision", "Problem Solving",
                    "Critical Thinking", "Exam Anxiety"]
        case .upskilling:
            return topicsForSkill(targetSkill)
        case .interviewPreparation:
            return ["System Design", "Behavioral Questions", "Technical Skills",
                    "Communication", "Problem Solving", "Case Studies",
                    "Salary Negotiation", "Company Research", "Mock Interviews", "Resume Building"]
        case .careerSwitch:
            return ["Industry Overview", "Transferable Skills", "Networking",
                    "Portfolio Building", "Certifications", "Mentorship",
                    "Job Market", "Personal Branding", "Skill Gap Analysis", "Bootcamps"]
        case .academicExcellence:
            return ["Research Methods", "Academic Writing", "Data Analysis",
                    "Critical Thinking", "Presentations", "Literature Review",
                    "Study Techniques", "Time Management", "Collaboration", "Note Taking"]
        case .casualLearning:
            return Self.generalTopics
        case .networking:
            return ["Personal Branding", "LinkedIn", "Public Speaking", "Community Building",
                    "Mentorship", "Industry Events", "Content Creation", "Collaboration",
                    "Relationship Building", "Thought Leadership"]
        }
    }

    private func topicsForSkill(_ skill: String) -> [String] {
        let lower = skill.lowercased()
        if lower.contains("product") {
            return ["Product Strategy", "User Research", "Metrics & Analytics",
                    "Roadmapping", "Prioritization", "Agile", "Stakeholder Management",
                    "A/B Testing", "Go-to-Market", "User Stories"]
        } else if lower.contains("data") {
            return ["Python", "SQL", "Machine Learning", "Statistics",
                    "Data Visualization", "Pandas", "Deep Learning",
                    "ETL Pipelines", "A/B Testing", "Big Data"]
        } else if lower.contains("design") {
            return ["UI Design", "UX Research", "Figma", "Prototyping",
                    "Design Systems", "Typography", "Color Theory",
                    "User Testing", "Accessibility", "Interaction Design"]
        } else if lower.contains("market") {
            return ["Digital Marketing", "SEO", "Content Strategy", "Social Media",
                    "Analytics", "Email Marketing", "Branding",
                    "Growth Hacking", "Copywriting", "Paid Ads"]
        } else {
            return Self.generalTopics
        }
    }

    private static let generalTopics = [
        "Technology", "Business", "Design", "Marketing",
        "Finance", "Data Science", "Leadership", "Communication",
        "Productivity", "Health & Wellness", "Creative Writing", "Programming"
    ]

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
        isLoading = true
        try? await service.complete()
        isLoading = false
        appState?.completeOnboarding()
    }

    // MARK: - Add Custom Topic

    func addCustomTopic() {
        let topic = customTopic.trimmingCharacters(in: .whitespaces)
        guard !topic.isEmpty else { return }
        selectedTopics.insert(topic)
        customTopic = ""
    }

    func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
        Haptics.selection()
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
        case 4:
            try await service.updatePreferences(
                style: learningStyle,
                weeklyCommitHours: Int(weeklyHours)
            )
        case 5:
            let topics = Array(selectedTopics)
            try await service.updateInterests(skills: topics, topicsOfInterest: topics)
        default:
            break
        }
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
