import SwiftUI

/// Routes a v2 task tap into the correct v1 detail screen.
///
/// V2HomeView, V2YouView, and the Compass "Start" action all send users through
/// this single router so the rules live in one place. Falls back to a generic
/// "task detail unavailable" sheet when the task lacks a payload.
@MainActor
@Observable
final class V2TaskRouter {

    /// Active route — driving sheet/cover presentation in V2RootView.
    var route: Route?

    enum Route: Identifiable, Equatable {
        case content(contentId: String, title: String)
        case quiz(quizId: String)
        case interview(scenarioId: String?)
        case external(url: URL)
        case unavailable(message: String)

        var id: String {
            switch self {
            case .content(let id, _):  return "content-\(id)"
            case .quiz(let id):        return "quiz-\(id)"
            case .interview(let id):   return "interview-\(id ?? "default")"
            case .external(let url):   return "external-\(url.absoluteString)"
            case .unavailable(let m):  return "unavailable-\(m)"
            }
        }
    }

    /// Dispatch — call from Home Begin / alt rows / Compass Start.
    func open(taskType: String, payload: V2HomeData.Payload?, title: String) {
        switch taskType {
        case "watch", "listen", "read":
            if let id = payload?.contentId {
                route = .content(contentId: id, title: title)
            } else {
                route = .unavailable(message: "This task's content isn't linked yet.")
            }

        case "quiz":
            if let id = payload?.quizId {
                route = .quiz(quizId: id)
            } else {
                route = .unavailable(message: "Quiz isn't ready yet. Check back soon.")
            }

        case "interview":
            route = .interview(scenarioId: payload?.interviewId)

        case "external":
            if let urlStr = payload?.url, let u = URL(string: urlStr) {
                route = .external(url: u)
            } else {
                route = .unavailable(message: "External link unavailable.")
            }

        case "compete", "mock_exam", "reflection", "notes_create", "conversation":
            // Phase 2: route to dedicated v2 detail screens. For now, show stub.
            route = .unavailable(message: "Coming next: dedicated \(taskType) screen.")

        default:
            route = .unavailable(message: "Unknown task type.")
        }
    }

    func close() { route = nil }
}
