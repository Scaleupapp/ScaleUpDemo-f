import Foundation

// MARK: - Hire from ScaleUp — candidate-side models
//
// Mirrors the learner-authed `/api/v2/you/talent*` contract (Phase 1–3 backend):
//   GET  /you/talent                              → TalentState
//   POST /you/talent/opt-in        { prefs }      → { ok }
//   POST /you/talent/opt-out                      → { ok }
//   GET  /you/talent/connections                  → [CandidateConn]
//   POST /you/talent/connections/:id/approve      → ConnectionRespondResult
//   POST /you/talent/connections/:id/decline      → ConnectionRespondResult
//
// Every endpoint 404s while FEATURE_EMPLOYER_MARKETPLACE is off — the view model
// maps that 404 to `available = false` so the whole feature stays invisible.
//
// CODABLE LESSON: every optional field is `var x: T? = nil` (NOT `let ... = nil`).
// A `let`+default is omitted from synthesized Decodable and breaks memberwise inits.
// The backend GET returns the raw TalentProfile Mongo document, so these structs
// intentionally decode only the fields we use — Codable ignores the rest.

/// GET /you/talent → discoverability state + (optional) opted-in profile.
struct TalentState: Codable {
    var optedIn: Bool = false
    var profile: TalentProfile? = nil
}

/// The consented, recruiter-facing projection of a career objective.
struct TalentProfile: Codable {
    var city: String? = nil
    var noticePeriod: String? = nil
    var workPref: String? = nil
    var snapshot: TalentSnapshot? = nil
}

/// Denormalized readiness snapshot shown back to the candidate
/// ("Discoverable as <roleLabel>").
struct TalentSnapshot: Codable {
    var roleLabel: String? = nil
    var readinessBand: String? = nil
    var readinessScore: Int? = nil
}

/// GET /you/talent/connections → one incoming employer interest.
/// Employer identity is masked ("A verified employer") until the candidate approves,
/// at which point `reveal` is populated.
struct CandidateConn: Codable, Identifiable {
    var connectionId: String = ""
    var status: String = "requested"      // requested | approved | declined
    var employer: String? = nil           // always "A verified employer" while masked
    var roleContext: String? = nil
    var message: String? = nil
    var createdAt: String? = nil
    var respondedAt: String? = nil
    var reveal: EmployerReveal? = nil

    var id: String { connectionId }

    var isPending: Bool { status == "requested" }
    var isApproved: Bool { status == "approved" }
    var isDeclined: Bool { status == "declined" }
}

/// Revealed only after the candidate approves a connection.
struct EmployerReveal: Codable {
    var companyName: String? = nil
    var name: String? = nil
    var email: String? = nil
}

// MARK: - Request / response payloads

/// POST /you/talent/opt-in body. Doubles as the prefs-edit payload
/// (idempotent upsert — there is no PATCH). Nil fields are omitted by the encoder
/// so a partial edit only touches what changed.
struct TalentOptInBody: Codable {
    var city: String? = nil
    var noticePeriod: String? = nil
    var workPref: String? = nil
}

/// Empty POST body for opt-out (the client requires a Codable body type).
struct EmptyPostBody: Codable {}

/// `{ ok: true }` envelope returned by opt-in / opt-out.
struct OkResult: Codable {
    var ok: Bool = true
}

/// `{ connectionId, status }` returned by approve / decline.
struct ConnectionRespondResult: Codable {
    var connectionId: String = ""
    var status: String = ""
}
