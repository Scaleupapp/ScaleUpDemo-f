import Foundation

// MARK: - Journey Endpoints

enum JourneyEndpoints {

    // MARK: - Request Bodies

    struct GenerateJourneyBody: Encodable {
        let objectiveId: String
    }

    // MARK: - Endpoints

    static func getJourney() -> Endpoint {
        .get("/journey")
    }

    static func generate(objectiveId: String) -> Endpoint {
        .post("/journey/generate", body: GenerateJourneyBody(objectiveId: objectiveId))
    }

    static func today() -> Endpoint {
        .get("/journey/today")
    }

    static func week(number: Int) -> Endpoint {
        .get("/journey/week/\(number)")
    }

    static func pause() -> Endpoint {
        .post("/journey/pause")
    }

    static func resume() -> Endpoint {
        .post("/journey/resume")
    }

    static func milestones() -> Endpoint {
        .get("/journey/milestones")
    }

    static func progress() -> Endpoint {
        .get("/journey/progress")
    }

    static func adaptations() -> Endpoint {
        .get("/journey/adaptations")
    }
}
