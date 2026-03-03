import SwiftUI

// MARK: - AI Tutor View Model

@Observable
@MainActor
final class AITutorViewModel {

    // MARK: - State

    var tutorStatus: TutorStatus?
    var conversation: TutorConversation?
    var messages: [TutorMessage] = []
    var quickPrompts: [QuickPrompt] = []
    var currentTier: TutorTier = .disabled

    var isLoadingStatus = false
    var isLoadingConversation = false
    var isSendingMessage = false
    var errorMessage: String?
    var failedMessage: String?

    // Input
    var inputText = ""
    var characterCount: Int { inputText.count }
    let maxCharacters = 2000

    // Rate limiting (client-side)
    private var recentSendTimestamps: [Date] = []
    var isRateLimited = false

    // Tier upgrade notification
    var showTierUpgrade = false

    // First-time tooltip
    var hasShownTooltip: Bool {
        UserDefaults.standard.bool(forKey: "aiTutorTooltipShown")
    }

    private let service = AITutorService()
    private(set) var contentId: String = ""
    private(set) var contentTitle: String = ""

    // MARK: - Computed

    var canSend: Bool {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && !isSendingMessage && !isRateLimited && text.count <= maxCharacters
    }

    var showQuickPrompts: Bool {
        messages.isEmpty && !quickPrompts.isEmpty
    }

    var isDisabled: Bool {
        currentTier == .disabled
    }

    var isLimited: Bool {
        currentTier == .limited
    }

    var buttonVisible: Bool {
        !isLoadingStatus && currentTier != .disabled
    }

    // MARK: - Load Status

    func loadStatus(contentId: String, contentTitle: String) async {
        self.contentId = contentId
        self.contentTitle = contentTitle
        isLoadingStatus = true

        do {
            let status = try await service.checkStatus(contentId: contentId)
            tutorStatus = status
            currentTier = status.tier
            quickPrompts = status.quickPrompts
        } catch {
            print("[AITutor] Status check failed: \(error)")
            currentTier = .disabled
        }

        isLoadingStatus = false
    }

    // MARK: - Load Conversation

    func loadConversation() async {
        guard !contentId.isEmpty else { return }
        isLoadingConversation = true
        errorMessage = nil

        do {
            let conv = try await service.getConversation(contentId: contentId)
            conversation = conv
            messages = conv.messages
            currentTier = conv.tutorTier

            if let prompts = conv.quickPrompts, !prompts.isEmpty, conv.messages.isEmpty {
                quickPrompts = prompts
            } else if !conv.messages.isEmpty {
                quickPrompts = []
            }
        } catch {
            print("[AITutor] Load conversation failed: \(error)")
            errorMessage = "Could not load conversation"
        }

        isLoadingConversation = false
    }

    // MARK: - Send Message

    func sendMessage(_ text: String? = nil) async {
        let messageText = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, messageText.count <= maxCharacters else { return }

        // Rate limiting: max 5 messages in 10 seconds
        let now = Date()
        recentSendTimestamps = recentSendTimestamps.filter { now.timeIntervalSince($0) < 10 }
        if recentSendTimestamps.count >= 5 {
            isRateLimited = true
            Task {
                try? await Task.sleep(for: .seconds(5))
                isRateLimited = false
            }
            return
        }
        recentSendTimestamps.append(now)

        // Optimistic update: show user message immediately
        let userMessage = TutorMessage(
            role: .user,
            content: messageText,
            contextMeta: nil,
            createdAt: Date()
        )
        messages.append(userMessage)
        inputText = ""
        failedMessage = nil
        isSendingMessage = true
        errorMessage = nil

        // Hide quick prompts after first message
        quickPrompts = []

        Haptics.light()

        do {
            let response = try await service.sendMessage(contentId: contentId, message: messageText)

            // Append assistant response
            messages.append(response.message)

            // Check for tier upgrade (limited → full)
            if currentTier == .limited && response.tutorTier == .full {
                currentTier = .full
                showTierUpgrade = true
                Haptics.success()
            } else {
                currentTier = response.tutorTier
            }
        } catch {
            print("[AITutor] Send message failed: \(error)")
            failedMessage = messageText
            errorMessage = "Failed to send. Tap to retry."
            Haptics.error()
        }

        isSendingMessage = false
    }

    // MARK: - Retry Failed Message

    func retryFailedMessage() async {
        guard let message = failedMessage else { return }
        // Remove the previously failed user message
        if let lastIndex = messages.lastIndex(where: { $0.role == .user && $0.content == message }) {
            messages.remove(at: lastIndex)
        }
        failedMessage = nil
        errorMessage = nil
        await sendMessage(message)
    }

    // MARK: - Quick Prompt

    func sendQuickPrompt(_ prompt: QuickPrompt) async {
        await sendMessage(prompt.prompt)
    }

    // MARK: - Tooltip

    func markTooltipShown() {
        UserDefaults.standard.set(true, forKey: "aiTutorTooltipShown")
    }
}
