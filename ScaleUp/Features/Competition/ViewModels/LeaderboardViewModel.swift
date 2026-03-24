import SwiftUI

@Observable
@MainActor
final class LeaderboardViewModel {

    // MARK: - State

    var stats: CompetitionStats? = nil
    var weeklyBoard: WeeklyLeaderboard? = nil
    var isLoading = false
    var error: String? = nil

    private let service = CompetitionService()

    // MARK: - Load Stats

    func loadStats() async {
        isLoading = true
        error = nil

        do {
            stats = try await service.fetchCompetitionStats()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load Leaderboard

    func loadLeaderboard(topic: String? = nil) async {
        isLoading = true
        error = nil

        do {
            weeklyBoard = try await service.fetchWeeklyLeaderboard(topic: topic)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load All

    func loadAll() async {
        isLoading = true
        error = nil

        async let statsTask: CompetitionStats? = {
            try? await self.service.fetchCompetitionStats()
        }()
        async let boardTask: WeeklyLeaderboard? = {
            try? await self.service.fetchWeeklyLeaderboard()
        }()

        let (fetchedStats, fetchedBoard) = await (statsTask, boardTask)
        stats = fetchedStats
        weeklyBoard = fetchedBoard

        isLoading = false
    }
}
