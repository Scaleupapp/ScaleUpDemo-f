import Foundation

/// Standardized event names + properties for the coding drill flow.
/// Event names are stable across iOS + Android (same strings on RN side).
///
/// Uses `AnalyticsService.shared.track(...)` — the project-wide fan-out
/// dispatcher — rather than calling Mixpanel directly, so events flow
/// through enrichment (app_version, build_number, platform) and any
/// future provider additions automatically.
@MainActor
enum DrillAnalytics {

    static func trackCardShown(drill: DrillTodayResponse) {
        AnalyticsService.shared.track(
            .codingDrillCardShown(
                drillSubtype: drill.drillSubtype.rawValue,
                difficulty: drill.difficulty.rawValue,
                roleTrack: drill.roleTrack.rawValue
            )
        )
    }

    static func trackCalibrationCardShown() {
        AnalyticsService.shared.track(.codingCalibrationCardShown)
    }

    static func trackCardTapped(drill: DrillTodayResponse) {
        AnalyticsService.shared.track(
            .codingDrillCardTapped(
                drillSubtype: drill.drillSubtype.rawValue,
                difficulty: drill.difficulty.rawValue
            )
        )
    }

    static func trackCalibrationCardTapped() {
        AnalyticsService.shared.track(.codingCalibrationCardTapped)
    }

    static func trackStarted(drill: DrillTodayResponse) {
        AnalyticsService.shared.track(
            .codingDrillStarted(
                drillSubtype: drill.drillSubtype.rawValue,
                difficulty: drill.difficulty.rawValue
            )
        )
    }

    static func trackSubmitted(drill: DrillTodayResponse, timeTakenSeconds: Int) {
        AnalyticsService.shared.track(
            .codingDrillSubmitted(
                drillSubtype: drill.drillSubtype.rawValue,
                difficulty: drill.difficulty.rawValue,
                timeTakenSeconds: timeTakenSeconds
            )
        )
    }

    static func trackResultViewed(drill: DrillTodayResponse, score: Int) {
        AnalyticsService.shared.track(
            .codingDrillResultViewed(
                drillSubtype: drill.drillSubtype.rawValue,
                difficulty: drill.difficulty.rawValue,
                score: score
            )
        )
    }

    static func trackAbandoned(drill: DrillTodayResponse, atState: String) {
        AnalyticsService.shared.track(
            .codingDrillAbandoned(
                drillSubtype: drill.drillSubtype.rawValue,
                abandonedAt: atState
            )
        )
    }

    static func trackCalibrationCompleted(recommendedDifficulty: String) {
        AnalyticsService.shared.track(
            .codingCalibrationCompleted(recommendedDifficulty: recommendedDifficulty)
        )
    }
}
