import Foundation
import UIKit

// MARK: - Compass message & config models

enum CompassRole { case user, compass }

struct CompassSuggestedAction: Codable, Sendable {
    let type: String              // "request_drill" | "start_tutoring" | "start_check_quiz"
    let drillSubtype: String?
    let difficulty: String?
    let topicHint: String?
    // tutoring
    let topic: String?
    let score: Double?
    let questionCount: Int?
    let beforeScore: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case drillSubtype = "drill_subtype"
        case difficulty
        case topicHint = "topic_hint"
        case topic
        case score
        case questionCount = "question_count"
        case beforeScore = "before_score"
    }
}

struct CompassMessage: Identifiable {
    let id = UUID()
    let role: CompassRole
    let text: String
    var suggestedAction: CompassSuggestedAction? = nil
    var cards: [CompassCard] = []
    var imageData: Data? = nil
}

struct CompassConfigField {
    let label: String
    let value: String
    var toggle: Bool = false
    var highlight: Bool = false
}

struct CompassConfig {
    let mode: String              // quiz_config, interview_config, ...
    let fields: [CompassConfigField]
    let estimateLabel: String
    let startLabel: String
    let startEndpoint: String?    // e.g., /api/v1/quizzes/request
}

// MARK: - Thread restore models

private struct CompassThreadEnvelope: Codable {
    let threadId: String?
    let title: String?
    let messageCount: Int?
    let lastMessageAt: String?
    let messages: [ThreadMessage]
}

private struct ThreadMessage: Codable {
    let role: String
    let content: String
    let mode: String?
    let followups: [String]?
    let cards: [CompassCard]?
}

// MARK: - Backend payload types

private struct CompassRequest: Codable {
    let mode: String
    let payload: CompassPayload
}

private struct CompassPayload: Codable {
    var message: String?
    var history: [CompassHistoryEntry]?
    var contentId: String?   // tutor mode — the content this turn is scoped to
    var weekNumber: Int?     // legacy review_week mode — kept for any in-flight server state
    var scope: String?       // coach mode — week | month | all_time | topic
    var topic: String?       // coach mode (scope=topic) or tutor_topic/tutor_result
    var attemptId: String?   // tutor_result mode — the completed quiz attempt
    var beforeScore: Double? // tutor_result mode — mastery before the check
    var imageBase64: String? // vision mode — base64-encoded JPEG
    var mimeType: String?    // vision mode — e.g. "image/jpeg"
}

private struct CompassHistoryEntry: Codable {
    let role: String  // "user" | "assistant"
    let content: String
}

private struct CompassResponseEnvelope: Codable {
    let mode: String
    let output: CompassOutput
}

private struct CompassOutput: Codable {
    // greeting
    let message: String?
    let suggestedActions: [SuggestedAction]?
    // conversation
    let reply: String?
    let followups: [String]?
    // config modes
    let headline: String?
    let config: ConfigDecoded?
    let estimateMin: Int?
    let startEndpoint: String?
    // insight mode
    let items: [InsightItem]?
    // on-demand drill action card
    let suggestedAction: CompassSuggestedAction?
    // Progress Intelligence answer cards
    let cards: [CompassCard]?
}

private struct SuggestedAction: Codable {
    let id: String
    let label: String
    let mode: String
}

private struct ConfigDecoded: Codable {
    let topic: FieldEntry?
    let format: FieldEntry?
    let difficulty: FieldEntry?
    let count: FieldEntry?
    let tagToObjective: FieldEntry?
    let type: FieldEntry?
    let targetRole: FieldEntry?
    let duration: FieldEntry?
    let seniority: FieldEntry?

    struct FieldEntry: Codable {
        let label: String?
        let value: AnyValue?
    }

    /// Permissive decoder for `value` since backend returns mixed types.
    struct AnyValue: Codable {
        let asString: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { asString = s; return }
            if let i = try? c.decode(Int.self)    { asString = String(i); return }
            if let b = try? c.decode(Bool.self)   { asString = b ? "Yes" : "No"; return }
            asString = ""
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(asString)
        }
    }
}

private struct InsightItem: Codable {
    let severity: String
    let text: String
}

// MARK: - View model

