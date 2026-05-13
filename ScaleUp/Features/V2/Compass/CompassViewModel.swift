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

// MARK: - View model

@Observable
@MainActor
final class CompassViewModel {
    var messages: [CompassMessage] = []
    var suggestions: [String] = [
        "⚡ Quiz me",
        "🎙️ Practice interview",
        "📝 Make a note",
        "📄 Build my resume",
        "↗ Plan my next 2 days",
        "🤔 Explain something",
    ]
    var showSuggestions = false
    var inputText: String = ""
    var activeConfig: CompassConfig? = nil

    func startConversation() {
        guard messages.isEmpty else { return }
        messages.append(.init(role: .compass, text: "Hi — what do you want to do?"))
        showSuggestions = true
    }

    func handleSuggestion(_ chip: String) {
        let userMsg = chip.replacingOccurrences(of: "⚡ ", with: "")
            .replacingOccurrences(of: "🎙️ ", with: "")
            .replacingOccurrences(of: "📝 ", with: "")
            .replacingOccurrences(of: "📄 ", with: "")
            .replacingOccurrences(of: "↗ ", with: "")
            .replacingOccurrences(of: "🤔 ", with: "")
        messages.append(.init(role: .user, text: userMsg))
        showSuggestions = false

        // Mode dispatch — simulates calling POST /api/v2/compass with the mode
        if chip.contains("Quiz") {
            messages.append(.init(role: .compass,
                text: "Got it. Here's how I'd set it up — change anything you want."))
            activeConfig = quizConfigMock
        } else if chip.contains("interview") {
            messages.append(.init(role: .compass,
                text: "Mock interview — adjust if needed."))
            activeConfig = interviewConfigMock
        } else if chip.contains("note") {
            messages.append(.init(role: .compass,
                text: "Upload a PDF, image, or audio file. I'll process it into a summary, mind map, flashcards, and audio narration."))
            activeConfig = nil
        } else if chip.contains("resume") {
            messages.append(.init(role: .compass,
                text: "I'll draft from your profile, diagnostic, and activity. Want me to start a base version?"))
            activeConfig = nil
        } else {
            messages.append(.init(role: .compass,
                text: "Tell me more about what you're trying to learn or do."))
            activeConfig = nil
        }
    }

    func send() {
        guard !inputText.isEmpty else { return }
        let userText = inputText
        messages.append(.init(role: .user, text: userText))
        inputText = ""
        showSuggestions = false

        // Stub Compass reply — wire to POST /api/v2/compass in production
        messages.append(.init(role: .compass,
            text: "I'd help with that. Want me to quiz you on it, explain a concept, or pull up relevant content?"))
    }

    func startConfiguredAction() {
        guard let config = activeConfig else { return }
        messages.append(.init(role: .compass, text: "Starting now…"))
        activeConfig = nil
        // TODO: route to detail page (quiz session, interview, etc.) via deep link or navigation.
    }

    // MARK: - Mock configs

    private var quizConfigMock: CompassConfig {
        .init(
            mode: "quiz_config",
            fields: [
                .init(label: "Topic",              value: "Last 7 days of content"),
                .init(label: "Format",             value: "Mix · recall + application"),
                .init(label: "Difficulty · count", value: "Medium · 10 questions"),
                .init(label: "Count toward objective", value: "Yes — readiness will update",
                      toggle: true, highlight: true),
            ],
            estimateLabel: "About 8 minutes · I'll explain anything you get wrong, and you can talk to me mid-quiz.",
            startLabel: "Start quiz",
            startEndpoint: "/api/v1/quizzes/request"
        )
    }

    private var interviewConfigMock: CompassConfig {
        .init(
            mode: "interview_config",
            fields: [
                .init(label: "Type",         value: "Behavioral"),
                .init(label: "Target role",  value: "SDE · Google L4"),
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
