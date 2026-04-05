import SwiftUI

@Observable
@MainActor
final class PendingApplicationsViewModel {
    var applications: [CreatorApplication] = []
    var isLoading = false
    var errorMessage: String?
    var isActioning = false
    let isAdmin: Bool

    private let adminService = AdminService()
    private let creatorService = CreatorService()

    init(isAdmin: Bool) {
        self.isAdmin = isAdmin
    }

    func loadApplications() async {
        isLoading = true
        errorMessage = nil
        do {
            if isAdmin {
                applications = try await adminService.fetchApplications()
            } else {
                applications = try await creatorService.fetchPendingApplications()
            }
        } catch {
            errorMessage = "\(error)"
            applications = []
        }
        isLoading = false
    }

    /// Admin: direct approve. Creator: endorse (peer endorsement).
    func approveOrEndorse(applicationId: String, note: String?) async {
        isActioning = true
        do {
            if isAdmin {
                try await adminService.approveApplication(id: applicationId, note: note)
            } else {
                try await creatorService.endorseApplication(id: applicationId, note: note)
            }
            Haptics.success()
            await loadApplications()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = isAdmin ? "Failed to approve" : "Failed to endorse"
            Haptics.error()
        }
        isActioning = false
    }

    func reject(applicationId: String, note: String) async {
        isActioning = true
        do {
            if isAdmin {
                try await adminService.rejectApplication(id: applicationId, note: note)
            } else {
                try await creatorService.rejectApplication(id: applicationId, note: note)
            }
            Haptics.success()
            await loadApplications()
        } catch let error as APIError {
            errorMessage = error.errorDescription
            Haptics.error()
        } catch {
            errorMessage = "Failed to reject"
            Haptics.error()
        }
        isActioning = false
    }
}

// MARK: - View

struct PendingApplicationsView: View {
    @State private var viewModel: PendingApplicationsViewModel
    @State private var selectedApp: CreatorApplication?