/// When Compass is opened scoped to a piece of content, it runs in TUTOR mode —
/// the same Compass brain + history, grounded in that video/article.
struct CompassTutorContext: Equatable, Identifiable {
    let contentId: String
    let title: String
    var id: String { contentId }
}

/// Scope for a Coach conversation. Picked by the user via scope chips on the
/// opening turn; pinned on every subsequent message so the server keeps the
/// retrospective framing aligned to the same window.
enum CoachScope: String, CaseIterable, Identifiable, Equatable {
    case week
    case month
    case allTime = "all_time"
    case topic

    var id: String { rawValue }

    /// Wire value for the backend `scope` field.
    var wireValue: String { rawValue }

    /// Chip label shown on the opener.
    var chipLabel: String {
        switch self {
        case .week:    return "This Week"
        case .month:   return "This Month"
        case .allTime: return "Since Start"
        case .topic:   return "By Topic"
        }
    }

    /// Short subtitle shown in the Coach header once a scope is chosen.
    var headerSubtitle: String {
        switch self {
        case .week:    return "scope: This Week"
        case .month:   return "scope: This Month"
        case .allTime: return "scope: Since Start"
        case .topic:   return "scope: By Topic"
        }
    }
}

/// When Compass is opened in Coach mode, it runs a retrospective over the
/// chosen scope (week / month / all-time / topic). Subsequent turns stay
/// anchored to the same scope so the server keeps framing consistent.
struct CompassCoachContext: Equatable, Identifiable {
    /// nil until the user picks a scope chip on the opening turn.
    var scope: CoachScope?
    /// Required only when scope == .topic.
    var topic: String?
    var id: String { "coach-\(scope?.rawValue ?? "pending")-\(topic ?? "")" }
}

/// LEGACY — kept only so `compassReview` task routes still compile until any
/// in-flight server state drains. New code paths use `CompassCoachContext`.
struct CompassReviewContext: Equatable, Identifiable {
    let weekNumber: Int
    let taskId: String?
    var id: String { "review-\(weekNumber)" }
}

/// Destination home screens the Compass quick-action chips route into.
/// Plan and Explain stay inside the conversation (no dedicated home).
enum CompassHomeRoute: String, Identifiable, CaseIterable {
    case quiz
    case interview
    case notes
    case plan
    case compete
    case codingDrill
    case codingCapstone
    var id: String { rawValue }

    /// Maps a chip label (e.g. "⚡ Quiz me", "Practice interview") onto the
    /// route. Returns nil for chips that should stay conversational.
    static func fromChip(_ chip: String) -> CompassHomeRoute? {
        let s = chip.lowercased()
        // capstone check BEFORE any other "coding" routing
        if s.contains("capstone") || s.contains("coding project") || s.contains("how am i doing on coding") {
            return .codingCapstone
        }
        // coding drill check BEFORE quiz — "coding drill" must not fall through to .quiz
        if s.contains("coding drill") || s.contains("coding practice") { return .codingDrill }
        if s.contains("quiz")      { return .quiz }
        if s.contains("interview") { return .interview }
        if s.contains("note")      { return .notes }
        if s.contains("plan")      { return .plan }
        if s.contains("compete") || s.contains("competition") || s.contains("challenge") {
            return .compete
        }
        return nil
    }
}

@Observable
@MainActor
final class CompassViewModel {
    var messages: [CompassMessage] = []
    var suggestions: [String] = []
    var showSuggestions = false
    var inputText: String = ""
    var activeConfig: CompassConfig? = nil
    var isWaitingForReply = false
    var error: String?

    /// Non-nil when Compass is scoped to a content piece (tutor mode).
    var tutorContext: CompassTutorContext?

    /// Non-nil when Compass was launched in Coach mode. Every turn in this
    /// conversation is anchored to the chosen scope (week / month / all-time /
    /// topic). The scope may be nil initially — the opener prompts the user
    /// to pick one before the LLM call.
    var coachContext: CompassCoachContext?

    /// Legacy plumbing — still accepted so the deprecated compassReview route
    /// continues to function for any in-flight server state. New entry points
    /// (Home "Talk to Coach") use coachContext directly.
    var reviewContext: CompassReviewContext?

