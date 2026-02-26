import SwiftUI

// MARK: - Education Entry (Mutable)

struct EducationEntry: Identifiable {
    let id = UUID()
    var degree: String = ""
    var institution: String = ""
    var yearOfCompletion: Int = Calendar.current.component(.year, from: Date())
    var currentlyPursuing: Bool = false

    var isValid: Bool {
        !degree.trimmingCharacters(in: .whitespaces).isEmpty &&
        !institution.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func toModel() -> Education {
        Education(
            degree: degree.trimmingCharacters(in: .whitespaces),
            institution: institution.trimmingCharacters(in: .whitespaces),
            yearOfCompletion: currentlyPursuing ? nil : yearOfCompletion,
            currentlyPursuing: currentlyPursuing
        )
    }
}

// MARK: - Work Experience Entry (Mutable)

struct WorkExperienceEntry: Identifiable {
    let id = UUID()
    var role: String = ""
    var company: String = ""
    var years: Int = 1
    var currentlyWorking: Bool = false

    var isValid: Bool {
        !role.trimmingCharacters(in: .whitespaces).isEmpty &&
        !company.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func toModel() -> WorkExperience {
        WorkExperience(
            role: role.trimmingCharacters(in: .whitespaces),
            company: company.trimmingCharacters(in: .whitespaces),
            years: years,
            currentlyWorking: currentlyWorking
        )
    }
}

// MARK: - Onboarding ViewModel

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Navigation State

    var currentStep: Int = 1
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Step 1: Profile

    var firstName: String = ""
    var lastName: String = ""

    // MARK: - Step 2: Background

    var educationEntries: [EducationEntry] = [EducationEntry()]
    var workExperienceEntries: [WorkExperienceEntry] = [WorkExperienceEntry()]

    // MARK: - Step 3: Objective

    var selectedObjectiveType: ObjectiveType?
    var objectiveSubPage: Int = 1

    // Specifics per objective type
    var examName: String = ""
    var targetSkill: String = ""
    var targetRole: String = ""
    var targetCompany: String = ""
    var fromDomain: String = ""
    var toDomain: String = ""

    var selectedTimeline: Timeline?
    var currentLevel: Difficulty = .beginner
    var weeklyCommitHours: Double = 10

    // MARK: - Step 4: Preferences

    var selectedLearningStyle: LearningStyle?

    // MARK: - Step 5: Interests

    var selectedSkills: [String] = []
    var selectedTopics: [String] = []

    // MARK: - Step 6: Complete

    var showCompletionAnimation: Bool = false

    // MARK: - Computed: Specifics String

    var specificsString: String {
        guard let objective = selectedObjectiveType else { return "" }
        switch objective {
        case .examPreparation:
            return examName
        case .upskilling:
            return targetSkill
        case .interviewPreparation:
            return [targetRole, targetCompany].filter { !$0.isEmpty }.joined(separator: " at ")
        case .careerSwitch:
            return [fromDomain, toDomain].filter { !$0.isEmpty }.joined(separator: " to ")
        case .academicExcellence:
            return targetSkill
        case .casualLearning:
            return targetSkill
        case .networking:
            return targetSkill
        }
    }

    // MARK: - Computed: Objective Summary

    var objectiveSummary: String {
        guard let objective = selectedObjectiveType else { return "" }
        switch objective {
        case .examPreparation:
            return "Preparing for \(examName.isEmpty ? "an exam" : examName)"
        case .upskilling:
            return "Upskilling in \(targetSkill.isEmpty ? "a new area" : targetSkill)"
        case .interviewPreparation:
            let rolePart = targetRole.isEmpty ? "a role" : targetRole
            let companyPart = targetCompany.isEmpty ? "" : " at \(targetCompany)"
            return "Preparing for \(rolePart)\(companyPart) interviews"
        case .careerSwitch:
            let from = fromDomain.isEmpty ? "current field" : fromDomain
            let to = toDomain.isEmpty ? "new field" : toDomain
            return "Switching from \(from) to \(to)"
        case .academicExcellence:
            return "Excelling in \(targetSkill.isEmpty ? "academics" : targetSkill)"
        case .casualLearning:
            return "Learning \(targetSkill.isEmpty ? "something new" : targetSkill)"
        case .networking:
            return "Building professional network in \(targetSkill.isEmpty ? "your field" : targetSkill)"
        }
    }

