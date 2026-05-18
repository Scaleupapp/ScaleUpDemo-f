import Foundation

/// Network service for the v2 onboarding flow. Wraps both the new v2 endpoints
/// and the reused v1 onboarding endpoints behind one clean surface.
@MainActor
final class V2OnboardingService {
    static let shared = V2OnboardingService()
    private init() {}

    // MARK: - Objective parsing (v2 NLU)

    struct ParseBody: Codable { let text: String }

    func parseObjective(_ text: String) async throws -> V2ObjectiveParseResult {
        let resp: V2APIResponse<V2ObjectiveParseResult> =
            try await V2APIClient.shared.post("/objective/parse", body: ParseBody(text: text))
        return resp.data
    }

    // MARK: - Catalog typeahead (v2)

    func suggest(query: String, type: String? = nil, limit: Int = 10) async throws -> [V2CatalogEntry] {
        var path = "/objective/suggest?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)"
        if let type = type { path += "&type=\(type)" }
        let resp: V2APIResponse<[V2CatalogEntry]> = try await V2APIClient.shared.get(path)
        return resp.data
    }

    func popular(type: String? = nil, limit: Int = 8) async throws -> [V2CatalogEntry] {
        var path = "/objective/popular?limit=\(limit)"
        if let type = type { path += "&type=\(type)" }
        let resp: V2APIResponse<[V2CatalogEntry]> = try await V2APIClient.shared.get(path)
        return resp.data
    }

    // MARK: - Topic suggestion (reuses v1 /onboarding/topics/suggest)

    func suggestTopics(for state: V2OnboardingState) async throws -> V2TopicsSuggestResponse {
        try await V2APIClient.shared.postV1(
            "/onboarding/topics/suggest",
            body: state.topicsSuggestBody()
        )
    }

    // MARK: - Required-time computation (v2)

    func computeRequiredTime(for state: V2OnboardingState) async throws -> V2RequiredTimeResponse {
        let resp: V2APIResponse<V2RequiredTimeResponse> =
            try await V2APIClient.shared.post("/objective/required-time", body: state.requiredTimeBody())
        return resp.data
    }

    // MARK: - Save objective (reuses v1 /onboarding/complete)

    func completeOnboarding(state: V2OnboardingState, weeklyCommitHours: Int) async throws -> V2OnboardingCompleteResponse {
        try await V2APIClient.shared.postV1(
            "/onboarding/complete",
            body: state.onboardingCompleteBody(weeklyCommitHours: weeklyCommitHours)
        )
    }

    // MARK: - Plan generation (v2 order: triggered AFTER the Reality Check)

    struct GeneratePlanBody: Codable { let attemptId: String }
    struct GeneratePlanResponse: Codable { let status: String; let alreadyTriggered: Bool }
    struct PlanGenStatusResponse: Codable { let status: String; let planId: String? }

    /// POST /api/v2/plan/generate — kicks off plan generation once the user has
    /// confirmed their weekly commitment on the Reality Check screen.
    func triggerPlanGeneration(attemptId: String) async throws -> GeneratePlanResponse {
        let resp: V2APIResponse<GeneratePlanResponse> =
            try await V2APIClient.shared.post("/plan/generate", body: GeneratePlanBody(attemptId: attemptId))
        return resp.data
    }

    /// GET /api/v2/plan/generation-status — poll for the Plan Creation screen.
    func planGenerationStatus(attemptId: String) async throws -> PlanGenStatusResponse {
        let resp: V2APIResponse<PlanGenStatusResponse> =
            try await V2APIClient.shared.get("/plan/generation-status?attemptId=\(attemptId)")
        return resp.data
    }

    // MARK: - Update weekly hours after the post-diagnostic Reality Check

    struct UpdateHoursBody: Codable { let weeklyCommitHours: Int }

    /// PUT /api/v1/objectives/:id — update just the weekly commitment after
    /// the user adjusts it on the post-diagnostic Reality Check screen.
    func updateWeeklyHours(objectiveId: String, hours: Int) async throws {
        struct Ignored: Codable {}
        let _: Ignored = try await V2APIClient.shared.putV1(
            "/objectives/\(objectiveId)",
            body: UpdateHoursBody(weeklyCommitHours: hours)
        )
    }

    // MARK: - Fetch the user's primary objective (for the post-diagnostic Reality Check)

    /// GET /api/v1/objectives — returns the user's objectives; we pick the
    /// primary active one. Permissive decode so v1 shape changes don't break it.
    func fetchPrimaryObjective() async throws -> V2ActiveObjective {
        // v1 may return { success, data: [...] } or a bare array — handle both.
        let raw: V2ObjectivesEnvelope = try await V2APIClient.shared.getV1("/objectives")
        let list = raw.resolved
        guard let primary = list.first(where: { $0.isPrimary == true }) ?? list.first else {
            throw V2APIError.decodingFailed
        }
        return primary
    }
}

/// Permissive envelope — v1 /objectives may be `{success,data:[...]}` or `[...]`.
struct V2ObjectivesEnvelope: Codable {
    let data: [V2ActiveObjective]?
    let objectives: [V2ActiveObjective]?
    private let bareArray: [V2ActiveObjective]?

    var resolved: [V2ActiveObjective] { data ?? objectives ?? bareArray ?? [] }

    init(from decoder: Decoder) throws {
        if let arr = try? decoder.singleValueContainer().decode([V2ActiveObjective].self) {
            bareArray = arr; data = nil; objectives = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decodeIfPresent([V2ActiveObjective].self, forKey: .data)
        objectives = try c.decodeIfPresent([V2ActiveObjective].self, forKey: .objectives)
        bareArray = nil
    }
    func encode(to encoder: Encoder) throws {}
    enum CodingKeys: String, CodingKey { case data, objectives }
}

struct V2ActiveObjective: Codable {
    let _id: String?
    let id: String?
    let objectiveType: String
    let timeline: String
    let currentLevel: String?
    let weeklyCommitHours: Int?
    let isPrimary: Bool?
    let specifics: SpecificsBlock?

    var objectiveId: String? { _id ?? id }

    struct SpecificsBlock: Codable {
        let examName: String?
        let targetSkill: String?
        let targetRole: String?
        let targetCompany: String?
        let fromDomain: String?
        let toDomain: String?
    }

    var specificsDict: [String: String] {
        var s: [String: String] = [:]
        if let v = specifics?.targetRole, !v.isEmpty { s["targetRole"] = v }
        if let v = specifics?.targetCompany, !v.isEmpty { s["targetCompany"] = v }
        if let v = specifics?.examName, !v.isEmpty { s["examName"] = v }
        if let v = specifics?.targetSkill, !v.isEmpty { s["targetSkill"] = v }
        if let v = specifics?.fromDomain, !v.isEmpty { s["fromDomain"] = v }
        if let v = specifics?.toDomain, !v.isEmpty { s["toDomain"] = v }
        return s
    }
}