    /// Tracks whether we've already sent the Coach opener for this
    /// conversation. After the opener, follow-up turns flow through
    /// conversation (with the coach framing pinned server-side).
    private var didSendCoachOpener = false

    /// Set when the user picks a Compass quick-action chip that maps to a
    /// dedicated destination screen (Quiz/Interview/Notes/Plan/Compete). The
    /// view presents the right home via .sheet(item:) on this value.
    var presentedHome: CompassHomeRoute?

    /// Non-nil while an inline check-quiz is running inside the chat.
    var inlineQuiz: CompassInlineQuizModel?

    /// True when the user's active objective maps to a coding role track.
    /// Probed once on Compass open; gates the "💻 Start a coding drill" chip.
    var isCodingEligible: Bool = false

    /// Set by V2CompassView.onAppear when Compass is opened from the placement
    /// shell. Filters "Plan my next 2 days" from default suggestions.
    var isPlacement: Bool = false

    /// Used for fallback if backend is unreachable. Keeps UX coherent during outages.
    private var allowFallback = true

    func startConversation(context: V2Tab = .compass) {
        // Eligibility refresh runs on every open — the conversation guard below
        // returns early on repeat opens, but the chip list still needs to be
        // accurate (e.g., user just finished onboarding into a coding track).
        Task { await checkCodingEligibility() }
        guard messages.isEmpty else { return }
        if let coach = coachContext {
            // Coach mode. If a scope is already chosen, fire the opener.
            // Otherwise, prompt the user to pick a scope; V2CompassView
            // renders the scope chip strip when coachContext.scope == nil.
            if let scope = coach.scope {
                Task { await callCoachOpener(scope: scope, topic: coach.topic) }
            } else {
                messages.append(.init(
                    role: .compass,
                    text: "I can look back over your week, your month, or your whole journey — or zoom in on a specific topic. What do you want to reflect on?"
                ))
                // Scope chips are rendered by V2CompassView itself (not as
                // generic suggestion chips) because tapping one needs to set
                // coachContext.scope before kicking off the opener.
                showSuggestions = false
            }
        } else if let review = reviewContext {
            // Legacy compassReview route — treat as coach with scope=week.
            coachContext = CompassCoachContext(scope: .week, topic: nil)
            Task { await callCoachOpener(scope: .week, topic: nil, weekNumber: review.weekNumber) }
        } else if tutorContext != nil {
            // Tutor mode opens with a scoped greeting, not the generic one.
            messages.append(.init(
                role: .compass,
                text: "Ask me anything about \(tutorContext!.title) — I can explain concepts, give examples, or quiz you on it."
            ))
            suggestions = ["Explain the key idea simply", "Give me a real example", "Quiz me on this"]
            showSuggestions = true
        } else {
            // Default Compass mode: try to restore the persisted thread first.
            // Only fall back to the greeting if nothing was restored.
            Task {
                if await restoreThreadIfAvailable() { return }
                await callGreeting(context: context)
            }
        }
    }

    /// Called by V2CompassView when the user taps a scope chip on the opener.
    /// Sets the scope on coachContext, then fires the opener.
    func openCoach(scope: CoachScope, topic: String? = nil) {
        if coachContext == nil {
            coachContext = CompassCoachContext(scope: scope, topic: topic)
        } else {
            coachContext?.scope = scope
            coachContext?.topic = topic
        }
        // The user picking a scope is the first explicit interaction — show
        // it as a user-side bubble for conversational coherence.
        messages.append(.init(role: .user, text: scope.chipLabel + (topic.map { " · \($0)" } ?? "")))
        showSuggestions = false
        Task { await callCoachOpener(scope: scope, topic: topic) }
    }

    /// Archive the current thread server-side and clear UI so the user starts fresh.
    func resetConversation() async {
        do {
            struct EmptyBody: Codable {}
            let _: V2APIResponse<ResetResponse> = try await V2APIClient.shared.post("/compass/reset", body: EmptyBody())
        } catch {
            // Even if the server fails, clear locally — the next message starts a new thread.
        }
        messages.removeAll()
        activeConfig = nil
        showSuggestions = false
        startConversation()
    }

