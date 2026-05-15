import Foundation

// MARK: - Compass message & config models

enum CompassRole { case user, compass }

struct CompassMessage: Identifiable {
    let id = UUID()
    let role: CompassRole
    let text: String
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

// MARK: - Backend payload types

private struct CompassRequest: Codable {
    let mode: String
    let payload: CompassPayload
}

private struct CompassPayload: Codable {
    var message: String?
    var history: [CompassHistoryEntry]?
    var contentId: String?   // tutor mode — the content this turn is scoped to
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

/// Destination home screens the Compass quick-action chips route into.
/// Plan and Explain stay inside the conversation (no dedicated home).
enum CompassHomeRoute: String, Identifiable, CaseIterable {
    case quiz
    case interview
    case notes
    case resume
    case plan
    var id: String { rawValue }

    /// Maps a chip label (e.g. "⚡ Quiz me", "Practice interview") onto the
    /// route. Returns nil for chips that should stay conversational.
    static func fromChip(_ chip: String) -> CompassHomeRoute? {
        let s = chip.lowercased()
        if s.contains("quiz")      { return .quiz }
        if s.contains("interview") { return .interview }
        if s.contains("note")      { return .notes }
        if s.contains("resume")    { return .resume }
        if s.contains("plan")      { return .plan }
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

    /// Set when the user picks a Compass quick-action chip that maps to a
    /// dedicated destination screen (Quiz/Interview/Notes/Resume Home). The
    /// view presents the right home via .sheet(item:) on this value.
    var presentedHome: CompassHomeRoute?

    /// Used for fallback if backend is unreachable. Keeps UX coherent during outages.
    private var allowFallback = true

    func startConversation(context: V2Tab = .compass) {
        guard messages.isEmpty else { return }
        if tutorContext != nil {
            // Tutor mode opens with a scoped greeting, not the generic one.
            messages.append(.init(
                role: .compass,
                text: "Ask me anything about \(tutorContext!.title) — I can explain concepts, give examples, or quiz you on it."
            ))
            suggestions = ["Explain the key idea simply", "Give me a real example", "Quiz me on this"]
            showSuggestions = true
        } else {
            Task { await callGreeting(context: context) }
        }
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
            .replacingOccurrences(of: "📄 ", with: "")
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

    private func callConversation(message: String) async {
        isWaitingForReply = true
        defer { isWaitingForReply = false }
        let history = messages.suffix(10).map { msg in
            CompassHistoryEntry(role: msg.role == .user ? "user" : "assistant", content: msg.text)
        }
        // Tutor mode when scoped to content — same Compass brain, grounded in the lesson.
        let mode = tutorContext != nil ? "tutor" : "conversation"
        let body = CompassRequest(
            mode: mode,
            payload: CompassPayload(
                message: message,
                history: history,
                contentId: tutorContext?.contentId
            )
        )
        do {
            let resp: V2APIResponse<CompassResponseEnvelope> = try await V2APIClient.shared.post("/compass", body: body)
            let reply = resp.data.output.reply ?? "Tell me more."
            messages.append(.init(role: .compass, text: reply))
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
        if chip.contains("resume")    { return "conversation" }
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

    // MARK: - Fallbacks

    private var defaultSuggestions: [String] {
        [
            "⚡ Quiz me",
            "🎙️ Practice interview",
            "📝 Make a note",
            "📄 Build my resume",
            "↗ Plan my next 2 days",
            "🤔 Explain something",
        ]
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
