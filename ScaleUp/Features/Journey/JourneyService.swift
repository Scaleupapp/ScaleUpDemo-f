import Foundation

actor JourneyService {
    private let api = APIClient.shared

    func getDashboard(objectiveId: String? = nil) async throws -> JourneyDashboard {
        try await api.request(JourneyEndpoints.dashboard(objectiveId: objectiveId))
    }

    func getJourney() async throws -> Journey {
        try await api.request(JourneyEndpoints.journey)
    }

    func getToday() async throws -> TodayResponse {
        try await api.request(JourneyEndpoints.today)
    }

    func getWeek(number: Int) async throws -> WeekResponse {
        try await api.request(JourneyEndpoints.week(number: number))
    }

    func completeAssignment(weekNumber: Int, day: Int) async throws -> AssignmentCompleteResponse {
        let body = CompleteAssignmentRequest(weekNumber: weekNumber, day: day)
        return try await api.request(JourneyEndpoints.completeAssignment, body: body)
    }

    func getMilestones() async throws -> [Milestone] {
        try await api.request(JourneyEndpoints.milestones)
    }

    func getAdaptations() async throws -> [AdaptationEntry] {
        try await api.request(JourneyEndpoints.adaptations)
    }

    func addMilestone(title: String, type: String, targetScore: Int?, targetTopic: String?) async throws -> [Milestone] {
        let body = AddMilestoneRequest(title: title, type: type, targetCriteria: MilestoneTargetRequest(targetScore: targetScore, targetTopic: targetTopic))
        return try await api.request(JourneyEndpoints.addMilestone, body: body)
    }

    func deleteMilestone(id: String) async throws -> [Milestone] {
        try await api.request(JourneyEndpoints.deleteMilestone(id: id))
    }

    func generate(objectiveId: String) async throws -> Journey {
        let body = GenerateJourneyRequest(objectiveId: objectiveId)
        return try await api.request(JourneyEndpoints.generate, body: body)
    }

    func pause() async throws {
        _ = try await api.requestRaw(JourneyEndpoints.pause)
    }

    func resume() async throws {
        _ = try await api.requestRaw(JourneyEndpoints.resume)
    }
}

// MARK: - Request Bodies

private struct CompleteAssignmentRequest: Encodable, Sendable {
    let weekNumber: Int
    let day: Int
}

private struct AddMilestoneRequest: Encodable, Sendable {
    let title: String
    let type: String
    let targetCriteria: MilestoneTargetRequest
}

private struct MilestoneTargetRequest: Encodable, Sendable {
    let targetScore: Int?
    let targetTopic: String?
}

// MARK: - Endpoints

private enum JourneyEndpoints: Endpoint {
    case journey
    case dashboard(objectiveId: String? = nil)
    case today
    case week(number: Int)
    case completeAssignment
    case milestones
    case addMilestone
    case deleteMilestone(id: String)
    case adaptations
    case generate
    case pause
    case resume

    var path: String {
        switch self {
        case .journey: return "/journey"
        case .dashboard: return "/journey/dashboard"
        case .today: return "/journey/today"
        case .week(let number): return "/journey/week/\(number)"
        case .completeAssignment: return "/journey/assignment/complete"
        case .milestones, .addMilestone: return "/journey/milestones"
        case .deleteMilestone(let id): return "/journey/milestones/\(id)"
        case .adaptations: return "/journey/adaptations"
        case .generate: return "/journey/generate"
        case .pause: return "/journey/pause"
        case .resume: return "/journey/resume"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .dashboard(let objectiveId):
            if let objectiveId {
                return [URLQueryItem(name: "objectiveId", value: objectiveId)]
            }
            return nil
        default:
            return nil
        }
    }

    var method: HTTPMethod {
        switch self {
        case .journey, .dashboard, .today, .week, .milestones, .adaptations:
            return .get
        case .generate, .addMilestone:
            return .post
        case .completeAssignment, .pause, .resume:
            return .put
        case .deleteMilestone:
            return .delete
        }
    }
}
