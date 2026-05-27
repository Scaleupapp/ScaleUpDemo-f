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

    /// Initialize with a pre-fetched drill (used by Practice Another + Compass action card flows).
    /// Skips the loadToday network call — moves straight to .input state since the
    /// /drills/request endpoint already creates the attempt server-side.
    init(service: DrillService = .shared, preloadedDrill: DrillTodayResponse, preloadedAttemptId: String) {
        self.service = service
        self.todayDrill = preloadedDrill
        self.attemptId = preloadedAttemptId
        self.startedAt = Date()
        self.state = .input
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

    /// Submit the drill and poll for the graded result.
    /// POSTs to /submit, then polls /result every 2 sec for up to 30 sec (15 attempts).
    func submit(_ submission: DrillSubmission) async {
        guard let drill = todayDrill else { return }
        guard let subtype = todayDrill?.drillSubtype else { return }

        state = .submitting

        let body = DrillSubmitBody(drillSubtype: subtype, submission: submission)

        do {
            _ = try await service.submitDrill(bundleId: drill.bundleId, body: body)
            // Fire submit event before polling so we capture it even if polling fails.
            let elapsed = Int(Date().timeIntervalSince(startedAt ?? Date()))
            DrillAnalytics.trackSubmitted(drill: drill, timeTakenSeconds: elapsed)
        } catch {
            lastError = "Failed to submit: \(error.localizedDescription)"
            state = .error(lastError ?? "submit failed")
            return
        }

        // Poll for result: every 2 sec, up to 30 sec (15 attempts).
        // Backend grader target latency is ~8 sec for non-refactor drills, so
        // we should usually get a graded result within 2-3 polls.
        let maxAttempts = 15
        let pollIntervalNs: UInt64 = 2 * 1_000_000_000

        for attempt in 0..<maxAttempts {
            // Brief delay before first poll too — grading rarely returns within 1 sec
            try? await Task.sleep(nanoseconds: pollIntervalNs)

            do {
                let result = try await service.pollResult(bundleId: drill.bundleId)
                switch result {
                case .graded(let graded):
                    state = .result(grade: graded)
                    return
                case .pending:
                    continue
                }
            } catch {
                // Transient failure — log and retry up to maxAttempts
                // Don't bail on the first network blip
                if attempt == maxAttempts - 1 {
                    lastError = "Grading is taking longer than expected. Pull down to refresh in a few seconds."
                    state = .error(lastError ?? "polling timed out")
                    return
                }
            }
        }

        lastError = "Grading took longer than 30 seconds. Try again."
        state = .error(lastError ?? "polling timeout")
    }

    var timeRemaining: TimeInterval? {
        guard let started = startedAt, let drill = todayDrill else { return nil }
        let budgetSeconds = TimeInterval(drill.timeBudgetMinutes * 60)
        let elapsed = Date().timeIntervalSince(started)
        return max(0, budgetSeconds - elapsed)
    }
}
