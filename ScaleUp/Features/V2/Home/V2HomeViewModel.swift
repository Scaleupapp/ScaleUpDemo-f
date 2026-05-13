import Foundation

// MARK: - V2 Home Data Models

/// Decoded shape from GET /api/v2/plan/today.
struct V2HomeData: Codable {
    let greeting: String
    let statusLine: String
    let objectiveLabel: String?
    let trajectory: Trajectory?
    let weekProgress: WeekProgress?
    let hero: Hero?
    let alternatives: [Alternative]
    let fallback: String?
    let message: String?

    struct Trajectory: Codable {
        let today: Int
        let in30Days: Int
        let atTargetDate: Int
        let targetReadiness: Int
        let timelineWeeks: Int
        let weeklyDelta: Int
        let onTrack: Bool
        let headline: String?
    }

    struct WeekProgress: Codable {
        let done: Int
        let total: Int
        let week: Int
        let totalWeeks: Int
    }

    struct Hero: Codable, Identifiable {
        let taskId: String?
        let taskType: String
        let icon: String
        let title: String
        let subtitle: String
        let durationMin: Int
        let difficulty: String
        let primaryTopic: String?
        let impact: Impact?

        var id: String { taskId ?? UUID().uuidString }
        var author: String { subtitle.isEmpty ? "ScaleUp" : subtitle }
        var whyText: String {
            if let i = impact, let from = i.expectedFrom, let to = i.expectedTo {
                return "\(i.whyText ?? "") After this, you'll be at ~\(to)%, up from \(from)%."
            }
            return impact?.whyText ?? "Plan-aligned for today."
        }

        struct Impact: Codable {
            let expectedFrom: Int?
            let expectedTo: Int?
            let expectedGain: Int?
            let whyText: String?
            let scope: String?
        }
    }

    struct Alternative: Codable, Identifiable {
        let taskId: String?
        let taskType: String
        let icon: String
        let title: String
        let durationMin: Int
        let primaryTopic: String?
        let reason: String

        var id: String { taskId ?? UUID().uuidString }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class V2HomeViewModel {
    var data: V2HomeData?
    var isLoading = false
    var error: String?
    var showAlternatives = false

    /// Set to true only in #Preview / debug builds. Production renders genuine
    /// empty/error states so testers see real personalized state.
    var usePreviewSample = false

    func load() async {
        if usePreviewSample {
            data = Self.sampleData
            return
        }
        isLoading = true
        error = nil
        do {
            let response: V2APIResponse<V2HomeData> = try await V2APIClient.shared.get("/plan/today")
            data = response.data
        } catch let e {
            self.error = Self.friendlyError(e)
            self.data = nil
        }
        isLoading = false
    }

    private static func friendlyError(_ e: Error) -> String {
        if let apiErr = e as? V2APIError {
            switch apiErr {
            case .invalidURL:         return "Couldn't reach ScaleUp. Check your connection."
            case .serverError(let s) where s == 401: return "Please sign in again."
            case .serverError(let s): return "Server issue (\(s)). Try again in a moment."
            case .decodingFailed:     return "We got a response but couldn't read it."
            }
        }
        return "Couldn't load your day. Pull to refresh."
    }

    static var sampleData: V2HomeData {
        .init(
            greeting: "Hi, Nirpeksh.",
            statusLine: "You're on track for August. 74% ready, 11 weeks to go.",
            objectiveLabel: "SDE @ Google · 6mo",
            trajectory: .init(
                today: 74, in30Days: 80, atTargetDate: 85,
                targetReadiness: 80, timelineWeeks: 24, weeklyDelta: 6,
                onTrack: true, headline: nil
            ),
            weekProgress: .init(done: 3, total: 7, week: 11, totalWeeks: 24),
            hero: .init(
                taskId: "sample-hero",
                taskType: "watch",
                icon: "📺",
                title: "Dynamic Programming",
                subtitle: "Memoization deep-dive",
                durationMin: 22,
                difficulty: "hard",
                primaryTopic: "dp",
                impact: .init(
                    expectedFrom: 30,
                    expectedTo: 36,
                    expectedGain: 6,
                    whyText: "Closes your top gap.",
                    scope: "topic"
                )
            ),
            alternatives: [
                .init(taskId: "alt-1", taskType: "quiz", icon: "🧠",
                      title: "Quick quiz · Last week's funnel topics",
                      durationMin: 5, primaryTopic: "funnel",
                      reason: "Quick win to warm up"),
                .init(taskId: "alt-2", taskType: "interview", icon: "🎙️",
                      title: "Practice behavioral interview",
                      durationMin: 30, primaryTopic: "behavioral",
                      reason: "For Google L4 · you're ready"),
                .init(taskId: "alt-3", taskType: "notes_create", icon: "📝",
                      title: "Recap your Week 2 notes",
                      durationMin: 10, primaryTopic: "review",
                      reason: "Spaced repetition due"),
            ],
            fallback: nil,
            message: nil
        )
    }
}
