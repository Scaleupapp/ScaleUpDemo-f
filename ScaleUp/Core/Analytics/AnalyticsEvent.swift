import Foundation

// MARK: - Analytics Event
//
// Single source of truth for every event tracked in the product.
// Adding a new event = one case here. Autocomplete tells you every event that exists.
// Snake_case names keep the Mixpanel dashboard consistent and queryable.

enum AnalyticsEvent {

    // MARK: Phase 1 — Activation Funnel

    case appOpened
    case sessionStarted
    case sessionEnded(durationSeconds: Int)
    case dailyActive
    case screenViewed(name: String)
    case tabSwitched(from: String, to: String)
    case phoneEntered
    case otpRequested
    case otpFailed(reason: String)
    case otpVerified
    case registrationCompleted(method: RegistrationMethod)
    case onboardingObjectiveSelected(objective: String)
    case onboardingCompleted
    case firstContentViewed(contentId: String, topic: String?)

    // MARK: Phase 2 — Content Engagement

    case contentStarted(contentId: String, topic: String?, contentType: String, source: String)
    case contentCompleted(contentId: String, topic: String?, durationSeconds: Int)
    case contentAbandoned(contentId: String, abandonAtPercent: Int)
    case contentLiked(contentId: String)
    case contentSaved(contentId: String)
    case contentShared(contentId: String, destination: String)
    case contentRated(contentId: String, rating: Int)
    case commentPosted(contentId: String)

    // MARK: Phase 2 — Quiz Engagement

    case quizStarted(quizId: String, topic: String?, source: String)
    case quizQuestionAnswered(quizId: String, questionIndex: Int, correct: Bool?, timeToAnswerMs: Int)
    case quizCompleted(quizId: String, topic: String?, score: Int, totalQuestions: Int)
    case quizAbandoned(quizId: String, atQuestion: Int)

    // MARK: Phase 2 — Interview Engagement

    case interviewStarted(type: String, targetRole: String, difficulty: String)
    case interviewCompleted(sessionId: String, type: String, durationSeconds: Int)
    case interviewAbandoned(sessionId: String, atPhase: String)

    // MARK: Phase 2 — Learning Tools

    case noteCreated(fileFormat: String)
    case flashcardReviewed(deckId: String)
    case mindmapGenerated(contentId: String?)
    case audioSummaryPlayed(contentId: String?)
    case aiTutorMessageSent(contentId: String, messageLength: Int)
    case aiTutorConversationStarted(contentId: String)

    // MARK: Phase 3 — C2O Transitions (the business thesis)

    case contentToQuizTransition(contentId: String, quizId: String)
    case quizWeaknessToContent(quizId: String, contentId: String, topic: String?)
    case interviewGapToContent(sessionId: String, contentId: String)
    case quizScoreImproved(topic: String, fromScore: Int, toScore: Int)

    // MARK: Phase 3 — Retention Signals

    case streakMaintained(days: Int)
    case streakBroken(previousDays: Int)
    case streakMilestone(days: Int)

    // MARK: Phase 2 — Diagnostic

    case diagnosticStarted(flowType: String)
    case diagnosticSelfRatingSubmitted(attemptId: String)
    case diagnosticFinished(attemptId: String, durationSeconds: Int, score: Int)
    case diagnosticAbandoned(attemptId: String, atStep: String)

    // MARK: Phase 3 — Competition & Challenges

    case challengeStarted(challengeId: String, topic: String?)
    case challengeCompleted(challengeId: String, score: Int)
    case liveEventJoined(eventId: String)

    // MARK: Phase 4 — Features & Discovery

    case searchPerformed(queryLength: Int, resultsCount: Int)
    case recommendationClicked(contentId: String, position: Int)
    case objectiveSwitched(fromObjective: String?, toObjective: String)
    case featureFirstUsed(feature: String)
    case creatorFollowed(creatorId: String)
    case creatorUnfollowed(creatorId: String)
    case learningPathStarted(pathId: String)

