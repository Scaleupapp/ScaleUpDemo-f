import Foundation

/// Thin @MainActor service for the placement first-login (onboarding) hook.
/// All networking goes through `V2APIClient.shared` (`/api/v2`).
@MainActor
final class PlacementOnboardingApi {
    static let shared = PlacementOnboardingApi()
    private init() {}

    private struct CompleteBody: Codable {}
    private struct CompleteResult: Codable { let ok: Bool? }

    /// `POST /api/v2/me/placement-onboarding/complete`.
    ///
    /// Marks the placement student's first-login hook complete server-side
    /// (`diagnosticComplete = true`, enrollment stage → onboarded). Idempotent;
    /// returns 404 `NOT_PLACEMENT` for non-placement users. Best-effort: any
    /// failure is swallowed and returns `false` so the student is never blocked
    /// from reaching Home.
    @discardableResult
    func complete() async -> Bool {
        do {
            let resp: V2APIResponse<CompleteResult> = try await V2APIClient.shared.post(
                "/me/placement-onboarding/complete", body: CompleteBody()
            )
            return resp.success
        } catch {
            return false
        }
    }

    /// `GET /api/v2/me/placement-onboarding`.
    ///
    /// Returns the hook payload (objective / branch / year plus the additive
    /// season fields). Best-effort: `nil` on any failure (incl. a 404 for a
    /// non-placement user), so callers fall back to `AppState` context.
    func fetch() async -> PlacementOnboardingPayload? {
        do {
            let resp: V2APIResponse<PlacementOnboardingPayload> = try await V2APIClient.shared.get(
                "/me/placement-onboarding"
            )
            return resp.data
        } catch {
            return nil
        }
    }
}
