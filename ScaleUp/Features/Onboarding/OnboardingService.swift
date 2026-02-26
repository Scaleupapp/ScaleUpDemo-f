import Foundation

// MARK: - Onboarding Status

struct OnboardingStatus: Decodable {
    let onboardingStep: Int
    let onboardingComplete: Bool
}

// MARK: - Onboarding Service

final class OnboardingService: Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Get Status

    /// Fetches the current onboarding status from the backend.
    func getStatus() async throws -> OnboardingStatus {
        try await apiClient.request(OnboardingEndpoints.getStatus())
    }

    // MARK: - Step 1: Profile

    /// Updates the user's profile information (first name, last name, date of birth, location).
    func updateProfile(
        firstName: String,
        lastName: String,
        dateOfBirth: String? = nil,
        location: String? = nil
    ) async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.updateProfile(
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                location: location
            )
        )
    }

    // MARK: - Step 2: Background

    /// Updates the user's educational and work background.
    func updateBackground(
        education: [Education],
        workExperience: [WorkExperience]
    ) async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.updateBackground(
                education: education,
                workExperience: workExperience
            )
        )
    }

    // MARK: - Step 3: Objective

    /// Sets the user's primary learning objective.
    func setObjective(
        objectiveType: ObjectiveType,
        timeline: Timeline,
        currentLevel: Difficulty,
        weeklyCommitHours: Double,
        specifics: OnboardingEndpoints.ObjectiveSpecificsBody?
    ) async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.setObjective(
                objectiveType: objectiveType,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
        )
    }

    // MARK: - Step 4: Preferences

    /// Updates the user's learning preferences.
    func updatePreferences(
        preferredLearningStyle: LearningStyle,
        weeklyCommitHours: Double
    ) async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.updatePreferences(
                preferredLearningStyle: preferredLearningStyle.rawValue,
                weeklyCommitHours: weeklyCommitHours
            )
        )
    }

    // MARK: - Step 5: Interests

    /// Updates the user's skill and topic interests.
    func updateInterests(
        skills: [String],
        topicsOfInterest: [String]
    ) async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.updateInterests(
                skills: skills,
                topicsOfInterest: topicsOfInterest
            )
        )
    }

    // MARK: - Step 6: Complete

    /// Marks onboarding as complete.
    func complete() async throws {
        try await apiClient.requestVoid(
            OnboardingEndpoints.complete()
        )
    }
}
