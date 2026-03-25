import SwiftUI

@Observable
@MainActor
final class LeaderboardViewModel {

    // MARK: - State

    var stats: CompetitionStats? = nil
    var weeklyBoard: WeeklyLeaderboard? = nil
    var allTimeEntries: [AllTimeEntry]? = nil
    var userObjectiveTopic: String? = nil
    var selectedTopic: String? = nil // nil = "All Topics" (global)
    var availableTopics: [(raw: String, display: String)] = []
    var isLoading = false
    var error: String? = nil

    private let service = CompetitionService()

    // MARK: - Load All (default: global leaderboard)

    func loadAll() async {
        isLoading = true
        error = nil

        // Load user's primary objective topic
        if userObjectiveTopic == nil {
            userObjectiveTopic = try? await service.fetchPrimaryObjectiveTopic()
        }

        // Build available topics from today's challenges
        let challenges = (try? await service.fetchTodayChallenges()) ?? []
        availableTopics = challenges.map { (raw: $0.topic, display: $0.formattedTitle) }

        // Default to global (nil = no topic filter)
        let topic = selectedTopic

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

    // MARK: - Switch Topic

    func switchTopic(_ topic: String?) async {
        selectedTopic = topic
        isLoading = true
        do {
            weeklyBoard = try await service.fetchWeeklyLeaderboard(topic: topic)
            allTimeEntries = nil // reset all-time when switching topics
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load Weekly

    func loadWeekly() async {
        isLoading = true
        do {
            weeklyBoard = try await service.fetchWeeklyLeaderboard(topic: selectedTopic)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load All Time

    func loadAllTime() async {
        isLoading = true
        do {
            let result = try await service.fetchAllTimeLeaderboard(topic: selectedTopic)
            allTimeEntries = result.entries
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helper

    private func titleCase(_ text: String) -> String {
        text.split(separator: " ").map { word in
            let lower = word.lowercased()
            return String(lower.prefix(1).uppercased() + lower.dropFirst())
        }.joined(separator: " ")
    }
}