    init(isAdmin: Bool = false) {
        _viewModel = State(initialValue: PendingApplicationsViewModel(isAdmin: isAdmin))
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.error)
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.error)
                        Spacer()
                        Button { viewModel.errorMessage = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ColorTokens.error)
                        }
                    }
                    .padding(Spacing.sm)
                    .background(ColorTokens.error.opacity(0.1))
                }

                if viewModel.isLoading && viewModel.applications.isEmpty {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                } else if viewModel.applications.isEmpty {
                    emptyState
                } else {
                    applicationList
                }
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
                isAdmin: viewModel.isAdmin,
                isActioning: viewModel.isActioning,
                onApproveOrEndorse: { note in
                    Task {
                        await viewModel.approveOrEndorse(applicationId: app.id, note: note)
                        if viewModel.errorMessage == nil { selectedApp = nil }
                    }
                },
                onReject: { note in
                    Task {
                        await viewModel.reject(applicationId: app.id, note: note)
                        if viewModel.errorMessage == nil { selectedApp = nil }
                    }
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
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
            Spacer()
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

                if let detail = app.statusDetail, !detail.isEmpty {
                    Text(detail)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(2)
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
    var isAdmin: Bool
    var isActioning: Bool
    var onApproveOrEndorse: (String?) -> Void
    var onReject: (String) -> Void

    @State private var approveNote = ""
    @State private var rejectNote = ""
    @State private var showRejectConfirm = false

    private var actionTitle: String { isAdmin ? "Approve" : "Endorse" }
    private var actionButtonTitle: String { isAdmin ? "Approve Application" : "Endorse Application" }

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

                        // Applicant Background
                        if let user = application.applicant {
                            let hasBackground = (user.education != nil && !user.education!.isEmpty) ||
                                (user.workExperience != nil && !user.workExperience!.isEmpty) ||
                                (user.skills != nil && !user.skills!.isEmpty)
                            if hasBackground {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("Applicant Background")
                                        .font(Typography.bodyBold)
                                        .foregroundStyle(ColorTokens.textSecondary)

                                    if let education = user.education, !education.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Education")
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                            ForEach(education) { edu in
                                                HStack(spacing: 6) {
                                                    Image(systemName: "graduationcap")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(ColorTokens.info)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(edu.degree)
                                                            .font(Typography.bodySmall)
                                                            .foregroundStyle(ColorTokens.textPrimary)
                                                        HStack(spacing: 4) {
                                                            Text(edu.institution)
                                                                .font(Typography.micro)
                                                                .foregroundStyle(ColorTokens.textTertiary)
                                                            if let year = edu.yearOfCompletion {
                                                                Text("· \(String(year))")
                                                                    .font(Typography.micro)
                                                                    .foregroundStyle(ColorTokens.textTertiary)
                                                            }
                                                            if edu.currentlyPursuing == true {
                                                                Text("(Current)")
                                                                    .font(Typography.micro)
                                                                    .foregroundStyle(ColorTokens.gold)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(Spacing.sm)
                                        .background(ColorTokens.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                    }

                                    if let work = user.workExperience, !work.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Work Experience")
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                            ForEach(work) { exp in
                                                HStack(spacing: 6) {
                                                    Image(systemName: "briefcase")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(ColorTokens.gold)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(exp.role)
                                                            .font(Typography.bodySmall)
                                                            .foregroundStyle(ColorTokens.textPrimary)
                                                        HStack(spacing: 4) {
                                                            Text(exp.company)
                                                                .font(Typography.micro)
                                                                .foregroundStyle(ColorTokens.textTertiary)
                                                            if let years = exp.years {
                                                                Text("· \(years) yr\(years == 1 ? "" : "s")")
                                                                    .font(Typography.micro)
                                                                    .foregroundStyle(ColorTokens.textTertiary)
                                                            }
                                                            if exp.currentlyWorking == true {
                                                                Text("(Current)")
                                                                    .font(Typography.micro)
                                                                    .foregroundStyle(ColorTokens.gold)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(Spacing.sm)
                                        .background(ColorTokens.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                    }

                                    if let skills = user.skills, !skills.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Skills")
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                            FlowLayout(spacing: 6) {
                                                ForEach(skills, id: \.self) { skill in
                                                    Text(skill.capitalized)
                                                        .font(Typography.micro)
                                                        .foregroundStyle(ColorTokens.textPrimary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(ColorTokens.surfaceElevated)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(Spacing.sm)
                                        .background(ColorTokens.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                    }
                                }

                                Divider().overlay(ColorTokens.divider)
                            }
                        }

                        // Application Details
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
                            linksSection(title: "Sample Content", links: links)
                        }
                        if let url = application.portfolioUrl, !url.isEmpty {
                            linksSection(title: "Portfolio", links: [url])
                        }
                        if let social = application.socialLinks {
                            let socialLinks: [(String, String)] = [
                                ("LinkedIn", social.linkedin),
                                ("Twitter", social.twitter),
                                ("YouTube", social.youtube),
                                ("Website", social.website),
                            ].compactMap { label, val in
                                guard let v = val, !v.isEmpty else { return nil }
                                return (label, v)
                            }
                            if !socialLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Social Links")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textTertiary)
                                    ForEach(socialLinks, id: \.0) { label, url in
                                        if let linkURL = URL(string: url.hasPrefix("http") ? url : "https://\(url)") {
                                            Link(destination: linkURL) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: socialIcon(for: label))
                                                        .font(.system(size: 12))
                                                    Text(label)
                                                        .font(Typography.bodySmall)
                                                    Spacer()
                                                    Image(systemName: "arrow.up.right.square")
                                                        .font(.system(size: 11))
                                                }
                                                .foregroundStyle(ColorTokens.info)
                                            }
                                        } else {
                                            HStack(spacing: 6) {
                                                Image(systemName: socialIcon(for: label))
                                                    .font(.system(size: 12))
                                                Text("\(label): \(url)")
                                                    .font(Typography.bodySmall)
                                                    .foregroundStyle(ColorTokens.textPrimary)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            }
                        }

                        Divider().overlay(ColorTokens.divider)

                        // Approve / Endorse section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(actionTitle)
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimary)
                            TextField("Add a note (optional)", text: $approveNote)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(Spacing.sm)
                                .background(ColorTokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.small)
                                        .stroke(ColorTokens.border, lineWidth: 1)
                                )

                            PrimaryButton(title: actionButtonTitle, icon: "checkmark.seal") {
                                onApproveOrEndorse(approveNote.isEmpty ? nil : approveNote)
                            }
                            .disabled(isActioning)
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
                            .disabled(rejectNote.isEmpty || isActioning)
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

    private func linksSection(title: String, links: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
            ForEach(links, id: \.self) { link in
                if let url = URL(string: link.hasPrefix("http") ? link : "https://\(link)") {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text(link)
                                .font(Typography.bodySmall)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(ColorTokens.info)
                    }
                } else {
                    Text(link)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private func socialIcon(for label: String) -> String {
        switch label {
        case "LinkedIn": return "link"
        case "Twitter": return "at"
        case "YouTube": return "play.rectangle"
        case "Website": return "globe"
        default: return "link"
        }
    }
}
