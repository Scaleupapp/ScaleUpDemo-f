import Foundation

// MARK: - Models

struct V2InsightsData: Codable {
    let baseline: BaselineBlock
    let calibration: CalibrationBlock
    /// Per-competency performance — drives the "How you did per section"
    /// breakdown (time / accuracy / score), so users see HOW the readiness
    /// number was built, not just the number.
    let performance: [PerformanceItem]?
    let patterns: [String]
    let trajectory: TrajectoryBlock?
    let topActions: [TopActionBlock]
    let planHeadline: String

    struct PerformanceItem: Codable, Identifiable {
        let topic: String
        let score: Int?
        let band: String?
        let accuracyPct: Int
        let avgTimeSec: Int
        let questionsAnswered: Int
        let hardAccuracyPct: Int?
        var id: String { topic }
    }

    struct BaselineBlock: Codable {
        let readiness: Int
        let headline: String
    }
    struct CalibrationBlock: Codable {
        let selfRated: [SelfRated]
        let actual: [Actual]
        let gap: [GapEntry]
        let summary: String

        struct SelfRated: Codable {
            let topic: String
            let level: String
        }
        struct Actual: Codable {
            let topic: String
            /// nil when notTested is true (no questions were in the pool).
            let scorePct: Int?
            /// nil when notTested is true.
            let band: String?
            /// True when the backend had no questions for this topic in the
            /// diagnostic pool (bank empty + LLM gen failed). Score and band
            /// are absent; UI should render "Not tested".
            let notTested: Bool?
        }
        struct GapEntry: Codable {
            let topic: String
            let delta: Int
            let classification: String
        }
    }
    struct TrajectoryBlock: Codable {
        let today: Int
        let in30Days: Int
        let in60Days: Int?
        let in90Days: Int?
        let atTargetDate: Int
        let targetReadiness: Int
        let timelineWeeks: Int
        let weeklyDelta: Int
        let onTrack: Bool
        let headline: String?
    }
    struct TopActionBlock: Codable {
        let rank: Int
        let title: String
        let reason: String
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2CalibrationInsightsViewModel {
    var data: V2InsightsData?
    var isLoading = false
    var error: String?
    var attemptId: String?

    func load(attemptId: String) async {
        self.attemptId = attemptId
        isLoading = true
        error = nil
        do {
            let resp: V2APIResponse<V2InsightsData> = try await V2APIClient.shared.get("/diagnostic/\(attemptId)/insights")
            data = resp.data
        } catch {
            self.error = "Couldn't load your insights. Try again."
            data = nil
        }
        isLoading = false
    }

    func loadLatestAttempt() async {
        // Convenience: pulls the latest diagnostic attempt for the user from v1
        // We don't have a v1 wrapper here; the calling view should pass an attemptId.
        // If absent, show the error state.
        if attemptId == nil {
            self.error = "No diagnostic attempt to load."
            self.data = nil
        }
    }
}
