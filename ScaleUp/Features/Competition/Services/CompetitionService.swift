import Foundation

// MARK: - Competition Endpoints

enum CompetitionEndpoints: Endpoint {
    case todayChallenges
    case challengeDetail(id: String)
    case startChallenge(id: String)
    case submitAnswer(id: String)
    case completeChallenge(id: String)
    case challengeResults(id: String)
    case weeklyLeaderboard(topic: String?)
    case allTimeLeaderboard(topic: String?)
    case primaryObjectiveTopic
    case competitionProfile
    case competitionStats
    case upcomingEvents
    case eventDetail(id: String)
    case joinLobby(id: String)
    case lobbyState(id: String)
    case currentQuestion(id: String)
    case submitLiveAnswer(id: String)
    case questionResults(id: String, questionIndex: Int)
    case eventResults(id: String)
    case challengeReview(id: String)

    var path: String {
        switch self {
        case .todayChallenges: return "/competition/challenges/today"
        case .challengeDetail(let id): return "/competition/challenges/\(id)"
        case .startChallenge(let id): return "/competition/challenges/\(id)/start"
        case .submitAnswer(let id): return "/competition/challenges/\(id)/answer"
        case .completeChallenge(let id): return "/competition/challenges/\(id)/complete"
        case .challengeResults(let id): return "/competition/challenges/\(id)/results"
        case .weeklyLeaderboard: return "/competition/leaderboard/weekly"
        case .allTimeLeaderboard: return "/competition/leaderboard/alltime"
        case .primaryObjectiveTopic: return "/competition/objective-topic"
        case .competitionProfile: return "/competition/profile"
        case .competitionStats: return "/competition/stats"
        case .upcomingEvents: return "/competition/live-events/upcoming"
        case .eventDetail(let id): return "/competition/live-events/\(id)"
        case .joinLobby(let id): return "/competition/live-events/\(id)/join"
        case .lobbyState(let id): return "/competition/live-events/\(id)/lobby"
        case .currentQuestion(let id): return "/competition/live-events/\(id)/question"
        case .submitLiveAnswer(let id): return "/competition/live-events/\(id)/answer"
        case .questionResults(let id, _): return "/competition/live-events/\(id)/question-results"
        case .eventResults(let id): return "/competition/live-events/\(id)/results"
        case .challengeReview(let id): return "/competition/challenges/\(id)/review"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .startChallenge, .completeChallenge, .joinLobby:
            return .post
        case .submitAnswer, .submitLiveAnswer:
            return .put
        default:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .questionResults(_, let qi):
            return [URLQueryItem(name: "questionIndex", value: "\(qi)")]
        case .weeklyLeaderboard(let topic):
            if let t = topic { return [URLQueryItem(name: "topic", value: t)] }
            return nil
        case .allTimeLeaderboard(let topic):
            if let t = topic { return [URLQueryItem(name: "topic", value: t)] }
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Request Bodies

struct ChallengeAnswerBody: Encodable, Sendable {
    let questionIndex: Int
    let selectedAnswer: String
    let timeSpent: Double
}

// MARK: - Competition Service

actor CompetitionService {
    private let api = APIClient.shared

    // Daily Challenges
    func fetchTodayChallenges() async throws -> [DailyChallenge] {
        try await api.request(CompetitionEndpoints.todayChallenges)
    }

    func startChallenge(id: String) async throws -> ChallengeStartResponse {
        try await api.request(CompetitionEndpoints.startChallenge(id: id))
    }

    func submitAnswer(challengeId: String, questionIndex: Int, selectedAnswer: String, timeSpent: Double) async throws -> [String: Int] {
        let body = ChallengeAnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeSpent: timeSpent)
        return try await api.request(CompetitionEndpoints.submitAnswer(id: challengeId), body: body)
    }

    func completeChallenge(id: String) async throws -> ChallengeResult {
        try await api.request(CompetitionEndpoints.completeChallenge(id: id))
    }

    // Leaderboard
    func fetchWeeklyLeaderboard(topic: String? = nil) async throws -> WeeklyLeaderboard {
        try await api.request(CompetitionEndpoints.weeklyLeaderboard(topic: topic))
    }

    func fetchAllTimeLeaderboard(topic: String? = nil) async throws -> AllTimeLeaderboardResponse {
        try await api.request(CompetitionEndpoints.allTimeLeaderboard(topic: topic))
    }

    func fetchPrimaryObjectiveTopic() async throws -> String? {
        struct ObjectiveResponse: Codable { let topic: String? }
        let result: ObjectiveResponse = try await api.request(CompetitionEndpoints.primaryObjectiveTopic)
        return result.topic
    }

    // Profile & Stats
    func fetchCompetitionProfile() async throws -> CompetitionProfile {
        try await api.request(CompetitionEndpoints.competitionProfile)
    }

    func fetchCompetitionStats() async throws -> CompetitionStats {
        try await api.request(CompetitionEndpoints.competitionStats)
    }

    // Live Events
    func fetchUpcomingEvents() async throws -> [LiveEvent] {
        try await api.request(CompetitionEndpoints.upcomingEvents)
    }

    func joinLobby(eventId: String) async throws -> LobbyJoinResponse {
        try await api.request(CompetitionEndpoints.joinLobby(id: eventId))
    }

    func joinLiveEvent(id: String) async throws -> LobbyJoinResponse {
        try await api.request(CompetitionEndpoints.joinLobby(id: id))
    }

    func fetchLobbyState(eventId: String) async throws -> LobbyState {
        try await api.request(CompetitionEndpoints.lobbyState(id: eventId))
    }

    func fetchCurrentQuestion(eventId: String) async throws -> LiveQuestionResponse {
        try await api.request(CompetitionEndpoints.currentQuestion(id: eventId))
    }

    func submitLiveAnswer(eventId: String, questionIndex: Int, selectedAnswer: String, timeSpent: Double) async throws -> [String: Int] {
        let body = ChallengeAnswerBody(questionIndex: questionIndex, selectedAnswer: selectedAnswer, timeSpent: timeSpent)
        return try await api.request(CompetitionEndpoints.submitLiveAnswer(id: eventId), body: body)
    }

    func fetchQuestionResults(eventId: String, questionIndex: Int) async throws -> LiveQuestionResults {
        try await api.request(CompetitionEndpoints.questionResults(id: eventId, questionIndex: questionIndex))
    }

    func fetchEventResults(eventId: String) async throws -> LiveEventResults {
        try await api.request(CompetitionEndpoints.eventResults(id: eventId))
    }

    func fetchChallengeReview(challengeId: String) async throws -> ChallengeReview {
        try await api.request(CompetitionEndpoints.challengeReview(id: challengeId))
    }
}
