import SwiftUI

@Observable
@MainActor
final class LeaderboardViewModel {

    // MARK: - State

    var stats: CompetitionStats? = nil
    var weeklyBoard: WeeklyLeaderboard? = nil
    var allTimeEntries: [AllTimeEntry]? = nil
    var userObjectiveTopic: String? = nil
    var isLoading = false
    var error: String? = nil

    private let service = CompetitionService()

    // MARK: - Load All (default: user's objective topic)

    func loadAll() async {
        isLoading = true
        error = nil

        // Load user's primary objective topic first
        if userObjectiveTopic == nil {
            userObjectiveTopic = try? await service.fetchPrimaryObjectiveTopic()
        }

        let topic = userObjectiveTopic

        async let statsTask: CompetitionStats? = {
            try? await self.service.fetchCompetitionStats()
        }()
        async let boardTask: WeeklyLeaderboard? = {
            try? await self.service.fetchWeeklyLeaderboard(topic: topic)
        }()

        let (fetchedStats, fetchedBoard) = await (statsTask, boardTask)
        stats = fetchedStats
        weeklyBoard = fetchedBoard

        isLoading = false
    }

    // MARK: - Load Weekly

    func loadWeekly() async {
        isLoading = true
        do {
            weeklyBoard = try await service.fetchWeeklyLeaderboard(topic: userObjectiveTopic)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load All Time

    func loadAllTime() async {
        isLoading = true
        do {
            let result = try await service.fetchAllTimeLeaderboard(topic: userObjectiveTopic)
            allTimeEntries = result.entries
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
