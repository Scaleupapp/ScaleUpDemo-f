import Foundation

// MARK: - Onboarding Endpoints

enum OnboardingEndpoints {

    // MARK: - Request Bodies

    struct UpdateProfileBody: Encodable {
        let firstName: String?
        let lastName: String?
        let dateOfBirth: String?
        let location: String?
    }

    struct UpdateBackgroundBody: Encodable {
        let education: [Education]
        let workExperience: [WorkExperience]
    }

    struct ObjectiveSpecificsBody: Encodable {
        let examName: String?
        let targetSkill: String?
        let targetRole: String?
        let targetCompany: String?
        let fromDomain: String?
        let toDomain: String?

        // Omit null keys from JSON
        enum CodingKeys: String, CodingKey {
            case examName, targetSkill, targetRole, targetCompany, fromDomain, toDomain
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(examName, forKey: .examName)
            try container.encodeIfPresent(targetSkill, forKey: .targetSkill)
            try container.encodeIfPresent(targetRole, forKey: .targetRole)
            try container.encodeIfPresent(targetCompany, forKey: .targetCompany)
            try container.encodeIfPresent(fromDomain, forKey: .fromDomain)
            try container.encodeIfPresent(toDomain, forKey: .toDomain)
        }
    }

    struct SetObjectiveBody: Encodable {
        let objectiveType: String
        let timeline: String
        let currentLevel: String
        let weeklyCommitHours: Double
        let specifics: ObjectiveSpecificsBody?
    }

    struct UpdatePreferencesBody: Encodable {
        let preferredLearningStyle: String?
        let weeklyCommitHours: Double?
    }

    struct UpdateInterestsBody: Encodable {
        let skills: [String]
        let topicsOfInterest: [String]
    }

    // MARK: - Endpoints

    static func getStatus() -> Endpoint {
        .get("/onboarding")
    }

    static func updateProfile(firstName: String? = nil, lastName: String? = nil, dateOfBirth: String? = nil, location: String? = nil) -> Endpoint {
        .put(
            "/onboarding/profile",
            body: UpdateProfileBody(firstName: firstName, lastName: lastName, dateOfBirth: dateOfBirth, location: location)
        )
    }

    static func updateBackground(education: [Education], workExperience: [WorkExperience]) -> Endpoint {
        .put(
            "/onboarding/background",
            body: UpdateBackgroundBody(education: education, workExperience: workExperience)
        )
    }

    static func setObjective(
        objectiveType: ObjectiveType,
        timeline: Timeline,
        currentLevel: Difficulty,
        weeklyCommitHours: Double,
        specifics: ObjectiveSpecificsBody?
    ) -> Endpoint {
        .post(
            "/onboarding/objective",
            body: SetObjectiveBody(
                objectiveType: objectiveType.rawValue,
                timeline: timeline.rawValue,
                currentLevel: currentLevel.rawValue,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
        )
    }

    static func updatePreferences(preferredLearningStyle: String? = nil, weeklyCommitHours: Double? = nil) -> Endpoint {
        .put(
            "/onboarding/preferences",
            body: UpdatePreferencesBody(preferredLearningStyle: preferredLearningStyle, weeklyCommitHours: weeklyCommitHours)
        )
    }

    static func updateInterests(skills: [String], topicsOfInterest: [String]) -> Endpoint {
        .put(
            "/onboarding/interests",
            body: UpdateInterestsBody(skills: skills, topicsOfInterest: topicsOfInterest)
        )
    }

    static func complete() -> Endpoint {
        .post("/onboarding/complete")
    }
}
