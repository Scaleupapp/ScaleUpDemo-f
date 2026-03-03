import Foundation

actor ObjectiveService {
    private let api = APIClient.shared

    // MARK: - Analysis

    func analyzeObjective(id: String) async throws -> ObjectiveAnalysisResponse {
        try await api.request(ObjectiveEndpoints.analyze(id: id))
    }

    func getObjectiveBrief(id: String) async throws -> ObjectiveBriefResponse {
        try await api.request(ObjectiveEndpoints.brief(id: id))
    }

    func getCompetencies(objectiveId: String) async throws -> [ObjectiveCompetency] {
        let brief: ObjectiveBriefResponse = try await api.request(ObjectiveEndpoints.brief(id: objectiveId))
        return brief.competencies ?? []
    }

    // MARK: - CRUD

    func list() async throws -> [UserObjective] {
        try await api.request(ObjectiveEndpoints.list)
    }

    func create(body: CreateObjectiveRequest) async throws -> UserObjective {
        try await api.request(ObjectiveEndpoints.create, body: body)
    }

    func update(id: String, body: UpdateObjectiveRequest) async throws -> UserObjective {
        try await api.request(ObjectiveEndpoints.update(id: id), body: body)
    }

    func pause(id: String) async throws {
        _ = try await api.requestRaw(ObjectiveEndpoints.pause(id: id))
    }

    func resume(id: String) async throws {
        _ = try await api.requestRaw(ObjectiveEndpoints.resume(id: id))
    }

    func setPrimary(id: String) async throws {
        _ = try await api.requestRaw(ObjectiveEndpoints.setPrimary(id: id))
    }
}

// MARK: - Response Models

struct ObjectiveAnalysisResponse: Codable, Sendable {
    let analysis: ObjectiveAnalysis?
}

struct ObjectiveAnalysis: Codable, Sendable {
    let competencies: [ObjectiveCompetency]?
    let objectiveBrief: ObjectiveBriefContent?
    let contentCoverage: ContentCoverage?
    let assessmentStrategy: AssessmentStrategy?
    let analyzedAt: Date?
    let aiModel: String?
}

struct ObjectiveCompetency: Codable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let weight: Int?
    let category: String?
    let prerequisites: [String]?
    let assessmentTypes: [String]?
    let proficiencyLevels: [ProficiencyLevel]?

    // Enriched in brief response
    let currentScore: Double?
    let currentLevel: String?
    let trend: String?
    let contentItems: [CompetencyContentItem]?
}

struct CompetencyContentItem: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let thumbnailUrl: String?
    let duration: Int?
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, thumbnailUrl, duration, contentType
    }
}

struct ProficiencyLevel: Codable, Sendable, Identifiable {
    var id: Int { level }
    let level: Int
    let title: String
    let description: String?
}

struct ObjectiveBriefContent: Codable, Sendable {
    let overview: String?
    let dayToDay: String?
    let challenges: String?
    let successCriteria: String?
    let industryContext: String?
}

struct ContentCoverage: Codable, Sendable {
    let covered: [String]?
    let gaps: [String]?
    let gapStrategies: [GapStrategy]?
}

struct GapStrategy: Codable, Sendable, Identifiable {
    var id: String { competency }
    let competency: String
    let strategy: String?
    let resources: [String]?
}

struct AssessmentStrategy: Codable, Sendable {
    let recommended: [AssessmentRecommendation]?
}

struct AssessmentRecommendation: Codable, Sendable, Identifiable {
    var id: String { competency }
    let competency: String
    let assessmentType: String?
    let reasoning: String?
}

// MARK: - Brief Response (enriched with user progress)

struct ObjectiveBriefResponse: Codable, Sendable {
    let objective: BriefObjectiveInfo?
    let brief: ObjectiveBriefContent?
    let competencies: [ObjectiveCompetency]?
    let contentCoverage: ContentCoverage?
    let assessmentStrategy: AssessmentStrategy?
    let analyzedAt: Date?
}

struct BriefObjectiveInfo: Codable, Sendable {
    let id: String?
    let objectiveType: String?
    let specifics: BriefSpecifics?
    let timeline: String?
    let currentLevel: String?
    let targetDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case objectiveType, specifics, timeline, currentLevel, targetDate
    }

    // Convenience
    var goalTitle: String {
        if let role = specifics?.targetRole { return "Become a \(role)" }
        if let skill = specifics?.targetSkill { return "Master \(skill)" }
        if let exam = specifics?.examName { return "Crack \(exam)" }
        return objectiveType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Learning Goal"
    }
}

struct BriefSpecifics: Codable, Sendable {
    let targetRole: String?
    let targetSkill: String?
    let examName: String?
    let targetCompany: String?
    let fromDomain: String?
    let toDomain: String?
}

// MARK: - Request Bodies

struct CreateObjectiveRequest: Encodable, Sendable {
    let objectiveType: String
    let specifics: ObjectiveSpecificsInput?
    let timeline: String
    let currentLevel: String
    let weeklyCommitHours: Int
    let preferredLearningStyle: String
    let topicsOfInterest: [String]
}

struct ObjectiveSpecificsInput: Encodable, Sendable {
    var targetRole: String?
    var targetSkill: String?
    var examName: String?
    var targetCompany: String?
    var fromDomain: String?
    var toDomain: String?
}

struct UpdateObjectiveRequest: Encodable, Sendable {
    var timeline: String?
    var currentLevel: String?
    var weeklyCommitHours: Int?
    var preferredLearningStyle: String?
    var topicsOfInterest: [String]?
}

// MARK: - Endpoints

private enum ObjectiveEndpoints: Endpoint {
    case analyze(id: String)
    case brief(id: String)
    case list
    case create
    case update(id: String)
    case pause(id: String)
    case resume(id: String)
    case setPrimary(id: String)

    var path: String {
        switch self {
        case .analyze(let id): return "/objectives/\(id)/analyze"
        case .brief(let id): return "/objectives/\(id)/brief"
        case .list, .create: return "/objectives"
        case .update(let id): return "/objectives/\(id)"
        case .pause(let id): return "/objectives/\(id)/pause"
        case .resume(let id): return "/objectives/\(id)/resume"
        case .setPrimary(let id): return "/objectives/\(id)/set-primary"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .analyze, .create: return .post
        case .brief, .list: return .get
        case .update, .pause, .resume, .setPrimary: return .put
        }
    }
}