    // MARK: - Computed: Can Advance

    var canAdvance: Bool {
        switch currentStep {
        case 1:
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2:
            // Background is optional (skippable)
            return true
        case 3:
            return canAdvanceObjectiveStep
        case 4:
            // Preferences are optional (skippable)
            return true
        case 5:
            return (selectedSkills.count + selectedTopics.count) >= 3
        case 6:
            return true
        default:
            return false
        }
    }

    /// Objective step has internal sub-pages
    private var canAdvanceObjectiveStep: Bool {
        switch objectiveSubPage {
        case 1:
            return selectedObjectiveType != nil
        case 2:
            return !specificsString.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:
            return selectedTimeline != nil
        default:
            return false
        }
    }

    // MARK: - Step Title

    var stepTitle: String {
        switch currentStep {
        case 1: return "Set Up Your Profile"
        case 2: return "Your Background"
        case 3:
            switch objectiveSubPage {
            case 1: return "What's Your Goal?"
            case 2: return "Tell Us More"
            case 3: return "Your Timeline"
            default: return "Your Objective"
            }
        case 4: return "How Do You Learn Best?"
        case 5: return "Your Interests"
        case 6: return "You're All Set!"
        default: return ""
        }
    }

    var stepSubtitle: String {
        switch currentStep {
        case 1: return "Let's get to know you"
        case 2: return "Help us personalize your experience"
        case 3:
            switch objectiveSubPage {
            case 1: return "Choose your primary learning objective"
            case 2: return "Give us the specifics so we can tailor your path"
            case 3: return "Set your pace and timeline"
            default: return ""
            }
        case 4: return "We'll customize content to match your style"
        case 5: return "Select at least 3 topics you're interested in"
        case 6: return "Your personalized learning path is ready"
        default: return ""
        }
    }

    // MARK: - Can Skip

    var canSkip: Bool {
        switch currentStep {
        case 2, 4, 5: return true
        default: return false
        }
    }

    // MARK: - Progress

    var progress: Double {
        if currentStep == 3 {
            let subProgress = Double(objectiveSubPage - 1) / 3.0
            return (Double(currentStep - 1) + subProgress) / 6.0
        }
        return Double(currentStep - 1) / 6.0
    }

    // MARK: - Continue Button Title

    var continueButtonTitle: String {
        switch currentStep {
        case 6: return "Start Learning"
        default: return "Continue"
        }
    }

    // MARK: - Pre-populate from User

    func prepopulate(from user: User?) {
        guard let user else { return }
        if !user.firstName.isEmpty { firstName = user.firstName }
        if !user.lastName.isEmpty { lastName = user.lastName }

        if !user.education.isEmpty {
            educationEntries = user.education.map { edu in
                var entry = EducationEntry()
                entry.degree = edu.degree
                entry.institution = edu.institution
                entry.yearOfCompletion = edu.yearOfCompletion ?? Calendar.current.component(.year, from: Date())
                entry.currentlyPursuing = edu.currentlyPursuing
                return entry
            }
        }

        if !user.workExperience.isEmpty {
            workExperienceEntries = user.workExperience.map { exp in
                var entry = WorkExperienceEntry()
                entry.role = exp.role
                entry.company = exp.company
                entry.years = exp.years ?? 1
                entry.currentlyWorking = exp.currentlyWorking
                return entry
            }
        }

        if !user.skills.isEmpty {
            selectedSkills = user.skills
        }

        // Resume from last step
        if user.onboardingStep > 1 {
            currentStep = user.onboardingStep
        }
    }

    // MARK: - Next Step

