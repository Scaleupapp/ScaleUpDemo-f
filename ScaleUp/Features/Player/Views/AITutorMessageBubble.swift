import SwiftUI

// MARK: - AI Tutor Message Bubble

struct AITutorMessageBubble: View {
    let message: TutorMessage
    let isConsecutive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            // Assistant avatar
            if message.role == .assistant && !isConsecutive {
                aiAvatar
            } else if message.role == .assistant {
                Spacer().frame(width: 28)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                bubbleContent
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

                // Timestamp
                if !message.timeString.isEmpty {
                    Text(message.timeString)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.top, isConsecutive ? 2 : Spacing.sm)
    }

    // MARK: - AI Avatar

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.gold.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)
        }
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        if message.role == .assistant {
            // Render markdown for assistant messages
            markdownText(message.content)
                .foregroundStyle(ColorTokens.textPrimary)
        } else {
            Text(message.content)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
        }
    }

    // MARK: - Bubble Background

    private var bubbleBackground: Color {
        message.role == .user ? ColorTokens.gold : ColorTokens.surface
    }

    // MARK: - Markdown Rendering

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(Typography.bodySmall)
        } else {
            Text(text)
                .font(Typography.bodySmall)
        }
    }
}
