import SwiftUI

// MARK: - Weekly Plan View Model

@Observable
final class WeeklyPlanViewModel {

    // MARK: - Published State

    var weeklyPlan: WeeklyPlan?
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let journeyService: JourneyService

    // MARK: - Init

    init(journeyService: JourneyService) {
        self.journeyService = journeyService
    }

    // MARK: - Computed Properties

    /// Number of completed days (non-rest days that have passed).
    var completedDays: Int {
        guard let weeklyPlan else { return 0 }
        return weeklyPlan.dailyAssignments.filter { !$0.isRestDay && $0.day < currentDayInWeek }.count
    }

    /// Number of remaining active (non-rest) days.
    var remainingDays: Int {
        guard let weeklyPlan else { return 0 }
        return weeklyPlan.dailyAssignments.filter { !$0.isRestDay && $0.day >= currentDayInWeek }.count
    }

    /// Total estimated minutes for the entire week.
    var totalMinutes: Int {
        guard let weeklyPlan else { return 0 }
        return weeklyPlan.dailyAssignments.reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Total active (non-rest) days in the week.
    var activeDays: Int {
        guard let weeklyPlan else { return 0 }
        return weeklyPlan.dailyAssignments.filter { !$0.isRestDay }.count
    }

    /// Current day of the week (1 = Monday, 7 = Sunday).
    var currentDayInWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert Sunday = 1 ... Saturday = 7 to Monday = 1 ... Sunday = 7
        return weekday == 1 ? 7 : weekday - 1
    }

    // MARK: - Load Week

    /// Fetches the weekly plan for the given week number.
    @MainActor
    func loadWeek(number: Int) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            self.weeklyPlan = try await journeyService.week(number: number)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }
}
