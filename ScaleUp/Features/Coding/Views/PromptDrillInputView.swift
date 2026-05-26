import SwiftUI

struct PromptDrillInputView: View {
    @Bindable var session: DrillSession
    @State private var promptText: String = ""
    @State private var showBriefRecap: Bool = false
    @FocusState private var editorFocused: Bool

    // Per the backend Joi validator: prompt_text is min 10 max 8000 chars.
    // We're using min 30 client-side to nudge learners toward specificity
    // (a 10-char prompt is almost certainly a poor answer).
    private let minChars = 30
    private let maxChars = 8000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                briefRecap

                editorSection

                Color.clear.frame(height: 80) // bottom inset for sticky submit bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            submitBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
        .onAppear {
            // Auto-focus the editor once the view is on screen — this is a
            // typing-heavy view, no reason to require a tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                editorFocused = true
            }
        }
    }

    // MARK: - Brief recap (collapsible)

    @ViewBuilder
    private var briefRecap: some View {
        if let brief = session.todayDrill?.brief, !brief.isEmpty {
            DisclosureGroup(isExpanded: $showBriefRecap) {
                Text(brief)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("View brief", systemImage: "doc.text")
                    .font(.subheadline.weight(.medium))
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your prompt")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if promptText.isEmpty {
                    Text("Write the prompt you'd send to an LLM to solve this task. Be specific — what should it do, what should the output look like, what edge cases matter?")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $promptText)
                    .font(.system(.body, design: .monospaced))
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minHeight: 220)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            characterCountRow
        }
    }

    private var characterCountRow: some View {
        HStack {
            Text("\(promptText.count) / \(maxChars)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(promptText.count < minChars ? .secondary : .secondary)

            Spacer()

            if promptText.count > 0 && promptText.count < minChars {
                Text("\(minChars - promptText.count) more to submit")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if promptText.count > maxChars {
                Text("Over max")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Submit bar

    private var submitBar: some View {
        Button {
            // Defensive: trim trailing whitespace before submit
            let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard canSubmit else { return }
            editorFocused = false
            Task { await session.submit(.prompt(text: trimmed)) }
        } label: {
            HStack {
                if canSubmit {
                    Text("Submit for grading")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                } else {
                    Text(disabledLabel)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.25))
            .foregroundStyle(canSubmit ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        let trimmedCount = promptText.trimmingCharacters(in: .whitespacesAndNewlines).count
        return trimmedCount >= minChars && trimmedCount <= maxChars
    }

    private var disabledLabel: String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Start writing your prompt" }
        if trimmed.count < minChars { return "Write at least \(minChars) characters" }
        if trimmed.count > maxChars { return "Too long — trim to \(maxChars)" }
        return "Submit for grading"
    }
}
