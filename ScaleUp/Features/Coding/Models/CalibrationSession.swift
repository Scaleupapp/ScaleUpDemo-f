import Foundation
import Observation

@Observable
@MainActor
final class CalibrationSession {
    enum State: Equatable {
        case loading
        case inProgress(stepIndex: Int)  // 0..2
        case submitting
        case result(CalibrationResultResponse)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.submitting, .submitting):
                return true
            case (.inProgress(let a), .inProgress(let b)):
                return a == b
            case (.result(let a), .result(let b)):
                return a.calibrationId == b.calibrationId
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: State = .loading
    var calibrationId: String?
    var drills: [CalibrationDrill] = []

    /// Per-step submissions, indexed by stepIndex. May contain `nil` until the
    /// learner completes that step. When all 3 are non-nil we submit.
    var submissions: [DrillSubmission?] = [nil, nil, nil]

    private let service: DrillService

    init(service: DrillService = .shared) {
        self.service = service
    }

    func start() async {
        state = .loading
        do {
            let started = try await service.startCalibration()
            calibrationId = started.calibrationId
            drills = started.drills
            // Defensive: backend should return exactly 3 in Phase A
            if drills.count != 3 {
                state = .error("Calibration returned \(drills.count) drills; expected 3.")
                return
            }
            submissions = Array(repeating: nil, count: drills.count)
            state = .inProgress(stepIndex: 0)
        } catch DrillServiceError.calibrationRequired,
                DrillServiceError.noDrillAvailable {
            state = .error("Calibration isn't available right now. Please try again later.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Called by the per-step input view when the learner submits that step.
    /// Buffers the submission locally and either advances to the next step or
    /// (after step 3) batches all 3 to the server.
    func submitStep(_ submission: DrillSubmission) async {
        guard case .inProgress(let stepIndex) = state else { return }
        guard stepIndex < submissions.count else { return }

        submissions[stepIndex] = submission

        if stepIndex + 1 < drills.count {
            state = .inProgress(stepIndex: stepIndex + 1)
        } else {
            await submitAllAndPoll()
        }
    }

    private func submitAllAndPoll() async {
        guard let calibrationId = calibrationId else {
            state = .error("Missing calibration id")
            return
        }

        // Build the batch body — submissions must match drill order
        let batched: [CalibrationDrillSubmission] = zip(drills, submissions).compactMap { drill, submission in
            guard let submission = submission else { return nil }
            return CalibrationDrillSubmission(
                drillSubtype: drill.drillSubtype,
                attemptId: drill.attemptId,
                submission: submission
            )
        }

        guard batched.count == drills.count else {
            state = .error("Missing submissions for some steps.")
            return
        }

        state = .submitting

        do {
            _ = try await service.submitCalibration(
                calibrationId: calibrationId,
                body: CalibrationSubmitBody(submissions: batched)
            )
        } catch {
            state = .error("Failed to submit: \(error.localizedDescription)")
            return
        }

        // Poll for result. Calibration grades 3 drills server-side, so latency
        // is ~3x a regular drill = ~24 sec. Poll every 3 sec, up to 60 sec.
        let maxAttempts = 20
        let pollIntervalNs: UInt64 = 3 * 1_000_000_000

        for attempt in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: pollIntervalNs)

            do {
                let result = try await service.pollCalibrationResult(calibrationId: calibrationId)
                // status: 'pending' | 'partial' | 'graded'
                if result.status == "graded" {
                    state = .result(result)
                    return
                }
            } catch {
                if attempt == maxAttempts - 1 {
                    state = .error("Grading timed out: \(error.localizedDescription)")
                    return
                }
            }
        }

        state = .error("Calibration grading took longer than expected. Check back in a few minutes.")
    }

    var currentDrill: CalibrationDrill? {
        guard case .inProgress(let i) = state else { return nil }
        return drills.indices.contains(i) ? drills[i] : nil
    }

    var currentStepNumber: Int? {
        guard case .inProgress(let i) = state else { return nil }
        return i + 1
    }
}
