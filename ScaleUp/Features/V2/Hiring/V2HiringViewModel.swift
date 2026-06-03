import Foundation

/// Drives the candidate side of "Hire from ScaleUp": the Open-to-work opt-in and
/// the connection inbox. Self-gating — `available` stays nil until `load()` runs,
/// then becomes `false` if the backend 404s (feature flag off) or `true` otherwise.
///
/// Mirrors `V2YouViewModel`'s `@Observable @MainActor final class` idiom and uses
/// `V2APIClient.shared.get/post` exactly like the other v2 view models.
@Observable
@MainActor
final class V2HiringViewModel {

    // MARK: - State

    /// nil = not loaded yet, false = feature off (404) or load failed, true = available.
    /// The You-tab entry only renders when this is `true`.
    var available: Bool? = nil

    var optedIn: Bool = false
    var profile: TalentProfile? = nil

    var connections: [CandidateConn] = []

    var loading = false
    var error: String? = nil

    /// Set when opt-in is blocked because the user isn't eligible / has no snapshot /
    /// has no objective — drives the friendly "take an assessment first" state.
    var ineligibleReason: String? = nil

    // MARK: - Derived

    /// Count of pending (requested) connections — surfaced as the inbox badge.
    var pendingCount: Int { connections.filter { $0.isPending }.count }

    /// "Discoverable as <role>" line for the opt-in screen + You-tab row.
    var roleLabel: String? { profile?.snapshot?.roleLabel }

    // MARK: - Talent state

    /// GET /you/talent. On 404 (flag off) → `available = false`; on success →
    /// `available = true` plus optedIn/profile. Other errors also hide the feature.
    func load() async {
        do {
            let response: V2APIResponse<TalentState> = try await V2APIClient.shared.get("/you/talent")
            available = true
            optedIn = response.data.optedIn
            profile = response.data.profile
        } catch V2APIError.httpError(let status, _) where status == 404 {
            // Feature flag is off — keep the whole feature invisible.
            available = false
        } catch V2APIError.serverError(let code) where code == 404 {
            available = false
        } catch {
            // Unknown failure: hide rather than show a broken entry.
            available = false
        }
    }

    /// POST /you/talent/opt-in. Doubles as "save prefs" while opted in (idempotent
    /// upsert; there is no PATCH). On the eligibility errors we surface a friendly
    /// reason instead of a raw server message.
    func optIn(city: String?, noticePeriod: String?, workPref: String?) async {
        loading = true
        error = nil
        ineligibleReason = nil
        let body = TalentOptInBody(city: normalized(city),
                                   noticePeriod: normalized(noticePeriod),
                                   workPref: normalized(workPref))
        do {
            let _: V2APIResponse<OkResult> = try await V2APIClient.shared.post("/you/talent/opt-in", body: body)
            optedIn = true
            // Reflect the saved prefs immediately, then refresh the snapshot from server.
            await load()
        } catch {
            handleOptInError(error)
        }
        loading = false
    }

    /// POST /you/talent/opt-out → removes the candidate from search.
    func optOut() async {
        loading = true
        error = nil
        do {
            let _: V2APIResponse<OkResult> = try await V2APIClient.shared.post("/you/talent/opt-out", body: EmptyPostBody())
            optedIn = false
            await load()
        } catch {
            error = friendlyMessage(for: error, fallback: "Couldn't turn this off. Try again.")
        }
        loading = false
    }

    // MARK: - Connections

    /// GET /you/talent/connections → the inbox.
    func loadConnections() async {
        loading = true
        error = nil
        do {
            let response: V2APIResponse<[CandidateConn]> = try await V2APIClient.shared.get("/you/talent/connections")
            connections = response.data
        } catch {
            error = friendlyMessage(for: error, fallback: "Couldn't load your inbox. Pull to refresh.")
        }
        loading = false
    }

    /// POST /you/talent/connections/:id/approve → reveals the employer.
    func approve(_ id: String) async {
        await respond(id: id, decision: "approve")
    }

    /// POST /you/talent/connections/:id/decline → greys the request out.
    func decline(_ id: String) async {
        await respond(id: id, decision: "decline")
    }

    private func respond(id: String, decision: String) async {
        error = nil
        do {
            let _: V2APIResponse<ConnectionRespondResult> =
                try await V2APIClient.shared.post("/you/talent/connections/\(id)/\(decision)", body: EmptyPostBody())
            // Re-fetch so an approval pulls in the freshly-revealed employer details.
            await loadConnections()
        } catch V2APIError.httpError(let status, _) where status == 409 {
            // ALREADY_RESPONDED — someone/somewhere already actioned it; just resync.
            await loadConnections()
        } catch {
            error = friendlyMessage(for: error, fallback: "Couldn't update this request. Try again.")
        }
    }

    // MARK: - Error mapping

    private func handleOptInError(_ error: Error) {
        if case V2APIError.httpError(let status, let data) = error, status == 400 {
            let code = errorCode(from: data)
            switch code {
            case "NOT_ELIGIBLE":
                ineligibleReason = "You're not eligible for the talent pool yet — keep building evidence on a career goal."
                return
            case "NO_SNAPSHOT":
                ineligibleReason = "Complete at least one assessment on a career goal before joining the talent pool."
                return
            case "NO_OBJECTIVE":
                ineligibleReason = "Set up a career goal first, then take an assessment to join the talent pool."
                return
            default:
                break
            }
        }
        self.error = friendlyMessage(for: error, fallback: "Couldn't update. Try again.")
    }

    /// Pulls the `code` field out of the backend error envelope:
    /// `{ success:false, code:'...', message:'...' }`.
    private func errorCode(from data: Data) -> String? {
        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return body["code"] as? String
    }

    /// Falls back to the server `message` when present, else a caller-supplied default.
    private func friendlyMessage(for error: Error, fallback: String) -> String {
        if case V2APIError.httpError(let status, let data) = error {
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = body["message"] as? String, !message.isEmpty {
                return message
            }
            if status == 401 { return "Please sign in again." }
            if status >= 500 { return "Server hiccup (\(status)). Try again in a moment." }
        }
        return fallback
    }

    /// Trims whitespace and treats an empty string as "no value" so the encoder
    /// omits it (a partial pref edit shouldn't blank out the others).
    private func normalized(_ s: String?) -> String? {
        guard let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
