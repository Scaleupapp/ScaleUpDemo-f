import SwiftUI

struct TextSourceSheet: View {
    let circleId: String
    let onSubmit: (String, String) -> Void

    @State private var title = ""
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Paste Notes")
                                .font(Typography.titleMedium)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("Add your study notes or text content as a quiz source")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        // Title field
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Title")
                                .font(Typography.captionBold)
                                .foregroundStyle(ColorTokens.textSecondary)
                            TextField("e.g. Chapter 5 Notes", text: $title)
                                .textFieldStyle(.plain)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorTokens.border))
                        }

                        // Text content
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("Content")
                                    .font(Typography.captionBold)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                Spacer()
                                Text("\(text.count) chars")
                                    .font(Typography.micro)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }

                            TextEditor(text: $text)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorTokens.border))
                        }

                        // Submit button
                        Button {
                            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedTitle.isEmpty, !trimmedText.isEmpty else { return }
                            onSubmit(trimmedTitle, trimmedText)
                            dismiss()
                        } label: {
                            Text("Add Source")
                                .font(Typography.bodySmallBold)
                                .foregroundStyle(ColorTokens.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm + 2)
                                .background(ColorTokens.gold, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding(Spacing.md)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
    }
}
