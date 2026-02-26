import SwiftUI

// MARK: - Journey View Model

@Observable
final class JourneyViewModel {

    // MARK: - Published State

    var journey: Journey?
    var todayPlan: TodayPlan?
    var isLoading: Bool = false
    var error: APIError?
    var showGenerateSheet: Bool = false

    // MARK: - Dependencies

    private let journeyService: JourneyService

    // MARK: - Init

    init(journeyService: JourneyService) {
        self.journeyService = journeyService
    }

    // MARK: - Computed Properties

    var hasJourney: Bool { journey != nil }

    var isPaused: Bool { journey?.status == .paused }

    var isActive: Bool { journey?.status == .active }

    var currentPhaseIndex: Int {
        guard let journey else { return 0 }
        return journey.currentPhaseIndex
    }

    // MARK: - Load Journey

    /// Loads the user's active journey and today's plan.
    /// Fetches journey first — if nil (no journey), skips today's plan.
    @MainActor
    func loadJourney() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let fetchedJourney = try await journeyService.getJourney()

            if let fetchedJourney {
                self.journey = fetchedJourney
                // Only fetch today's plan if a journey exists
                do {
                    self.todayPlan = try await journeyService.today()
                } catch {
                    // Today's plan failure is non-fatal
                    self.todayPlan = nil
                }
            } else {
                // No journey exists for this user
                self.journey = nil
                self.todayPlan = nil
            }
        } catch let apiError as APIError {
            if case .notFound = apiError {
                self.journey = nil
                self.todayPlan = nil
            } else {
                self.error = apiError
            }
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes journey data without showing the full loading state.
    @MainActor
    func refresh() async {
        error = nil

        do {
            let fetchedJourney = try await journeyService.getJourney()

            if let fetchedJourney {
                self.journey = fetchedJourney
                do {
                    self.todayPlan = try await journeyService.today()
                } catch {
                    self.todayPlan = nil
                }
            } else {
                self.journey = nil
                self.todayPlan = nil
            }
        } catch let apiError as APIError {
            if case .notFound = apiError {
                self.journey = nil
                self.todayPlan = nil
            } else {
                self.error = apiError
            }
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Pause Journey

    /// Pauses the currently active journey.
    @MainActor
    func pauseJourney() async {
        error = nil

        do {
            try await journeyService.pause()
            await loadJourney()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Resume Journey

    /// Resumes a paused journey.
    @MainActor
    func resumeJourney() async {
        error = nil

        do {
            try await journeyService.resume()
            await loadJourney()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }
}
