import Foundation

// MARK: - Analytics Event

/// Strongly-typed analytics events that represent meaningful user
/// actions throughout the app.
///
/// Each case carries the minimum context needed for segmentation.
/// The computed `name` and `parameters` properties produce the
/// flat key/value representation expected by analytics backends
/// (Firebase Analytics, Mixpanel, Amplitude, etc.).
enum AnalyticsEvent {

    // MARK: - Auth

    case signUp(method: String)
    case signIn(method: String)
    case signOut

    // MARK: - Content

    case contentViewed(id: String, type: String)
    case contentCompleted(id: String, duration: Int)
    case contentLiked(id: String)
    case contentSaved(id: String)

    // MARK: - Quiz

    case quizStarted(id: String, type: String)
    case quizCompleted(id: String, score: Double)

    // MARK: - Journey

    case journeyGenerated(objectiveType: String)
    case dailyPlanCompleted(week: Int, day: Int)

    // MARK: - Social

    case userFollowed(userId: String)
    case playlistCreated

    // MARK: - Navigation

    case screenViewed(name: String)
    case tabSwitched(tab: String)

    // MARK: - Event Name

    /// The snake_case event name sent to the analytics backend.
    var name: String {
        switch self {
        // Auth
        case .signUp:                return "sign_up"
        case .signIn:                return "sign_in"
        case .signOut:               return "sign_out"

        // Content
        case .contentViewed:         return "content_viewed"
        case .contentCompleted:      return "content_completed"
        case .contentLiked:          return "content_liked"
        case .contentSaved:          return "content_saved"

        // Quiz
        case .quizStarted:           return "quiz_started"
        case .quizCompleted:         return "quiz_completed"

        // Journey
        case .journeyGenerated:      return "journey_generated"
        case .dailyPlanCompleted:    return "daily_plan_completed"

        // Social
        case .userFollowed:          return "user_followed"
        case .playlistCreated:       return "playlist_created"

        // Navigation
        case .screenViewed:          return "screen_viewed"
        case .tabSwitched:           return "tab_switched"
        }
    }

    // MARK: - Event Parameters

    /// Key-value parameters associated with this event.
    var parameters: [String: Any] {
        switch self {
        // Auth
        case .signUp(let method):
            return ["method": method]
        case .signIn(let method):
            return ["method": method]
        case .signOut:
            return [:]

        // Content
        case .contentViewed(let id, let type):
            return ["content_id": id, "content_type": type]
        case .contentCompleted(let id, let duration):
            return ["content_id": id, "duration_seconds": duration]
        case .contentLiked(let id):
            return ["content_id": id]
        case .contentSaved(let id):
            return ["content_id": id]

        // Quiz
        case .quizStarted(let id, let type):
            return ["quiz_id": id, "quiz_type": type]
        case .quizCompleted(let id, let score):
            return ["quiz_id": id, "score": score]

        // Journey
        case .journeyGenerated(let objectiveType):
            return ["objective_type": objectiveType]
        case .dailyPlanCompleted(let week, let day):
            return ["week": week, "day": day]

        // Social
        case .userFollowed(let userId):
            return ["followed_user_id": userId]
        case .playlistCreated:
            return [:]

        // Navigation
        case .screenViewed(let name):
            return ["screen_name": name]
        case .tabSwitched(let tab):
            return ["tab_name": tab]
        }
    }
}
