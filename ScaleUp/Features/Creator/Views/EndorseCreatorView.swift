import SwiftUI

// MARK: - Endorse Creator View

struct EndorseCreatorView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    let applicationId: String
    let application: CreatorApplication?

    // MARK: - State

    @State private var endorsementNote: String = ""
    @State private var isSubmitting = false
    @State private var error: APIError?
    @State private var isSuccess = false

    // MARK: - Init

    init(applicationId: String, application: CreatorApplication? = nil) {
        self.applicationId = applicationId
        self.application = application
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if isSuccess {
                    successView
                } else {
                    endorseFormContent
                }
            }
            .navigationTitle("Endorse Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .disabled(isSubmitting)
                }
            }
            .loadingOverlay(isPresented: isSubmitting, message: "Submitting endorsement...")
        }
    }

    // MARK: - Endorse Form Content

    private var endorseFormContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Header
                endorseHeader

                // Application Details (if available)
                if let application {
                    applicationDetailsSection(application: application)
                }

                // Endorsement Note
                noteSection

                // Error Message
                if let error {
                    Text(error.localizedDescription)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }

                // Submit Button
                PrimaryButton(
                    title: "Endorse",
                    isLoading: isSubmitting
                ) {
                    Task { await submitEndorsement() }
                }
                .padding(.horizontal, Spacing.md)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Endorse Header

    private var endorseHeader: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "hand.thumbsup.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.primary)

            Text("Endorse This Application")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Your endorsement helps the review team make a decision.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Application Details Section

    @ViewBuilder
    private func applicationDetailsSection(application: CreatorApplication) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Application Details")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            // Domain
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Domain")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Text(application.domain)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
            }

            // Specializations
            if !application.specializations.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Specializations")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(application.specializations, id: \.self) { spec in
                            Text(spec)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textPrimaryDark)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(ColorTokens.surfaceElevatedDark)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Motivation excerpt
            if let motivation = application.motivation, !motivation.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Motivation")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Text(motivation)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(4)
                }
            }

            // Experience excerpt
            if let experience = application.experience, !experience.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Experience")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    Text(experience)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .lineLimit(3)
                }
            }

            // Current endorsements
            if let endorsements = application.endorsements, !endorsements.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.success)

                    Text("\(endorsements.count) existing endorsement\(endorsements.count == 1 ? "" : "s")")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.success)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Endorsement Note (optional)")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            TextEditor(text: $endorsementNote)
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

            Text("Share why you think this person would make a great creator.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.success)
            }

            VStack(spacing: Spacing.sm) {
                Text("Endorsement Submitted!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Thank you for endorsing this creator application. Your support helps build a stronger community.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            PrimaryButton(title: "Done") {
                dismiss()
            }
            .padding(.horizontal, Spacing.md)

            Spacer()
        }
    }

    // MARK: - Submit Endorsement

    @MainActor
    private func submitEndorsement() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil

        do {
            try await dependencies.apiClient.requestVoid(
                CreatorEndpoints.endorse(
                    applicationId: applicationId,
                    note: endorsementNote.isEmpty ? nil : endorsementNote
                )
            )
            dependencies.hapticManager.success()
            isSuccess = true
        } catch let apiError as APIError {
            self.error = apiError
            dependencies.hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            dependencies.hapticManager.error()
        }

        isSubmitting = false
    }
}
