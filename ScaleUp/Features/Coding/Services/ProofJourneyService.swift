import Foundation

// MARK: - Models (agentic layer #8, flag `proof_builder`)
//
// Client shapes for GET/POST /api/v2/proof-journey. Date fields decode as
// String (not Date) — see the note in InterviewProgramService.swift; the
// `.v2` JSONDecoder has no ISO8601 strategy installed.

struct ProofJourneyStep: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let status: String // done | now | todo | failed
    let at: String?
}

struct ProofJourneyJdSummary: Codable {
    let role: String?
    let company: String?
    let skills: [String]
}

struct ProofJourneyCapstoneRef: Codable {
    let bundleId: String?
    let sessionId: String?
}

struct ProofJourneyNextSuggestion: Codable {
    let skill: String
    let reason: String
}

/// Client shape for the caller's latest proof-builder journey. Named
/// `ProofJourney` (not `ProofJourneyView`, the OpenAPI schema name) to avoid
/// colliding with the SwiftUI `ProofJourneyView` screen.
struct ProofJourney: Codable, Identifiable {
    let id: String
    let status: String // extracting | capstone_pending | building | grading | publishable | published | failed
    let jdSummary: ProofJourneyJdSummary
    let steps: [ProofJourneyStep]
    let capstoneRef: ProofJourneyCapstoneRef
    let proofToken: String?
    let nextProofSuggestion: ProofJourneyNextSuggestion?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case status, jdSummary, steps, capstoneRef, proofToken, nextProofSuggestion, createdAt
    }
}

// MARK: - Service

@MainActor
enum ProofJourneyService {
    private struct JourneyWrapper: Codable { let journey: ProofJourney? }
    private struct CreateBody: Codable { let jdText: String }
    private struct EmptyBody: Codable {}

    /// Returns the caller's latest journey, or nil when none exists yet.
    /// Throws `V2APIError.httpError(404, _)` when the `proof_builder` flag
    /// is off — callers should treat that as "hide this feature entirely".
    static func fetch() async throws -> ProofJourney? {
        let resp: V2APIResponse<JourneyWrapper> = try await V2APIClient.shared.get("/proof-journey")
        return resp.data.journey
    }

    static func create(jdText: String) async throws -> ProofJourney {
        let resp: V2APIResponse<JourneyWrapper> = try await V2APIClient.shared.post("/proof-journey", body: CreateBody(jdText: jdText))
        guard let journey = resp.data.journey else { throw V2APIError.decodingFailed }
        return journey
    }

    static func publish() async throws -> ProofJourney {
        let resp: V2APIResponse<JourneyWrapper> = try await V2APIClient.shared.post("/proof-journey/publish", body: EmptyBody())
        guard let journey = resp.data.journey else { throw V2APIError.decodingFailed }
        return journey
    }
}

// MARK: - Display helpers

enum ProofJourneyFormat {
    /// Public share URL for a published proof page.
    static func shareURL(token: String) -> URL? {
        URL(string: "https://scaleupapp.club/r/\(token)")
    }

    static func shareLinkText(token: String) -> String {
        "scaleupapp.club/r/\(token)"
    }

    /// Statuses where the journey is progressing automatically in the
    /// background (extraction, capstone provisioning, grading) — the screen
    /// should poll and show a waiting state, no user action needed yet.
    static let waitingStatuses: Set<String> = ["extracting", "capstone_pending", "grading"]
}
