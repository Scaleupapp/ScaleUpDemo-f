import SwiftUI

// MARK: - AI Tutor Chat Sheet

struct AITutorSheetView: View {
    let contentId: String
    let contentTitle: String
    @Bindable var viewModel: AITutorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().overlay(ColorTokens.divider)

            // Chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Welcome message (empty state)
                        if viewModel.messages.isEmpty && !viewModel.isLoadingConversation {
                            welcomeMessage
                                .padding(.bottom, Spacing.sm)
                        }

                        // Loading indicator
                        if viewModel.isLoadingConversation {
                            ProgressView()
                                .tint(ColorTokens.gold)
                                .padding(.vertical, Spacing.xl)
                        }

                        // Tier upgrade notification
                        if viewModel.showTierUpgrade {
                            tierUpgradeMessage
                                .padding(.bottom, Spacing.sm)
                        }

                        // Messages
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                            AITutorMessageBubble(
                                message: message,
                                isConsecutive: isConsecutive(at: index)
                            )
                            .id(index)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }

                        // Typing indicator
                        if viewModel.isSendingMessage {
                            AITutorTypingIndicator()
                                .id("typing")
                                .padding(.top, Spacing.sm)
                        }

                        // Error with retry
                        if viewModel.failedMessage != nil {
                            retryBanner
                                .padding(.top, Spacing.sm)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(Motion.easeOut) {
                        proxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isSendingMessage) {
                    if viewModel.isSendingMessage {
                        withAnimation(Motion.easeOut) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }

            // Quick prompts
            if viewModel.showQuickPrompts {
                quickPromptsSection
            }

            Divider().overlay(ColorTokens.divider)

            // Input bar
            inputBar
        }
        .background(ColorTokens.background)
        .task {
            // If coming from history, status may not be loaded yet
            if viewModel.tutorStatus == nil {
                await viewModel.loadStatus(contentId: contentId, contentTitle: contentTitle)
            }
            await viewModel.loadConversation()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(ColorTokens.gold)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Spacing.xs) {
                    Text("AI Tutor")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.isLimited {
                        Text("Limited")
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.warning.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(contentTitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Welcome Message

    private var welcomeMessage: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.gold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.gold)
                }

                Text("AI Tutor")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            Text(viewModel.isLimited
                ? "Hi! I can help with this video's key concepts, though I don't have the full transcript yet."
                : "Hi! I'm your AI tutor for this video. Ask me anything — I've read the full transcript.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    // MARK: - Quick Prompts

    private var quickPromptsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(viewModel.quickPrompts) { prompt in
                    Button {
                        Haptics.light()
                        Task { await viewModel.sendQuickPrompt(prompt) }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: iconForPrompt(prompt.id))
                                .font(.system(size: 12))
                            Text(prompt.label)
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: Spacing.xs) {
            // Rate limit warning
            if viewModel.isRateLimited {
                Text("Slow down — give the tutor a moment")
                    .font(Typography.micro)
                    .foregroundStyle(ColorTokens.warning)
                    .padding(.horizontal, Spacing.lg)
            }

            // Character count (visible at 1800+)
            if viewModel.characterCount >= 1800 {
                HStack {
                    Spacer()
                    Text("\(viewModel.characterCount)/\(viewModel.maxCharacters)")
                        .font(Typography.micro)
                        .foregroundStyle(characterCountColor)
                        .padding(.horizontal, Spacing.lg)
                }
            }

            HStack(spacing: Spacing.sm) {
                TextField("Ask about this video...", text: $viewModel.inputText, axis: .vertical)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .tint(ColorTokens.gold)
                    .lineLimit(1...4)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onChange(of: viewModel.inputText) {
                        if viewModel.inputText.count > viewModel.maxCharacters {
                            viewModel.inputText = String(viewModel.inputText.prefix(viewModel.maxCharacters))
                        }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.canSend ? ColorTokens.gold : ColorTokens.textTertiary)
                }
                .disabled(!viewModel.canSend)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Retry Banner

    private var retryBanner: some View {
        Button {
            Task { await viewModel.retryFailedMessage() }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(ColorTokens.error)
                Text("Failed to send. Tap to retry.")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.error)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier Upgrade Message

    private var tierUpgradeMessage: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(ColorTokens.success)
            Text("Transcript now available — I can answer more detailed questions!")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.success)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Helpers

    private func isConsecutive(at index: Int) -> Bool {
        guard index > 0 else { return false }
        return viewModel.messages[index].role == viewModel.messages[index - 1].role
    }

    private var characterCountColor: Color {
        if viewModel.characterCount >= 1950 { return ColorTokens.error }
        if viewModel.characterCount >= 1800 { return ColorTokens.warning }
        return ColorTokens.textTertiary
    }

    private func iconForPrompt(_ id: String) -> String {
        switch id {
        case "summarize":       return "lightbulb.fill"
        case "simpler":         return "arrow.2.squarepath"
        case "example":         return "doc.text.fill"
        case "prerequisites":   return "questionmark.circle.fill"
        case "quiz_me":         return "brain.fill"
        case "key_takeaways":   return "star.fill"
        default:                return "sparkles"
        }
    }
}