    private struct ResetResponse: Codable { let reset: Bool? }

    func handleSuggestion(_ chip: String) {
        // First check if this chip maps to a dedicated home screen — those
        // open as destinations, NOT as one-shot config cards. Tutor-mode
        // chips ("Quiz me on this") stay conversational.
        if tutorContext == nil, let route = CompassHomeRoute.fromChip(chip) {
            presentedHome = route
            return
        }

        let userMsg = chip
            .replacingOccurrences(of: "⚡ ", with: "")
            .replacingOccurrences(of: "🎙️ ", with: "")
            .replacingOccurrences(of: "📝 ", with: "")
            .replacingOccurrences(of: "↗ ", with: "")
            .replacingOccurrences(of: "🤔 ", with: "")
        messages.append(.init(role: .user, text: userMsg))
        showSuggestions = false

        Task { await callMode(for: chip, userMessage: userMsg) }
    }

    /// Trigger the conversational quiz_config flow — used when "Generate a
    /// new quiz" is tapped from inside Quiz Home, so customisation still
    /// happens through Compass.
    func startQuizConfigFromHome() {
        let userMsg = "Quiz me"
        messages.append(.init(role: .user, text: userMsg))
        showSuggestions = false
        Task { await callConfigMode(mode: "quiz_config") }
    }

    func send() {
        guard !inputText.isEmpty else { return }
        let userText = inputText
        messages.append(.init(role: .user, text: userText))
        inputText = ""
        showSuggestions = false
        activeConfig = nil

        Task { await callConversation(message: userText) }
    }

