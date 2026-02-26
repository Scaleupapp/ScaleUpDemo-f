import SwiftUI

// MARK: - Edit Creator Profile View

struct EditCreatorProfileView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    let profile: CreatorProfile
    let creatorService: CreatorService
    let hapticManager: HapticManager
    var onSave: ((CreatorProfile) -> Void)?

    // MARK: - Form State

    @State private var bio: String
    @State private var specializations: [String]
    @State private var newSpecialization: String = ""
    @State private var linkedinUrl: String
    @State private var twitterUrl: String
    @State private var youtubeUrl: String
    @State private var websiteUrl: String

    // MARK: - View State

    @State private var isSaving = false
    @State private var error: APIError?

    // MARK: - Init

    init(
        profile: CreatorProfile,
        creatorService: CreatorService,
        hapticManager: HapticManager,
        onSave: ((CreatorProfile) -> Void)? = nil
    ) {
        self.profile = profile
        self.creatorService = creatorService
        self.hapticManager = hapticManager
        self.onSave = onSave

        _bio = State(initialValue: profile.bio ?? "")
        _specializations = State(initialValue: profile.specializations)
        _linkedinUrl = State(initialValue: profile.socialLinks?.linkedin ?? "")
        _twitterUrl = State(initialValue: profile.socialLinks?.twitter ?? "")
        _youtubeUrl = State(initialValue: profile.socialLinks?.youtube ?? "")
        _websiteUrl = State(initialValue: profile.socialLinks?.website ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {

                        // Bio Section
                        bioSection

                        // Specializations Section
                        specializationsSection

                        // Social Links Section
                        socialLinksSection

                        // Error Message
                        if let error {
                            Text(error.localizedDescription)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.md)
                        }

                        Spacer()
                            .frame(height: Spacing.xxl)
                    }
                    .padding(.vertical, Spacing.md)
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
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.primary)
                    .disabled(isSaving)
                }
            }
            .loadingOverlay(isPresented: isSaving, message: "Saving changes...")
        }
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Bio")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Spacer()

                Text("\(bio.count) characters")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            TextEditor(text: $bio)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                )

            Text("Tell learners about yourself and your expertise.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Specializations Section

    private var specializationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Specializations")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            // Add new specialization
            HStack(spacing: Spacing.sm) {
                TextField("Add a specialization", text: $newSpecialization)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 44)
                    .background(ColorTokens.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                    )
                    .onSubmit {
                        addSpecialization()
                    }

                Button {
                    addSpecialization()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            newSpecialization.trimmingCharacters(in: .whitespaces).isEmpty
                                ? ColorTokens.textTertiaryDark
                                : ColorTokens.primary
                        )
                }
                .disabled(newSpecialization.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Current specializations
            if !specializations.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(specializations, id: \.self) { spec in
                        HStack(spacing: Spacing.xs) {
                            Text(spec)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Button {
                                specializations.removeAll { $0 == spec }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(ColorTokens.primary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Social Links Section

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Social Links")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.md) {
                socialLinkField(
                    icon: "link.circle.fill",
                    label: "LinkedIn",
                    placeholder: "https://linkedin.com/in/yourname",
                    text: $linkedinUrl
                )

                socialLinkField(
                    icon: "at.circle.fill",
                    label: "Twitter",
                    placeholder: "https://twitter.com/yourhandle",
                    text: $twitterUrl
                )

                socialLinkField(
                    icon: "play.circle.fill",
                    label: "YouTube",
                    placeholder: "https://youtube.com/@yourchannel",
                    text: $youtubeUrl
                )

                socialLinkField(
                    icon: "globe",
                    label: "Website",
                    placeholder: "https://yourwebsite.com",
                    text: $websiteUrl
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Social Link Field

    @ViewBuilder
    private func socialLinkField(icon: String, label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.primary)

                Text(label)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }

            TextField(placeholder, text: text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimaryDark)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.md)
                .frame(height: 44)
                .background(ColorTokens.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func addSpecialization() {
        let trimmed = newSpecialization.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !specializations.contains(trimmed) else { return }
        specializations.append(trimmed)
        newSpecialization = ""
        hapticManager.selection()
    }

    @MainActor
    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil

        // Build social links dictionary
        var socialLinksDict: [String: String] = [:]
        if !linkedinUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            socialLinksDict["linkedin"] = linkedinUrl.trimmingCharacters(in: .whitespaces)
        }
        if !twitterUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            socialLinksDict["twitter"] = twitterUrl.trimmingCharacters(in: .whitespaces)
        }
        if !youtubeUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            socialLinksDict["youtube"] = youtubeUrl.trimmingCharacters(in: .whitespaces)
        }
        if !websiteUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            socialLinksDict["website"] = websiteUrl.trimmingCharacters(in: .whitespaces)
        }

        do {
            let updatedProfile = try await creatorService.updateProfile(
                bio: bio.isEmpty ? nil : bio,
                expertise: specializations.isEmpty ? nil : specializations,
                socialLinks: socialLinksDict.isEmpty ? nil : socialLinksDict
            )
            hapticManager.success()
            onSave?(updatedProfile)
            dismiss()
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isSaving = false
    }
}
