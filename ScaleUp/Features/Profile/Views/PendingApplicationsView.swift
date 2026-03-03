import SwiftUI

@Observable
@MainActor
final class PendingApplicationsViewModel {
    var applications: [CreatorApplication] = []
    var isLoading = false
    var errorMessage: String?

    private let creatorService = CreatorService()

    func loadApplications() async {
        isLoading = true
        applications = (try? await creatorService.fetchPendingApplications()) ?? []
        isLoading = false
    }

    func endorse(applicationId: String, note: String?) async {
        do {
            try await creatorService.endorseApplication(id: applicationId, note: note)
            Haptics.success()
            await loadApplications()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to endorse"
            Haptics.error()
        }
    }

    func reject(applicationId: String, note: String) async {
        do {
            try await creatorService.rejectApplication(id: applicationId, note: note)
            Haptics.success()
            await loadApplications()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to reject"
            Haptics.error()
        }
    }
}

// MARK: - View

struct PendingApplicationsView: View {
    @State private var viewModel = PendingApplicationsViewModel()
    @State private var selectedApp: CreatorApplication?

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.applications.isEmpty {
                ProgressView().tint(ColorTokens.gold)
            } else if viewModel.applications.isEmpty {
                emptyState
            } else {
                applicationList
            }
        }
        .navigationTitle("Review Applications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadApplications()
        }
        .refreshable {
            await viewModel.loadApplications()
        }
        .sheet(item: $selectedApp) { app in
            ApplicationReviewSheet(
                application: app,
                onEndorse: { note in
                    Task { await viewModel.endorse(applicationId: app.id, note: note) }
                    selectedApp = nil
                },
                onReject: { note in
                    Task { await viewModel.reject(applicationId: app.id, note: note) }
                    selectedApp = nil
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No pending applications")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Check back later for new applications in your domain")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }

    private var applicationList: some View {
        List(viewModel.applications) { app in
            Button {
                selectedApp = app
            } label: {
                applicationRow(app)
            }
            .listRowBackground(ColorTokens.surface)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private func applicationRow(_ app: CreatorApplication) -> some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 44, height: 44)
                Text(applicantInitials(app))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(applicantName(app))
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Text(app.domain.capitalized)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.gold)
                    if let count = app.endorsements?.count, count > 0 {
                        Text("\(count) endorsement\(count == 1 ? "" : "s")")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            statusBadge(app.status)
        }
    }

    private func statusBadge(_ status: ApplicationStatus) -> some View {
        Text(status.displayName)
            .font(Typography.micro)
            .foregroundStyle(status.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func applicantName(_ app: CreatorApplication) -> String {
        app.applicant?.displayName ?? "Applicant"
    }

    private func applicantInitials(_ app: CreatorApplication) -> String {
        guard let user = app.applicant else { return "?" }
        let first = user.firstName.prefix(1)
        let last = (user.lastName ?? "").prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Application Review Sheet

struct ApplicationReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let application: CreatorApplication
    var onEndorse: (String?) -> Void
    var onReject: (String) -> Void

    @State private var endorseNote = ""
    @State private var rejectNote = ""
    @State private var showRejectConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Applicant info
                        VStack(spacing: Spacing.sm) {
                            Text(application.applicant?.displayName ?? "Applicant")
                                .font(Typography.titleMedium)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text(application.domain.capitalized)
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.gold)
                        }

                        // Details
                        if let specs = application.specializations, !specs.isEmpty {
                            detailSection(title: "Specializations", value: specs.joined(separator: ", "))
                        }
                        if let exp = application.experience, !exp.isEmpty {
                            detailSection(title: "Experience", value: exp)
                        }
                        if let mot = application.motivation, !mot.isEmpty {
                            detailSection(title: "Motivation", value: mot)
                        }
                        if let links = application.sampleContentLinks, !links.isEmpty {
                            detailSection(title: "Sample Content", value: links.joined(separator: "\n"))
                        }

                        Divider().overlay(ColorTokens.divider)

                        // Endorse section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Endorse")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimary)
                            TextField("Add a note (optional)", text: $endorseNote)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.small)
                                        .stroke(ColorTokens.border, lineWidth: 1)
                                )

                            PrimaryButton(title: "Endorse Application", icon: "checkmark.seal") {
                                onEndorse(endorseNote.isEmpty ? nil : endorseNote)
                            }
                        }

                        // Reject section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Reject")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.error)
                            TextField("Justification (required)", text: $rejectNote)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.small)
                                        .stroke(ColorTokens.border, lineWidth: 1)
                                )

                            Button {
                                showRejectConfirm = true
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Reject Application")
                                        .font(Typography.bodyBold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(rejectNote.isEmpty ? ColorTokens.buttonDisabledBg : ColorTokens.error)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            }
                            .disabled(rejectNote.isEmpty)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Review Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .alert("Reject Application?", isPresented: $showRejectConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reject", role: .destructive) {
                    onReject(rejectNote)
                }
            } message: {
                Text("This will reject the application. The applicant can reapply after 30 days.")
            }
        }
    }

    private func detailSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}
