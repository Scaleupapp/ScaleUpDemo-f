import Foundation

// MARK: - Models (agentic layer #4, flag `interview_coach`)
//
// Client shapes for GET/POST /api/v2/interview-program. Date fields come
// back as ISO8601 strings — the v2 namespace's JSONDecoder does NOT install
// an ISO8601 date-decoding strategy (only `.coding` does, see
// V2APIClient.decoder(for:)), so we decode them as String and parse lazily
// when displaying, matching the convention used elsewhere in Features/V2
// (e.g. V2CompassHistoryView, V2PlanDetailViewModel).

struct InterviewProgramTarget: Codable {
    let role: String?
    let company: String?
    let driveDate: String?
}

struct InterviewProgramWeekStrip: Codable {
    let current: Int
    let total: Int
}

struct InterviewProgramDimensionTrend: Codable, Identifiable {
    var id: String { dimension }
    let dimension: String
    let scores: [Double]
    let delta: Double?
}

struct InterviewProgramFocus: Codable {
    let dimension: String?
    let score: Double?
    let delta: Double?
    let reason: String
}

/// Client shape for the caller's active interview-coach program. Named
/// `InterviewProgram` (not `InterviewProgramView`, the OpenAPI schema name)
/// to avoid colliding with the SwiftUI `InterviewProgramView` screen.
struct InterviewProgram: Codable, Identifiable {
    let id: String
    let status: String // active | completed | abandoned
    let target: InterviewProgramTarget
    let weekStrip: InterviewProgramWeekStrip
    let trends: [InterviewProgramDimensionTrend]
    let focus: InterviewProgramFocus
    let suggestion: String
    let sessionsCompleted: Int
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status, target, weekStrip, trends, focus, suggestion, sessionsCompleted, createdAt
    }
}

// MARK: - Service

@MainActor
enum InterviewProgramService {
    private struct ProgramWrapper: Codable { let program: InterviewProgram? }
    private struct AbandonWrapper: Codable { let abandoned: Bool }
    private struct CreateBody: Codable {
        let targetRole: String
        let targetCompany: String?
        let driveDate: String?
        let weeks: Int?
    }
    private struct EmptyBody: Codable {}

    /// Returns the caller's active program, or nil when none exists.
    /// Throws `V2APIError.httpError(404, _)` when the `interview_coach` flag
    /// is off — callers should treat that as "hide this feature entirely".
    static func fetch() async throws -> InterviewProgram? {
        let resp: V2APIResponse<ProgramWrapper> = try await V2APIClient.shared.get("/interview-program")
        return resp.data.program
    }

    static func create(targetRole: String, targetCompany: String?, driveDate: Date?, weeks: Int?) async throws -> InterviewProgram {
        let driveDateISO = driveDate.map { ISO8601DateFormatter().string(from: $0) }
        let body = CreateBody(targetRole: targetRole, targetCompany: targetCompany, driveDate: driveDateISO, weeks: weeks)
        let resp: V2APIResponse<ProgramWrapper> = try await V2APIClient.shared.post("/interview-program", body: body)
        guard let program = resp.data.program else { throw V2APIError.decodingFailed }
        return program
    }

    /// Idempotent — always returns normally (abandoned:false when there was
    /// nothing active to abandon).
    static func abandon() async throws -> Bool {
        let resp: V2APIResponse<AbandonWrapper> = try await V2APIClient.shared.post("/interview-program/abandon", body: EmptyBody())
        return resp.data.abandoned
    }
}

// MARK: - Display helpers

enum InterviewProgramFormat {
    static func date(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let d = withFrac.date(from: iso) ?? plain.date(from: iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f.string(from: d)
    }

    static func dimensionLabel(_ raw: String?) -> String {
        (raw ?? "").capitalized
    }
}
