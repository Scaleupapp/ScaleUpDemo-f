import SwiftUI

struct CreatorApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreatorApplicationViewModel()
    var onSubmitted: ((CreatorApplication) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar

                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            switch viewModel.currentStep {
                            case .domain: domainStep
                            case .experience: experienceStep
                            case .links: linksStep
                            case .review: reviewStep
                            }
                        }
                        .padding(Spacing.md)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.error)
                            .padding(.horizontal, Spacing.md)
                    }

                    // Navigation buttons
                    navigationButtons
                }

                // Success overlay
                if let app = viewModel.submittedApplication {
                    successOverlay(app)
                }
            }
            .navigationTitle("Apply as Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CreatorApplicationViewModel.Step.allCases, id: \.rawValue) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? ColorTokens.gold : ColorTokens.surfaceElevated)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Step 1: Domain

    private var domainStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(title: "Your Domain", subtitle: "What area of expertise do you want to create content in?")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Domain")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                TextField("e.g., technology, finance, design", text: $viewModel.domain)
                    .scaleUpField()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Specializations")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                if !viewModel.specializations.isEmpty {
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(viewModel.specializations, id: \.self) { spec in
                            HStack(spacing: 4) {
                                Text(spec)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.gold)
                                Button { viewModel.removeSpecialization(spec) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(ColorTokens.gold.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: Spacing.sm) {
                    TextField("Add specialization", text: $viewModel.newSpecialization)
                        .scaleUpField()
                        .onSubmit { viewModel.addSpecialization() }
                    Button { viewModel.addSpecialization() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(ColorTokens.gold)
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Experience

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(title: "Experience & Motivation", subtitle: "Tell us about your background and why you want to create content.")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Experience")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                TextEditor(text: $viewModel.experience)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(Spacing.sm)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Motivation")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                TextEditor(text: $viewModel.motivation)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(Spacing.sm)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Step 3: Links

    private var linksStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(title: "Content & Social Links", subtitle: "Share sample content and your social profiles.")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Sample Content Links")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    if viewModel.sampleContentLinks.count < 5 {
                        Button { viewModel.addLinkField() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                }

                ForEach(Array(viewModel.sampleContentLinks.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: Spacing.sm) {
                        TextField("https://...", text: $viewModel.sampleContentLinks[index])
                            .scaleUpField()
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                        if viewModel.sampleContentLinks.count > 1 {
                            Button { viewModel.removeLinkField(at: index) } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(ColorTokens.error)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Portfolio URL (optional)")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                TextField("https://yourportfolio.com", text: $viewModel.portfolioUrl)
                    .scaleUpField()
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Social Links (optional)")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                socialField(icon: "link", placeholder: "LinkedIn URL", text: $viewModel.linkedin)
                socialField(icon: "at", placeholder: "Twitter/X handle", text: $viewModel.twitter)
                socialField(icon: "play.rectangle.fill", placeholder: "YouTube channel", text: $viewModel.youtube)
                socialField(icon: "globe", placeholder: "Website", text: $viewModel.website)
            }
        }
    }

    private func socialField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .textInputAutocapitalization(.never)
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            stepHeader(title: "Review Your Application", subtitle: "Make sure everything looks good before submitting.")

            reviewSection(title: "Domain", value: viewModel.domain.capitalized)

            if !viewModel.specializations.isEmpty {
                reviewSection(title: "Specializations", value: viewModel.specializations.joined(separator: ", "))
            }

            reviewSection(title: "Experience", value: viewModel.experience)
            reviewSection(title: "Motivation", value: viewModel.motivation)

            let validLinks = viewModel.sampleContentLinks.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !validLinks.isEmpty {
                reviewSection(title: "Sample Links", value: validLinks.joined(separator: "\n"))
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What happens next?")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.gold)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    bulletPoint("Your application will be reviewed by Core and Anchor creators in your domain")
                    bulletPoint("1 Anchor endorsement or 2 Core endorsements = approved")
                    bulletPoint("You'll start as a Rising creator and can work your way up")
                }
            }
            .padding(Spacing.md)
            .background(ColorTokens.gold.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(ColorTokens.gold)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func reviewSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: Spacing.sm) {
            if viewModel.currentStep != .domain {
                SecondaryButton(title: "Back", icon: "chevron.left") {
                    viewModel.back()
                }
            }

            if viewModel.currentStep == .review {
                PrimaryButton(
                    title: "Submit Application",
                    icon: "paperplane.fill",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canProceed
                ) {
                    Task { await viewModel.submit() }
                }
            } else {
                PrimaryButton(
                    title: "Continue",
                    icon: "chevron.right",
                    isDisabled: !viewModel.canProceed
                ) {
                    viewModel.next()
                }
            }
        }
        .padding(Spacing.md)
    }

    // MARK: - Success Overlay

    private func successOverlay(_ app: CreatorApplication) -> some View {
        ZStack {
            ColorTokens.background.opacity(0.95).ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(ColorTokens.gold)

                Text("Application Submitted!")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Core and Anchor creators in your domain will review your application. You'll be notified when it's approved.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                PrimaryButton(title: "Done") {
                    onSubmitted?(app)
                    dismiss()
                }
                .padding(.horizontal, Spacing.xl)
            }
        }
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(subtitle)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}

// MARK: - ScaleUp Field Modifier

private extension View {
    func scaleUpField() -> some View {
        self.font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(Spacing.sm)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
    }
}