    // MARK: Phase 4 — Friction & Errors

    case errorEncountered(endpoint: String, code: Int, message: String)
    case screenAbandoned(screen: String, timeOnScreenMs: Int)
    case networkTimeout(endpoint: String)

    // MARK: Event Name (sent to Mixpanel)

    var name: String {
        switch self {
        case .appOpened:                          return "app_opened"
        case .sessionStarted:                     return "session_started"
        case .sessionEnded:                       return "session_ended"
        case .dailyActive:                        return "daily_active"
        case .screenViewed:                       return "screen_viewed"
        case .tabSwitched:                        return "tab_switched"
        case .phoneEntered:                       return "phone_entered"
        case .otpRequested:                       return "otp_requested"
        case .otpFailed:                          return "otp_failed"
        case .otpVerified:                        return "otp_verified"
        case .registrationCompleted:              return "registration_completed"
        case .onboardingObjectiveSelected:        return "onboarding_objective_selected"
        case .onboardingCompleted:                return "onboarding_completed"
        case .firstContentViewed:                 return "first_content_viewed"

        case .contentStarted:                     return "content_started"
        case .contentCompleted:                   return "content_completed"
        case .contentAbandoned:                   return "content_abandoned"
        case .contentLiked:                       return "content_liked"
        case .contentSaved:                       return "content_saved"
        case .contentShared:                      return "content_shared"
        case .contentRated:                       return "content_rated"
        case .commentPosted:                      return "comment_posted"

        case .quizStarted:                        return "quiz_started"
        case .quizQuestionAnswered:               return "quiz_question_answered"
        case .quizCompleted:                      return "quiz_completed"
        case .quizAbandoned:                      return "quiz_abandoned"

        case .diagnosticStarted:                  return "diagnostic_started"
        case .diagnosticSelfRatingSubmitted:      return "diagnostic_self_rating_submitted"
        case .diagnosticFinished:                 return "diagnostic_finished"
        case .diagnosticAbandoned:                return "diagnostic_abandoned"

        case .interviewStarted:                   return "interview_started"
        case .interviewCompleted:                 return "interview_completed"
        case .interviewAbandoned:                 return "interview_abandoned"

        case .noteCreated:                        return "note_created"
        case .flashcardReviewed:                  return "flashcard_reviewed"
        case .mindmapGenerated:                   return "mindmap_generated"
        case .audioSummaryPlayed:                 return "audio_summary_played"
        case .aiTutorMessageSent:                 return "ai_tutor_message_sent"
        case .aiTutorConversationStarted:         return "ai_tutor_conversation_started"

        case .contentToQuizTransition:            return "content_to_quiz_transition"
        case .quizWeaknessToContent:              return "quiz_weakness_to_content"
        case .interviewGapToContent:              return "interview_gap_to_content"
        case .quizScoreImproved:                  return "quiz_score_improved"

        case .streakMaintained:                   return "streak_maintained"
        case .streakBroken:                       return "streak_broken"
        case .streakMilestone:                    return "streak_milestone"

        case .challengeStarted:                   return "challenge_started"
        case .challengeCompleted:                 return "challenge_completed"
        case .liveEventJoined:                    return "live_event_joined"

        case .searchPerformed:                    return "search_performed"
        case .recommendationClicked:              return "recommendation_clicked"
        case .objectiveSwitched:                  return "objective_switched"
        case .featureFirstUsed:                   return "feature_first_used"
        case .creatorFollowed:                    return "creator_followed"
        case .creatorUnfollowed:                  return "creator_unfollowed"
        case .learningPathStarted:                return "learning_path_started"

        case .errorEncountered:                   return "error_encountered"
        case .screenAbandoned:                    return "screen_abandoned"
        case .networkTimeout:                     return "network_timeout"
        }
    }

    // MARK: Event-specific Properties