    func sendVision(image: UIImage, prompt: String) async {
        guard let enc = CompassImageEncoder.downscaleAndEncode(image) else {
            messages.append(.init(role: .compass, text: "I couldn't process that image — try another?"))
            return
        }
        activeConfig = nil
        showSuggestions = false
        // Local user bubble with the thumbnail (in memory only — never persisted server-side).
        messages.append(CompassMessage(role: .user, text: prompt, imageData: enc.data))
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post(
                "/compass", body: CompassRequest(mode: "vision", payload: CompassPayload(message: prompt, imageBase64: enc.base64, mimeType: enc.mimeType))
            )
            messages.append(.init(role: .compass, text: resp.data.output.reply ?? "Here's what I see."))
        } catch {
            messages.append(.init(role: .compass, text: "I had trouble reading that — try again?"))
        }
    }

    /// Route into the v1 detail screen for whichever action the user configured.
    /// Caller passes the shared V2TaskRouter so the sheet appears at the root.
    func startConfiguredAction(router: V2TaskRouter) {
        guard let config = activeConfig else { return }
        // Extract the configured topic so the router can request a quiz for it.
        let topic = config.fields.first(where: { $0.label.caseInsensitiveCompare("Topic") == .orderedSame })?.value
            ?? config.fields.first?.value
        let title = config.fields.first?.value ?? "Starting now"
        let taskType: String
        switch config.mode {
        case "quiz_config":      taskType = "quiz"
        case "interview_config": taskType = "interview"
        default:                 taskType = "manual"
        }
        // V2TaskRouter handles quiz-without-quizId by requesting a quiz for
        // the topic (V2QuizRequestLoaderSheet) — exactly what Compass wants.
        router.open(
            taskType: taskType,
            payload: nil,
            title: title,
            topic: topic
        )
        messages.append(.init(role: .compass, text: "Opening now…"))
        activeConfig = nil
    }

    // MARK: - Tutoring methods

    func startTutoring(topic: String) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post(
                "/compass", body: CompassRequest(mode: "tutor_topic", payload: CompassPayload(topic: topic))
            )
            let out = resp.data.output
            messages.append(.init(role: .compass, text: out.reply ?? "Let's work on \(topic).",
                                  suggestedAction: out.suggestedAction, cards: out.cards ?? []))
        } catch {
            messages.append(.init(role: .compass, text: "I couldn't start that just now — try again?"))
        }
    }

    func startInlineCheck(topic: String, questionCount: Int, beforeScore: Double?) {
        let model = CompassInlineQuizModel(topic: topic, questionCount: questionCount, beforeScore: beforeScore)
        inlineQuiz = model
        Task {
            await model.begin()
        }
    }

    func finishInlineCheck() async {
        guard let model = inlineQuiz, let attemptId = model.attemptId else { inlineQuiz = nil; return }
        let topic = model.topic, before = model.beforeScore
        inlineQuiz = nil
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post(
                "/compass", body: CompassRequest(mode: "tutor_result", payload: CompassPayload(topic: topic, attemptId: attemptId, beforeScore: before))
            )
            let out = resp.data.output
            messages.append(.init(role: .compass, text: out.reply ?? "Nice work.",
                                  suggestedAction: out.suggestedAction, cards: out.cards ?? []))
        } catch {
            messages.append(.init(role: .compass, text: "You finished the check — your mastery will update shortly."))
        }
    }

    // MARK: - Thread restore

    /// Fetches the persisted Compass thread from the backend and populates
    /// `messages` with it. Returns true if at least one message was restored
    /// so the caller can skip the greeting. Only called for the default
    /// Compass mode (no tutor/coach context).
    func restoreThreadIfAvailable() async -> Bool {
        do {
            let resp: V2APIResponse<CompassThreadEnvelope> = try await V2APIClient.shared.get("/compass/thread")
            let restored = resp.data.messages.compactMap { m -> CompassMessage? in
                guard !m.content.isEmpty else { return nil }
                return CompassMessage(
                    role: m.role == "assistant" ? .compass : .user,
                    text: m.content,
                    suggestedAction: nil,
                    cards: m.cards ?? []
                )
            }
            guard !restored.isEmpty else { return false }
            messages = restored
            return true
        } catch {
            return false
        }
    }

    // MARK: - Backend calls

    private func callGreeting(context: V2Tab = .compass) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        let contextHint: String?
        switch context {
        case .home:    contextHint = "User is on the Home tab. Offer to help pick today's task."
        case .learn:   contextHint = "User is on Learn (content browse). Offer to find content."
        case .you:     contextHint = "User is on You (their progress). Offer to summarize the week."
        case .compass: contextHint = nil
        }
        let body = CompassRequest(
            mode: "greeting",
            payload: CompassPayload(message: contextHint, history: nil)
        )
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post("/compass", body: body)
            let msg = resp.data.output.message ?? "Hi — what do you want to do?"
            messages.append(.init(role: .compass, text: msg))
            suggestions = resp.data.output.suggestedActions?.map { $0.label } ?? defaultSuggestions
            showSuggestions = true
        } catch {
            messages.append(.init(role: .compass, text: "Hi — what do you want to do?"))
            suggestions = defaultSuggestions
            showSuggestions = true
        }
    }

    private func callMode(for chip: String, userMessage: String) async {
        let mode = inferMode(from: chip)
        switch mode {
        case "quiz_config", "interview_config":
            await callConfigMode(mode: mode)
        case "note":
            // Notes chip is now intercepted by handleSuggestion → presentedHome.
            // If we end up here (defensive fallback), route to the home too.
            presentedHome = .notes
        default:
            await callConversation(message: userMessage)
        }
    }

    private func callConfigMode(mode: String) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        let body = CompassRequest(mode: mode, payload: CompassPayload(message: nil, history: nil))
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post("/compass", body: body)
            if let headline = resp.data.output.headline {
                messages.append(.init(role: .compass, text: headline))
            }
            activeConfig = buildConfig(from: resp.data.output, mode: mode)
        } catch {
            if allowFallback {
                messages.append(.init(role: .compass, text: mode == "quiz_config"
                    ? "Got it. Here's how I'd set it up — change anything you want."
                    : "Mock interview — adjust if needed."))
                activeConfig = mode == "quiz_config" ? fallbackQuizConfig : fallbackInterviewConfig
            } else {
                self.error = "Couldn't reach Compass. Try again."
            }
        }
    }

    private func callCoachOpener(scope: CoachScope, topic: String?, weekNumber: Int? = nil) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        let body = CompassRequest(
            mode: "coach",
            payload: CompassPayload(
                message: nil,
                history: nil,
                contentId: nil,
                weekNumber: weekNumber,
                scope: scope.wireValue,
                topic: topic
            )
        )
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post("/compass", body: body)
            let reply = resp.data.output.reply
                ?? resp.data.output.message
                ?? "Here's the recap — how did it feel?"
            messages.append(.init(role: .compass, text: reply))
            let follow = resp.data.output.followups ?? ["It went well", "I got blocked", "Plan what's next"]
            suggestions = follow
            showSuggestions = !follow.isEmpty
            didSendCoachOpener = true
        } catch {
            let fallback: String = {
                switch scope {
                case .week:    return "Let's look at this week. How did it actually feel?"
                case .month:   return "Let's zoom out to the past month. What stands out?"
                case .allTime: return "Let's look at the whole journey so far. What feels different now?"
                case .topic:   return "Let's focus on \(topic ?? "that topic"). Where do you feel solid, and where do you still wobble?"
                }
            }()
            messages.append(.init(role: .compass, text: fallback))
            suggestions = ["It went well", "I got blocked", "Plan what's next"]
            showSuggestions = true
            didSendCoachOpener = true
        }
    }

    private func callConversation(message: String) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        let history = messages.suffix(10).map { msg in
            CompassHistoryEntry(role: msg.role == .user ? "user" : "assistant", content: msg.text)
        }
        // Mode selection:
        //   - coach: follow-up turns of a Coach session stay in coach so the
        //     server keeps the scope framing pinned (handled server-side by
        //     forwarding to conversation with the coach scope addendum).
        //   - tutor: scoped to a piece of content.
        //   - conversation: everything else.
        let mode: String
        if coachContext != nil || reviewContext != nil {
            mode = "coach"
        } else if tutorContext != nil {
            mode = "tutor"
        } else {
            mode = "conversation"
        }
        let body = CompassRequest(
            mode: mode,
            payload: CompassPayload(
                message: message,
                history: history,
                contentId: tutorContext?.contentId,
                weekNumber: reviewContext?.weekNumber,
                scope: coachContext?.scope?.wireValue,
                topic: coachContext?.topic
            )
        )
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post("/compass", body: body)
            let reply = resp.data.output.reply ?? "Tell me more."
            messages.append(.init(role: .compass, text: reply, suggestedAction: resp.data.output.suggestedAction, cards: resp.data.output.cards ?? []))
            if let followups = resp.data.output.followups, !followups.isEmpty {
                suggestions = followups
                showSuggestions = true
            }
        } catch {
            messages.append(.init(role: .compass, text: "I had trouble reaching the server — but I'm here. Try again?"))
        }
    }

    // MARK: - Helpers

    private func inferMode(from chip: String) -> String {
        if chip.contains("Quiz")      { return "quiz_config" }
        if chip.contains("interview") { return "interview_config" }
        if chip.contains("note")      { return "note" }
        return "conversation"
    }

    private func buildConfig(from output: CompassOutput, mode: String) -> CompassConfig? {
        guard let cfg = output.config else { return nil }
        var fields: [CompassConfigField] = []
        if mode == "quiz_config" {
            if let topic = cfg.topic           { fields.append(.init(label: "Topic", value: topic.label ?? topic.value?.asString ?? "")) }
            if let format = cfg.format         { fields.append(.init(label: "Format", value: format.label ?? format.value?.asString ?? "")) }
            if let diff = cfg.difficulty, let count = cfg.count {
                let l = "\(diff.label ?? diff.value?.asString ?? "") · \(count.label ?? count.value?.asString ?? "")"
                fields.append(.init(label: "Difficulty · count", value: l))
            }
            if let tag = cfg.tagToObjective {
                fields.append(.init(label: "Count toward objective",
                                    value: tag.label ?? tag.value?.asString ?? "",
                                    toggle: true, highlight: true))
            }
        } else if mode == "interview_config" {
            if let type = cfg.type             { fields.append(.init(label: "Type", value: type.label ?? type.value?.asString ?? "")) }
            if let role = cfg.targetRole       { fields.append(.init(label: "Target role", value: role.label ?? role.value?.asString ?? "")) }
            if let dur = cfg.duration          { fields.append(.init(label: "Duration", value: dur.label ?? dur.value?.asString ?? "")) }
            if let sen = cfg.seniority         { fields.append(.init(label: "Seniority", value: sen.label ?? sen.value?.asString ?? "")) }
            if let tag = cfg.tagToObjective {
                fields.append(.init(label: "Count toward objective",
                                    value: tag.label ?? tag.value?.asString ?? "",
                                    toggle: true, highlight: true))
            }
        }
        let est = output.estimateMin.map { "About \($0) minutes." } ?? ""
        return CompassConfig(
            mode: mode,
            fields: fields,
            estimateLabel: est,
            startLabel: mode == "quiz_config" ? "Start quiz" : "Start interview",
            startEndpoint: output.startEndpoint
        )
    }

    // MARK: - Coding eligibility probe

    /// Probes /drills/today to determine whether the user's objective maps to a coding
    /// role track. Anything except a 404 no_coding_track_for_objective response means
    /// the user is eligible (calibration_required, daily_quota_used, no_drill_available
    /// all indicate a track exists). Result gates the "💻 Start a coding drill" chip.
    func checkCodingEligibility() async {
        do {
            let _: DrillTodayResponse = try await V2APIClient.shared.getCoding("/drills/today")
            isCodingEligible = true
        } catch V2APIError.httpError(let status, let data) where status == 404 {
            if let body = try? JSONDecoder().decode([String: String].self, from: data),
               let err = body["error"],
               err == "no_coding_track_for_objective" {
                isCodingEligible = false
            } else {
                // calibration_required / daily_quota_used / no_drill_available → track exists
                isCodingEligible = true
            }
        } catch {
            isCodingEligible = false  // hide chip on unknown errors
        }

        // The greeting call runs in parallel and may have already populated
        // `suggestions` with the backend's chip list (which doesn't include the
        // coding chip). Inject it now so the user sees it on this open without
        // needing a re-render trigger.
        if isCodingEligible, !suggestions.isEmpty,
           !suggestions.contains(where: { $0.lowercased().contains("coding drill") }) {
            let codingChip = "💻 Start a coding drill"
            // Insert after the practice/interview chip if present, else at index 1.
            if let idx = suggestions.firstIndex(where: { $0.lowercased().contains("interview") }) {
                suggestions.insert(codingChip, at: min(idx + 1, suggestions.count))
            } else {
                suggestions.insert(codingChip, at: min(2, suggestions.count))
            }
        }
    }

    // MARK: - Fallbacks

    private var defaultSuggestions: [String] {
        var chips = [
            "⚡ Quiz me",
            "🎙️ Practice interview",
            "📝 Make a note",
            "↗ Plan my next 2 days",
            "🤔 Explain something",
        ]
        if isCodingEligible {
            // Insert after "Practice interview" (index 2) so it's near the practice chips
            chips.insert("💻 Start a coding drill", at: 2)
        }
        if isPlacement {
            // Remove "Plan my next 2 days" for placement students
            chips.removeAll { $0.contains("Plan") }
        }
        return chips
    }

    private var fallbackQuizConfig: CompassConfig {
        .init(
            mode: "quiz_config",
            fields: [
                .init(label: "Topic",              value: "Last 7 days of content"),
                .init(label: "Format",             value: "Mix · recall + application"),
                .init(label: "Difficulty · count", value: "Medium · 10 questions"),
                .init(label: "Count toward objective", value: "Yes — readiness will update",
                      toggle: true, highlight: true),
            ],
            estimateLabel: "About 8 minutes · I'll explain anything you get wrong.",
            startLabel: "Start quiz",
            startEndpoint: "/api/v1/quizzes/request"
        )
    }

    private var fallbackInterviewConfig: CompassConfig {
        .init(
            mode: "interview_config",
            fields: [
                .init(label: "Type",         value: "Behavioral"),
                .init(label: "Target role",  value: "Your active objective role"),
                .init(label: "Duration",    value: "30 min"),
                .init(label: "Seniority",    value: "Mid-level"),
                .init(label: "Count toward objective", value: "Yes",
                      toggle: true, highlight: true),
            ],
            estimateLabel: "Voice or text · I'll give detailed feedback after.",
            startLabel: "Start interview",
            startEndpoint: "/api/v1/interviews/start"
        )
    }
}
