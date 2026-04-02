import SwiftUI

struct CreateNoteRequestSheet: View {
    var onCreated: ((NoteRequest) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var desc = ""
    @State private var domain = ""
    @State private var difficulty = "intermediate"
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage: String?

    private let service = NoteRequestService()

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !domain.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        ScaleUpTextField(label: "Title", icon: "textformat", text: $title, autocapitalization: .words)

                        ScaleUpTextField(label: "Description (optional)", icon: "text.alignleft", text: $desc, autocapitalization: .sentences)

                        ScaleUpTextField(label: "Domain / Subject", icon: "folder.fill", text: $domain, autocapitalization: .words)

                        // Difficulty picker
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Difficulty")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                            HStack(spacing: Spacing.sm) {
                                ForEach(["beginner", "intermediate", "advanced"], id: \.self) { level in
                                    Button {
                                        difficulty = level
                                    } label: {
                                        Text(level.capitalized)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(difficulty == level ? .white : ColorTokens.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(difficulty == level ? ColorTokens.gold : ColorTokens.surface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        PrimaryButton(
                            title: isSubmitting ? "Submitting..." : "Submit Request",
                            icon: "paperplane.fill",
                            isLoading: isSubmitting,
                            isDisabled: !isValid
                        ) {
                            Task { await submit() }
                        }

                        Spacer().frame(height: Spacing.xxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Request Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }

    // MARK: - Submit

    private func submit() async {
        isSubmitting = true
        do {
            let request = try await service.createRequest(
                title: title.trimmingCharacters(in: .whitespaces),
                description: desc.isEmpty ? nil : desc.trimmingCharacters(in: .whitespaces),
                domain: domain.trimmingCharacters(in: .whitespaces),
                difficulty: difficulty
            )
            Haptics.success()
            onCreated?(request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Haptics.error()
        }
        isSubmitting = false
    }
}