    var properties: [String: Any] {
        switch self {
        case .appOpened, .sessionStarted, .dailyActive, .phoneEntered,
             .otpRequested, .otpVerified, .onboardingCompleted:
            return [:]

        case .sessionEnded(let durationSeconds):
            return ["duration_seconds": durationSeconds]

        case .screenViewed(let name):
            return ["screen_name": name]

        case .tabSwitched(let from, let to):
            return ["from_tab": from, "to_tab": to]

        case .otpFailed(let reason):
            return ["reason": reason]

        case .registrationCompleted(let method):
            return ["method": method.rawValue]

        case .onboardingObjectiveSelected(let objective):
            return ["objective": objective]

        case .firstContentViewed(let contentId, let topic):
            var props: [String: Any] = ["content_id": contentId]
            if let topic { props["topic"] = topic }
            return props

        case .contentStarted(let contentId, let topic, let contentType, let source):
            var props: [String: Any] = [
                "content_id": contentId,
                "content_type": contentType,
                "source": source
            ]
            if let topic { props["topic"] = topic }
            return props

        case .contentCompleted(let contentId, let topic, let durationSeconds):
            var props: [String: Any] = [
                "content_id": contentId,
                "duration_seconds": durationSeconds
            ]
            if let topic { props["topic"] = topic }
            return props

        case .contentAbandoned(let contentId, let abandonAtPercent):
            return ["content_id": contentId, "abandon_at_percent": abandonAtPercent]

        case .contentLiked(let contentId),
             .contentSaved(let contentId),
             .commentPosted(let contentId):
            return ["content_id": contentId]

        case .contentShared(let contentId, let destination):
            return ["content_id": contentId, "destination": destination]

        case .contentRated(let contentId, let rating):
            return ["content_id": contentId, "rating": rating]

        case .quizStarted(let quizId, let topic, let source):
            var props: [String: Any] = ["quiz_id": quizId, "source": source]
            if let topic { props["topic"] = topic }
            return props

        case .quizQuestionAnswered(let quizId, let questionIndex, let correct, let timeToAnswerMs):
            var props: [String: Any] = [
                "quiz_id": quizId,
                "question_index": questionIndex,
                "time_to_answer_ms": timeToAnswerMs
            ]
            if let correct { props["correct"] = correct }
            return props

        case .quizCompleted(let quizId, let topic, let score, let totalQuestions):
            var props: [String: Any] = [
                "quiz_id": quizId,
                "score": score,
                "total_questions": totalQuestions
            ]
            if let topic { props["topic"] = topic }
            return props

        case .quizAbandoned(let quizId, let atQuestion):
            return ["quiz_id": quizId, "at_question": atQuestion]

        case .diagnosticStarted(let flowType):
            return ["flow_type": flowType]

        case .diagnosticSelfRatingSubmitted(let attemptId):
            return ["attempt_id": attemptId]

        case .diagnosticFinished(let attemptId, let durationSeconds, let score):
            return ["attempt_id": attemptId, "duration_seconds": durationSeconds, "score": score]

        case .diagnosticAbandoned(let attemptId, let atStep):
            return ["attempt_id": attemptId, "at_step": atStep]

        case .interviewStarted(let type, let targetRole, let difficulty):
            return ["interview_type": type, "target_role": targetRole, "difficulty": difficulty]

        case .interviewCompleted(let sessionId, let type, let durationSeconds):
            return [
                "session_id": sessionId,
                "interview_type": type,
                "duration_seconds": durationSeconds
            ]

        case .interviewAbandoned(let sessionId, let atPhase):
            return ["session_id": sessionId, "at_phase": atPhase]

        case .noteCreated(let fileFormat):
            return ["file_format": fileFormat]

        case .flashcardReviewed(let deckId):
            return ["deck_id": deckId]

        case .mindmapGenerated(let contentId):
            var props: [String: Any] = [:]
            if let contentId { props["content_id"] = contentId }
            return props

        case .audioSummaryPlayed(let contentId):
            var props: [String: Any] = [:]
            if let contentId { props["content_id"] = contentId }
            return props

        case .aiTutorMessageSent(let contentId, let messageLength):
            return ["content_id": contentId, "message_length": messageLength]

        case .aiTutorConversationStarted(let contentId):
            return ["content_id": contentId]

        case .contentToQuizTransition(let contentId, let quizId):
            return ["content_id": contentId, "quiz_id": quizId]

        case .quizWeaknessToContent(let quizId, let contentId, let topic):
            var props: [String: Any] = ["quiz_id": quizId, "content_id": contentId]
            if let topic { props["topic"] = topic }
            return props

        case .interviewGapToContent(let sessionId, let contentId):
            return ["session_id": sessionId, "content_id": contentId]

        case .quizScoreImproved(let topic, let fromScore, let toScore):
            return ["topic": topic, "from_score": fromScore, "to_score": toScore]

        case .streakMaintained(let days):
            return ["streak_days": days]

        case .streakBroken(let previousDays):
            return ["previous_days": previousDays]

        case .streakMilestone(let days):
            return ["streak_days": days]

        case .challengeStarted(let challengeId, let topic):
            var props: [String: Any] = ["challenge_id": challengeId]
            if let topic { props["topic"] = topic }
            return props

        case .challengeCompleted(let challengeId, let score):
            return ["challenge_id": challengeId, "score": score]

        case .liveEventJoined(let eventId):
            return ["event_id": eventId]

        case .searchPerformed(let queryLength, let resultsCount):
            return ["query_length": queryLength, "results_count": resultsCount]

        case .recommendationClicked(let contentId, let position):
            return ["content_id": contentId, "position": position]

        case .objectiveSwitched(let fromObjective, let toObjective):
            var props: [String: Any] = ["to_objective": toObjective]
            if let fromObjective { props["from_objective"] = fromObjective }
            return props

        case .featureFirstUsed(let feature):
            return ["feature": feature]

        case .creatorFollowed(let creatorId), .creatorUnfollowed(let creatorId):
            return ["creator_id": creatorId]

        case .learningPathStarted(let pathId):
            return ["path_id": pathId]

        case .errorEncountered(let endpoint, let code, let message):
            return ["endpoint": endpoint, "error_code": code, "error_message": message]

        case .screenAbandoned(let screen, let timeOnScreenMs):
            return ["screen": screen, "time_on_screen_ms": timeOnScreenMs]

        case .networkTimeout(let endpoint):
            return ["endpoint": endpoint]
        }
    }
}

