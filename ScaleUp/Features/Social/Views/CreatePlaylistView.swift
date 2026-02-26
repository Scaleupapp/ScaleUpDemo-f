import SwiftUI

// MARK: - Create Playlist View

struct CreatePlaylistView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    /// Callback fired with the newly created playlist on success.
    var onCreated: ((Playlist) -> Void)?

    // MARK: - State

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = true
    @State private var isCreating: Bool = false
    @State private var error: APIError?

    // MARK: - Computed

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Name field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Name")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimaryDark)

                        TextField("My Learning Playlist", text: $name)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .padding(Spacing.md)
                            .background(ColorTokens.surfaceDark)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(
                                        name.isEmpty
                                            ? ColorTokens.surfaceElevatedDark
                                            : ColorTokens.primary.opacity(0.5),
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Description field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Description")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Text("(optional)")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }

                        TextEditor(text: $description)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimaryDark)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(Spacing.md)
                            .background(ColorTokens.surfaceDark)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                            )
                    }

                    // Visibility toggle
                    Toggle(isOn: $isPublic) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: isPublic ? "globe" : "lock.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    isPublic ? ColorTokens.success : ColorTokens.textTertiaryDark
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPublic ? "Public" : "Private")
                                    .font(Typography.bodyBold)
                                    .foregroundStyle(ColorTokens.textPrimaryDark)

                                Text(
                                    isPublic
                                        ? "Anyone can see this playlist"
                                        : "Only you can see this playlist"
                                )
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                            }
                        }
                    }
                    .tint(ColorTokens.primary)
                    .padding(.vertical, Spacing.sm)

                    // Error message
                    if let error {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.error)

                            Text(error.localizedDescription)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.error)
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }

                    Spacer()

                    // Create button
                    PrimaryButton(
                        title: "Create Playlist",
                        isLoading: isCreating,
                        isDisabled: !isFormValid
                    ) {
                        Task { await createPlaylist() }
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    @MainActor
    private func createPlaylist() async {
        guard isFormValid, !isCreating else { return }
        isCreating = true
        error = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let playlist = try await dependencies.socialService.createPlaylist(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                isPublic: isPublic
            )
            dependencies.hapticManager.success()
            onCreated?(playlist)
            dismiss()
        } catch let apiError as APIError {
            self.error = apiError
            dependencies.hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            dependencies.hapticManager.error()
        }

        isCreating = false
    }
}
