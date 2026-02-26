import SwiftUI

// MARK: - Creator Application View

struct CreatorApplicationView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CreatorApplicationViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isCheckingStatus {
                        statusCheckingView
                    } else if let application = viewModel.existingApplication {
                        existingApplicationView(application: application, viewModel: viewModel)
                    } else if viewModel.submitSuccess {
                        successView
                    } else {
                        applicationFormView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Creator Program")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CreatorApplicationViewModel(
                    creatorService: dependencies.creatorService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.existingApplication == nil && !viewModel.submitSuccess {
                await viewModel.checkExistingApplication()
            }
        }
    }

    // MARK: - Status Checking View

    private var statusCheckingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .tint(ColorTokens.primary)
                .scaleEffect(1.5)

            Text("Checking application status...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Existing Application View

    @ViewBuilder
    private func existingApplicationView(application: CreatorApplication, viewModel: CreatorApplicationViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xxl)

                switch application.status {
                case .pending:
                    pendingStatusCard(application: application)
                case .approved:
                    approvedStatusCard
                case .rejected:
                    rejectedStatusCard(viewModel: viewModel)
                }

                // Application Details
                applicationDetailsCard(application: application)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Pending Status Card

    @ViewBuilder
    private func pendingStatusCard(application: CreatorApplication) -> some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.warning.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "hourglass")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.warning)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: Spacing.sm) {
                Text("Application Under Review")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Your application is being reviewed by our team. We'll notify you once a decision has been made.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }

            // Endorsements count
            if let endorsements = application.endorsements, !endorsements.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.success)

                    Text("\(endorsements.count) endorsement\(endorsements.count == 1 ? "" : "s")")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.success)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorTokens.success.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Approved Status Card

    private var approvedStatusCard: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.success)
            }

            VStack(spacing: Spacing.sm) {
                Text("Welcome to the Creator Program!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .multilineTextAlignment(.center)

                Text("Your application has been approved. You can now start creating and sharing content with learners.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: "Go to Creator Studio") {
                dismiss()
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Rejected Status Card

    @ViewBuilder
    private func rejectedStatusCard(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.error.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.error)
            }

            VStack(spacing: Spacing.sm) {
                Text("Application Not Approved")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("Unfortunately your application was not approved at this time. You can revise and reapply.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }

            SecondaryButton(title: "Reapply") {
                viewModel.existingApplication = nil
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Application Details Card

    @ViewBuilder
    private func applicationDetailsCard(application: CreatorApplication) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Application Details")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            detailRow(label: "Domain", value: application.domain)

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

            if let motivation = application.motivation, !motivation.isEmpty {
                detailRow(label: "Motivation", value: motivation)
            }

            detailRow(label: "Submitted", value: formatDate(application.createdAt))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Detail Row

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    // MARK: - Application Form View

    @ViewBuilder
    private func applicationFormView(viewModel: CreatorApplicationViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(ColorTokens.primary)

                    Text("Apply to Create")
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    Text("Share your expertise with thousands of learners")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.md)

                // Form Fields
                VStack(spacing: Spacing.lg) {

                    // Domain
                    domainField(viewModel: viewModel)

                    // Specializations
                    specializationsField(viewModel: viewModel)

                    // Motivation
                    motivationField(viewModel: viewModel)

                    // Experience
                    experienceField(viewModel: viewModel)

                    // Portfolio URL
                    portfolioField(viewModel: viewModel)

                    // Sample Content Links
                    sampleLinksField(viewModel: viewModel)
                }
                .padding(.horizontal, Spacing.md)

                // Error Message
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }

                // Submit Button
                PrimaryButton(
                    title: "Submit Application",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.isValid
                ) {
                    Task { await viewModel.submitApplication() }
                }
                .padding(.horizontal, Spacing.md)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
        }
        .loadingOverlay(isPresented: viewModel.isSubmitting, message: "Submitting application...")
    }

    // MARK: - Domain Field

    @ViewBuilder
    private func domainField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Domain *")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            TextField("e.g. Web Development, Data Science, Design", text: Binding(
                get: { viewModel.domain },
                set: { viewModel.domain = $0 }
            ))
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .padding(.horizontal, Spacing.md)
            .frame(height: 52)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
            )
        }
    }

    // MARK: - Specializations Field

    @ViewBuilder
    private func specializationsField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Specializations *")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            // Tag input
            HStack(spacing: Spacing.sm) {
                TextField("Add a specialization", text: Binding(
                    get: { viewModel.newSpecialization },
                    set: { viewModel.newSpecialization = $0 }
                ))
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
                    viewModel.addSpecialization()
                }

                Button {
                    viewModel.addSpecialization()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            viewModel.newSpecialization.trimmingCharacters(in: .whitespaces).isEmpty
                                ? ColorTokens.textTertiaryDark
                                : ColorTokens.primary
                        )
                }
                .disabled(viewModel.newSpecialization.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Chips display
            if !viewModel.specializations.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(viewModel.specializations, id: \.self) { spec in
                        HStack(spacing: Spacing.xs) {
                            Text(spec)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Button {
                                viewModel.removeSpecialization(spec)
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

            if viewModel.specializations.isEmpty {
                Text("At least 1 specialization required")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }
        }
    }

    // MARK: - Motivation Field

    @ViewBuilder
    private func motivationField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Motivation *")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                Spacer()

                Text("\(viewModel.motivationCharCount)/50 min")
                    .font(Typography.caption)
                    .foregroundStyle(
                        viewModel.motivationMeetsMinimum
                            ? ColorTokens.success
                            : ColorTokens.textTertiaryDark
                    )
            }

            TextEditor(text: Binding(
                get: { viewModel.motivation },
                set: { viewModel.motivation = $0 }
            ))
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

            Text("Tell us why you want to become a creator and what value you can bring to learners.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Experience Field

    @ViewBuilder
    private func experienceField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Experience")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            TextEditor(text: Binding(
                get: { viewModel.experience },
                set: { viewModel.experience = $0 }
            ))
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 80)
            .padding(Spacing.sm)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
            )

            Text("Describe your relevant teaching or industry experience.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Portfolio Field

    @ViewBuilder
    private func portfolioField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Portfolio URL")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            TextField("https://yourportfolio.com", text: Binding(
                get: { viewModel.portfolioUrl },
                set: { viewModel.portfolioUrl = $0 }
            ))
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimaryDark)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, Spacing.md)
            .frame(height: 52)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
            )
        }
    }

    // MARK: - Sample Links Field

    @ViewBuilder
    private func sampleLinksField(viewModel: CreatorApplicationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Sample Content Links")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)

            // Input row
            HStack(spacing: Spacing.sm) {
                TextField("https://example.com/content", text: Binding(
                    get: { viewModel.newSampleLink },
                    set: { viewModel.newSampleLink = $0 }
                ))
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
                .onSubmit {
                    viewModel.addSampleLink()
                }

                Button {
                    viewModel.addSampleLink()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            viewModel.newSampleLink.trimmingCharacters(in: .whitespaces).isEmpty
                                ? ColorTokens.textTertiaryDark
                                : ColorTokens.primary
                        )
                }
                .disabled(viewModel.newSampleLink.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Links list
            if !viewModel.sampleLinks.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(viewModel.sampleLinks.enumerated()), id: \.offset) { index, link in
                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.primary)

                            Text(link)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button {
                                viewModel.removeSampleLink(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.error)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorTokens.surfaceDark)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                }
            }

            Text("Links to blogs, videos, or any content you've created.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.success)
            }

            VStack(spacing: Spacing.sm) {
                Text("Application Submitted!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("We've received your application. Our team will review it and get back to you soon.")
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

    // MARK: - Helpers

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}
