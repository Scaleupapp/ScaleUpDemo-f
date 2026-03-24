import Foundation

// MARK: - Daily Challenge

struct DailyChallenge: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let topic: String
    let date: String
    let status: String
    let participantCount: Int
    let timeLimitSeconds: Int?
    let activatesAt: String?
    let closesAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, date, status, participantCount, timeLimitSeconds, activatesAt, closesAt
    }
}

// MARK: - Challenge Start Response

struct ChallengeStartResponse: Codable, Sendable {
    let attemptId: String
    let questions: [ChallengeQuestion]
    let timeLimitSeconds: Int?
}

struct ChallengeQuestion: Codable, Sendable, Identifiable {
    let questionIndex: Int
    let questionText: String
    let questionType: String
    let concept: String?
    let options: [ChallengeOption]

    var id: Int { questionIndex }
}

struct ChallengeOption: Codable, Sendable, Hashable {
    let label: String
    let text: String
}

// MARK: - Challenge Results

struct ChallengeResult: Codable, Sendable {
    let rawScore: Double
    let handicappedScore: Double
    let timeTaken: Double
    let isPersonalBest: Bool
    let correct: Int
    let total: Int
    let previousBest: Double
}

// MARK: - Weekly Leaderboard

struct WeeklyLeaderboard: Codable, Sendable {
    let id: String?
    let topic: String
    let weekStart: String
    let weekEnd: String
    let entries: [LeaderboardEntry]
    let finalized: Bool
    let participantCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, weekStart, weekEnd, entries, finalized, participantCount
    }
}

struct LeaderboardEntry: Codable, Sendable, Identifiable {
    let userId: LeaderboardUser
    let totalHandicappedScore: Double
    let challengesCompleted: Int
    let bestDayScore: Double
    let rank: Int?
    let percentile: Double?

    var id: String { userId.id }
}

struct LeaderboardUser: Codable, Sendable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let username: String?
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture
    }

    var displayName: String {
        if let first = firstName, let last = lastName { return "\(first) \(last)" }
        return username ?? "Player"
    }
}

// MARK: - Competition Profile

struct CompetitionProfile: Codable, Sendable {
    let userId: String?
    let personalBests: [String: PersonalBest]?
    let totalChallengesCompleted: Int
    let currentChallengeStreak: Int
    let longestChallengeStreak: Int
    let titlesEarned: [CompetitionTitle]?
}

struct PersonalBest: Codable, Sendable {
    let bestDailyScore: Double?
    let bestDailyDate: String?
    let bestWeeklyScore: Double?
    let bestWeeklyWeekStart: String?
}

struct CompetitionTitle: Codable, Sendable {
    let title: String
    let earnedAt: String
    let topic: String
}

// MARK: - Competition Stats

struct CompetitionStats: Codable, Sendable {
    let challengeStreak: Int
    let percentile: Double?
    let challengesThisWeek: Int
    let personalBests: [String: PersonalBest]?
    let todayCompleted: Int
    let todayTotal: Int
}

// MARK: - Live Event

struct LiveEvent: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let topic: String
    let scheduledAt: String
    let status: String
    let participantCount: Int
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, scheduledAt, status, participantCount, startedAt, completedAt
    }

    static func == (lhs: LiveEvent, rhs: LiveEvent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LobbyJoinResponse: Codable, Sendable {
    let alreadyJoined: Bool
    let participantCount: Int
}

struct LobbyState: Codable, Sendable {
    let status: String
    let participantCount: Int
    let scheduledAt: String
    let topic: String
}

struct LiveQuestionResponse: Codable, Sendable {
    let questionIndex: Int?
    let questionText: String?
    let questionType: String?
    let difficulty: String?
    let options: [ChallengeOption]?
    let timeLimit: Int?
    let timeRemaining: Double?
    let totalQuestions: Int?
    let eventComplete: Bool
}

struct LiveQuestionResults: Codable, Sendable {
    let correctPercentage: Int
    let totalAnswered: Int
}

struct LiveEventResults: Codable, Sendable {
    let event: LiveEventWithLeaderboard
    let attempt: LiveEventAttemptResult?
}

struct LiveEventWithLeaderboard: Codable, Sendable {
    let id: String
    let topic: String
    let leaderboard: [LiveLeaderboardEntry]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case topic, leaderboard
    }
}

struct LiveLeaderboardEntry: Codable, Sendable, Identifiable {
    let userId: LeaderboardUser
    let handicappedScore: Double
    let rawScore: Double
    let rank: Int

    var id: String { userId.id }
}

struct LiveEventAttemptResult: Codable, Sendable {
    let rawScore: Double?
    let handicappedScore: Double?
    let timeTaken: Double?
    let rank: Int?
}

// MARK: - All-Time Leaderboard

struct AllTimeEntry: Codable, Sendable, Identifiable {
    let userId: LeaderboardUser
    let totalScore: Double
    let totalChallenges: Int
    let rank: Int

    var id: String { userId.id }
}

struct AllTimeLeaderboardResponse: Codable, Sendable {
    let entries: [AllTimeEntry]
    let topic: String
}
