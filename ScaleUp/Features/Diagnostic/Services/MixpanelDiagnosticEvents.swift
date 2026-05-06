import Foundation

// Thin convenience wrapper so call-sites stay concise and don't import AnalyticsService directly.
// All calls delegate to AnalyticsService.shared — no batching, no retry, no buffering.

enum DiagnosticMixpanelEvent: String {
    case started                    = "diagnostic_started"
    case questionShown              = "diagnostic_question_shown"
    case questionAnswered           = "diagnostic_question_answered"
    case voiceUsed                  = "diagnostic_voice_used"
    case voiceFailedFallbackTyped   = "diagnostic_voice_failed_fallback_typed"
    case topicCompleted             = "diagnostic_topic_completed"
    case completed                  = "diagnostic_completed"
    case abandoned                  = "diagnostic_abandoned"
}

@MainActor
enum MixpanelDiagnostic {

    static func trackQuestionShown(
        questionId: String,
        competency: String,
        type: String,
        topicIndex: Int,
        topicTotal: Int
    ) {
        AnalyticsService.shared.track(.diagnosticQuestionShown(
            questionId: questionId,
            competency: competency,
            type: type,
            topicIndex: topicIndex,
            topicTotal: topicTotal
        ))
    }

    static func trackQuestionAnswered(
        questionId: String,
        competency: String,
        type: String,
        timeMs: Int
    ) {
        AnalyticsService.shared.track(.diagnosticQuestionAnswered(
            questionId: questionId,
            competency: competency,
            type: type,
            timeMs: timeMs
        ))
    }

    static func trackVoiceUsed(
        questionId: String,
        competency: String,
        durationSec: Double
    ) {
        AnalyticsService.shared.track(.diagnosticVoiceUsed(
            questionId: questionId,
            competency: competency,
            durationSec: durationSec
        ))
    }

    static func trackVoiceFailedFallbackTyped(questionId: String, reason: String) {
        AnalyticsService.shared.track(.diagnosticVoiceFailedFallbackTyped(
            questionId: questionId,
            reason: reason
        ))
    }

    static func trackTopicCompleted(competency: String, topicIndex: Int, topicTotal: Int) {
        AnalyticsService.shared.track(.diagnosticTopicCompleted(
            competency: competency,
            topicIndex: topicIndex,
            topicTotal: topicTotal
        ))
    }
}