// MARK: - Registration Method

enum RegistrationMethod: String {
    case phone
    case email
}

// MARK: - User Properties
//
// Attached to the Mixpanel user profile once identified.
// Every event auto-joins these — no need to include in individual event props.

struct AnalyticsUserProperties {
    var objective: String?
    var currentLevel: String?
    var targetExam: String?
    var targetRole: String?
    var targetCompany: String?
    var weeklyCommitHours: Int?
    var currentStreak: Int?
    var readinessScore: Int?
    var totalContentConsumed: Int?
    var totalQuizzesTaken: Int?
    var isPremium: Bool?
    var signupPlatform: String = "ios"
    var appVersion: String?
    var buildNumber: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = ["signup_platform": signupPlatform]
        if let objective { dict["objective"] = objective }
        if let currentLevel { dict["current_level"] = currentLevel }
        if let targetExam { dict["target_exam"] = targetExam }
        if let targetRole { dict["target_role"] = targetRole }
        if let targetCompany { dict["target_company"] = targetCompany }
        if let weeklyCommitHours { dict["weekly_commit_hours"] = weeklyCommitHours }
        if let currentStreak { dict["current_streak"] = currentStreak }
        if let readinessScore { dict["readiness_score"] = readinessScore }
        if let totalContentConsumed { dict["total_content_consumed"] = totalContentConsumed }
        if let totalQuizzesTaken { dict["total_quizzes_taken"] = totalQuizzesTaken }
        if let isPremium { dict["is_premium"] = isPremium }
        if let appVersion { dict["app_version"] = appVersion }
        if let buildNumber { dict["build_number"] = buildNumber }
        return dict
    }
}