    func nextStep(
        onboardingService: OnboardingService,
        authManager: AuthManager,
        appState: AppState
    ) async {
        guard canAdvance else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch currentStep {
            case 1:
                try await onboardingService.updateProfile(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
                withAnimation(Animations.standard) {
                    currentStep = 2
                }

            case 2:
                let validEducation = educationEntries.filter { $0.isValid }.map { $0.toModel() }
                let validExperience = workExperienceEntries.filter { $0.isValid }.map { $0.toModel() }
                try await onboardingService.updateBackground(
                    education: validEducation,
                    workExperience: validExperience
                )
                withAnimation(Animations.standard) {
                    currentStep = 3
                    objectiveSubPage = 1
                }

            case 3:
                try await advanceObjectiveSubPage(onboardingService: onboardingService)

            case 4:
                if let style = selectedLearningStyle {
                    try await onboardingService.updatePreferences(
                        preferredLearningStyle: style,
                        weeklyCommitHours: weeklyCommitHours
                    )
                }
                withAnimation(Animations.standard) {
                    currentStep = 5
                }

            case 5:
                let allTopics = Array(Set(selectedSkills + selectedTopics))
                try await onboardingService.updateInterests(
                    skills: selectedSkills,
                    topicsOfInterest: allTopics
                )
                withAnimation(Animations.standard) {
                    currentStep = 6
                }
                // Trigger completion animation after transition
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(Animations.spring) {
                    showCompletionAnimation = true
                }

            case 6:
                try await onboardingService.complete()
                appState.authStatus = .authenticated

            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Skip Step

    func skipStep(
        onboardingService: OnboardingService,
        authManager: AuthManager,
        appState: AppState
    ) async {
        guard canSkip else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch currentStep {
            case 2:
                // Submit empty background
                try await onboardingService.updateBackground(education: [], workExperience: [])
                withAnimation(Animations.standard) {
                    currentStep = 3
                    objectiveSubPage = 1
                }
            case 4:
                // Submit default preference
                try await onboardingService.updatePreferences(
                    preferredLearningStyle: .mix,
                    weeklyCommitHours: weeklyCommitHours
                )
                withAnimation(Animations.standard) {
                    currentStep = 5
                }
            case 5:
                try await onboardingService.updateInterests(skills: [], topicsOfInterest: [])
                withAnimation(Animations.standard) {
                    currentStep = 6
                }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(Animations.spring) {
                    showCompletionAnimation = true
                }
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Objective Sub-Page Navigation

    private func advanceObjectiveSubPage(onboardingService: OnboardingService) async throws {
        switch objectiveSubPage {
        case 1:
            withAnimation(Animations.standard) {
                objectiveSubPage = 2
            }
        case 2:
            withAnimation(Animations.standard) {
                objectiveSubPage = 3
            }
        case 3:
            guard let objectiveType = selectedObjectiveType,
                  let timeline = selectedTimeline else { return }

            let specifics = buildSpecifics(for: objectiveType)

            try await onboardingService.setObjective(
                objectiveType: objectiveType,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
            withAnimation(Animations.standard) {
                currentStep = 4
            }
        default:
            break
        }
    }

    // MARK: - Build Specifics Object

    private func buildSpecifics(for objectiveType: ObjectiveType) -> OnboardingEndpoints.ObjectiveSpecificsBody? {
        let exam = examName.trimmedOrNil
        let skill = targetSkill.trimmedOrNil
        let role = targetRole.trimmedOrNil
        let company = targetCompany.trimmedOrNil
        let from = fromDomain.trimmedOrNil
        let to = toDomain.trimmedOrNil

        switch objectiveType {
        case .examPreparation:
            guard exam != nil else { return nil }
            return .init(examName: exam, targetSkill: nil, targetRole: nil, targetCompany: nil, fromDomain: nil, toDomain: nil)
        case .upskilling, .academicExcellence, .casualLearning, .networking:
            guard skill != nil else { return nil }
            return .init(examName: nil, targetSkill: skill, targetRole: nil, targetCompany: nil, fromDomain: nil, toDomain: nil)
        case .interviewPreparation:
            guard role != nil || company != nil else { return nil }
            return .init(examName: nil, targetSkill: nil, targetRole: role, targetCompany: company, fromDomain: nil, toDomain: nil)
        case .careerSwitch:
            guard from != nil || to != nil else { return nil }
            return .init(examName: nil, targetSkill: nil, targetRole: nil, targetCompany: nil, fromDomain: from, toDomain: to)
        }
    }

    // MARK: - Go Back (within Objective sub-pages)

    func goBackInObjective() {
        guard currentStep == 3, objectiveSubPage > 1 else { return }
        withAnimation(Animations.standard) {
            objectiveSubPage -= 1
        }
    }

    // MARK: - Education Helpers

    func addEducationEntry() {
        educationEntries.append(EducationEntry())
    }

    func removeEducationEntry(_ entry: EducationEntry) {
        guard educationEntries.count > 1 else { return }
        educationEntries.removeAll { $0.id == entry.id }
    }

    // MARK: - Work Experience Helpers

    func addWorkExperienceEntry() {
        workExperienceEntries.append(WorkExperienceEntry())
    }

    func removeWorkExperienceEntry(_ entry: WorkExperienceEntry) {
        guard workExperienceEntries.count > 1 else { return }
        workExperienceEntries.removeAll { $0.id == entry.id }
    }

    // MARK: - Suggested Topics

    var suggestedTopics: [String] {
        guard let objective = selectedObjectiveType else {
            return defaultTopics
        }

        switch objective {
        case .examPreparation:
            let examLower = examName.lowercased()
            if examLower.contains("sat") {
                return ["SAT Math", "SAT Reading", "SAT Writing", "Algebra", "Geometry",
                        "Data Analysis", "Grammar", "Vocabulary", "Reading Comprehension",
                        "Essay Writing", "Test Strategy", "Time Management"]
            } else if examLower.contains("gre") {
                return ["GRE Verbal", "GRE Quantitative", "GRE Analytical Writing",
                        "Vocabulary Building", "Reading Comprehension", "Algebra",
                        "Data Interpretation", "Critical Reasoning"]
            } else if examLower.contains("gmat") {
                return ["GMAT Verbal", "GMAT Quantitative", "Integrated Reasoning",
                        "Data Sufficiency", "Critical Reasoning", "Sentence Correction"]
            }
            return ["Practice Tests", "Study Planning", "Time Management",
                    "Test-Taking Strategies", "Subject Review", "Problem Solving"]

        case .upskilling:
            let skillLower = targetSkill.lowercased()
            if skillLower.contains("product") {
                return productManagementTopics
            } else if skillLower.contains("data") {
                return ["Data Analysis", "SQL", "Python", "Statistics",
                        "Machine Learning", "Data Visualization", "Excel", "Tableau"]
            } else if skillLower.contains("design") {
                return ["UI Design", "UX Research", "Figma", "Design Systems",
                        "Prototyping", "User Testing", "Visual Design", "Interaction Design"]
            }
            return ["Fundamentals", "Best Practices", "Advanced Techniques",
                    "Case Studies", "Industry Trends", "Hands-on Projects"]

        case .interviewPreparation:
            return ["System Design", "Behavioral Questions", "Technical Interviews",
                    "Data Structures", "Algorithms", "Problem Solving",
                    "Communication Skills", "Case Studies", "Salary Negotiation"]

        case .careerSwitch:
            return ["Career Planning", "Skill Gap Analysis", "Portfolio Building",
                    "Networking", "Resume Building", "Industry Knowledge",
                    "Transferable Skills", "Personal Branding"]

        case .academicExcellence:
            return ["Study Techniques", "Research Methods", "Academic Writing",
                    "Critical Thinking", "Time Management", "Note-Taking",
                    "Exam Preparation", "Presentation Skills"]

        case .casualLearning:
            return defaultTopics

        case .networking:
            return ["Professional Networking", "LinkedIn Optimization", "Personal Branding",
                    "Communication Skills", "Public Speaking", "Elevator Pitch",
                    "Industry Events", "Mentorship"]
        }
    }

    private var productManagementTopics: [String] {
        ["Product Strategy", "Roadmapping", "User Research", "A/B Testing",
         "Agile Methodology", "Stakeholder Management", "Metrics & Analytics",
         "Product Discovery", "Go-to-Market Strategy", "Competitive Analysis",
         "Wireframing", "User Stories"]
    }

    private var defaultTopics: [String] {
        ["Technology", "Business", "Science", "Mathematics", "Design",
         "Programming", "Data Science", "Marketing", "Finance",
         "Communication", "Leadership", "Personal Development"]
    }
}
