import Foundation
import Observation

@Observable
@MainActor
final class DrillSession {
    var state: DrillViewState = .loading
    var todayDrill: DrillTodayResponse?
    var attemptId: String?
    var startedAt: Date?
    var lastError: String?

    private let service: DrillService

    init(service: DrillService = .shared) {
        self.service = service
    }

    func loadToday() async {
        state = .loading
        do {
            let drill = try await service.fetchTodayDrill()
            todayDrill = drill
            state = .brief
        } catch DrillServiceError.calibrationRequired {
            state = .calibrationRequired
        } catch DrillServiceError.noDrillAvailable {
            state = .noDrillAvailable
        } catch {
            lastError = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    /// Called when the user taps Start on the brief screen.
    /// Creates the DrillAttempt server-side and moves to .input.
    func start() async {
        guard let drill = todayDrill else { return }
        do {
            let started = try await service.startDrill(bundleId: drill.bundleId)
            attemptId = started.attemptId
            startedAt = Date()
            state = .input
        } catch {
            lastError = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    /// Submit the drill. Called from the per-subtype input views in UI-B3/B4/B5.
    /// Implemented in UI-B6.
    func submit(_ submission: DrillSubmission) async {
        // Stub for UI-B2 — real impl lands in UI-B6.
        // Current behavior: just move to .submitting so the developer can see the
        // state transition. UI-B6 will wire the real submit + poll.
        state = .submitting
    }

    var timeRemaining: TimeInterval? {
        guard let started = startedAt, let drill = todayDrill else { return nil }
        let budgetSeconds = TimeInterval(drill.timeBudgetMinutes * 60)
        let elapsed = Date().timeIntervalSince(started)
        return max(0, budgetSeconds - elapsed)
    }
}
