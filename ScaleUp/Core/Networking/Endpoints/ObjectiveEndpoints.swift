import Foundation

// MARK: - Objective Endpoints

enum ObjectiveEndpoints {

    // MARK: - Request Bodies

    struct CreateObjectiveBody: Encodable {
        let objectiveType: String
        let timeline: String
        let currentLevel: String
        let weeklyCommitHours: Int
        let specifics: [String: String]?
    }

    struct UpdateObjectiveBody: Encodable {
        let specifics: [String: String]?
        let timeline: String?
        let currentLevel: String?
        let weeklyCommitHours: Int?
    }

    // MARK: - Endpoints

    static func list() -> Endpoint {
        .get("/objectives")
    }

    static func create(
        objectiveType: String,
        timeline: String,
        currentLevel: String,
        weeklyCommitHours: Int,
        specifics: [String: String]? = nil
    ) -> Endpoint {
        .post(
            "/objectives",
            body: CreateObjectiveBody(
                objectiveType: objectiveType,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours,
                specifics: specifics
            )
        )
    }

    static func update(
        id: String,
        specifics: [String: String]? = nil,
        timeline: String? = nil,
        currentLevel: String? = nil,
        weeklyCommitHours: Int? = nil
    ) -> Endpoint {
        .put(
            "/objectives/\(id)",
            body: UpdateObjectiveBody(
                specifics: specifics,
                timeline: timeline,
                currentLevel: currentLevel,
                weeklyCommitHours: weeklyCommitHours
            )
        )
    }

    static func pause(id: String) -> Endpoint {
        .put("/objectives/\(id)/pause")
    }

    static func resume(id: String) -> Endpoint {
        .put("/objectives/\(id)/resume")
    }

    static func setPrimary(id: String) -> Endpoint {
        .put("/objectives/\(id)/set-primary")
    }
}
