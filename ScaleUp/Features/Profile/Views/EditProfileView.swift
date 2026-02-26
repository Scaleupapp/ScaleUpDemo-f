import SwiftUI

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let user: User
    var onSave: ((User) -> Void)?

    @State private var viewModel: EditProfileViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    formContent(viewModel: viewModel)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            guard let viewModel else { return }
                            if let updatedUser = await viewModel.save() {
                                onSave?(updatedUser)
                                dismiss()
                            }
                        }
                    }
                    .font(Typography.bodyBold)
                    .foregroundStyle(
                        (viewModel?.hasChanges == true && viewModel?.isSaving == false && viewModel?.isBioOverLimit == false)
                            ? ColorTokens.primary
                            : ColorTokens.textTertiaryDark
                    )
                    .disabled(
                        viewModel?.hasChanges != true ||
                        viewModel?.isSaving == true ||
                        viewModel?.isBioOverLimit == true
                    )
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = EditProfileViewModel(
                    userService: dependencies.userService,
                    hapticManager: dependencies.hapticManager
                )
                vm.populate(from: user)
                viewModel = vm
            }
        }
        .interactiveDismissDisabled(viewModel?.isSaving == true)
    }

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(viewModel: EditProfileViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Avatar Preview
                avatarSection

                // Error Banner
                if let error = viewModel.error {
                    errorBanner(message: error.localizedDescription)
                }

                // Personal Information
                personalSection(viewModel: viewModel)

                // About
                aboutSection(viewModel: viewModel)

                // Contact
                contactSection(viewModel: viewModel)

                // Saving Overlay
                if viewModel.isSaving {
                    savingOverlay
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: Spacing.sm) {
            CreatorAvatar(
                imageURL: user.profilePicture,
                name: "\(user.firstName) \(user.lastName)",
                size: 80
            )

            Text("Change Photo")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.primary)
                .opacity(0.5) // Placeholder — not yet functional
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(ColorTokens.error)

            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.error)

            Spacer()
        }
        .padding(Spacing.sm)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Personal Section

    @ViewBuilder
    private func personalSection(viewModel: EditProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Personal Information")

            VStack(spacing: Spacing.sm) {
                fieldRow(label: "First Name") {
                    styledTextField(text: Binding(
                        get: { viewModel.firstName },
                        set: { viewModel.firstName = $0 }
                    ), placeholder: "First name")
                }

                fieldRow(label: "Last Name") {
                    styledTextField(text: Binding(
                        get: { viewModel.lastName },
                        set: { viewModel.lastName = $0 }
                    ), placeholder: "Last name")
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private func aboutSection(viewModel: EditProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("About")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Bio")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                TextEditor(text: Binding(
                    get: { viewModel.bio },
                    set: { viewModel.bio = $0 }
                ))
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(Spacing.sm)
                .background(ColorTokens.surfaceElevatedDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                HStack {
                    Spacer()
                    Text(viewModel.bioCharacterCountText)
                        .font(Typography.caption)
                        .foregroundStyle(
                            viewModel.isBioOverLimit
                                ? ColorTokens.error
                                : ColorTokens.textTertiaryDark
                        )
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Contact Section

    @ViewBuilder
    private func contactSection(viewModel: EditProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Contact")

            VStack(spacing: Spacing.sm) {
                fieldRow(label: "Phone") {
                    styledTextField(text: Binding(
                        get: { viewModel.phone },
                        set: { viewModel.phone = $0 }
                    ), placeholder: "+1 (555) 000-0000")
                    .keyboardType(.phonePad)
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(ColorTokens.primary)
            Text("Saving changes...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Reusable Helpers

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Typography.titleMedium)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            content()
        }
    }

    @ViewBuilder
    private func styledTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(Spacing.sm)
            .background(ColorTokens.surfaceElevatedDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}
