import SwiftUI

// MARK: - Application Review View

struct ApplicationReviewView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel: ApplicationReviewViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.applications.isEmpty {
                    applicationSkeletonView
                } else if let error = viewModel.error, viewModel.applications.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadApplications() }
                        }
                    )
                } else if viewModel.applications.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Applications",
                        subtitle: "There are no creator applications to review at this time."
                    )
                } else {
                    applicationListContent(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Application Review")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = ApplicationReviewViewModel(
                    adminService: dependencies.adminService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.applications.isEmpty {
                await viewModel.loadApplications()
            }
        }
    }

    // MARK: - Application List Content

    @ViewBuilder
    private func applicationListContent(viewModel: ApplicationReviewViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.applications) { application in
                    ApplicationCard(
                        application: application,
                        isActionInProgress: viewModel.actionInProgressId == application.id,
                        onReject: {
                            viewModel.applicationToReject = application
                            viewModel.showRejectAlert = true
                        }
                    )
                    .onAppear {
                        // Pagination trigger
                        if application.id == viewModel.applications.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(ColorTokens.primary)
                            .padding(Spacing.md)
                        Spacer()
                    }
                }

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            await viewModel.loadApplications()
        }
        // Reject Alert with note input
        .alert("Reject Application", isPresented: Binding(
            get: { viewModel.showRejectAlert },
            set: { viewModel.showRejectAlert = $0 }
        )) {
            TextField("Reason for rejection (optional)", text: Binding(
                get: { viewModel.rejectNote },
                set: { viewModel.rejectNote = $0 }
            ))
            Button("Cancel", role: .cancel) {
                viewModel.applicationToReject = nil
                viewModel.rejectNote = ""
            }
            Button("Reject", role: .destructive) {
                if let app = viewModel.applicationToReject {
                    let note = viewModel.rejectNote.isEmpty ? nil : viewModel.rejectNote
                    Task {
                        await viewModel.rejectApplication(id: app.id, note: note)
                    }
                }
            }
        } message: {
            if let app = viewModel.applicationToReject {
                Text("Are you sure you want to reject the application for \(app.domain)?")
            }
        }
    }

    // MARK: - Skeleton Loading View

    private var applicationSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonLoader(height: 180, cornerRadius: CornerRadius.medium)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }
}

// MARK: - Application Card

private struct ApplicationCard: View {
    let application: CreatorApplication
    let isActionInProgress: Bool
    let onReject: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("User: \(application.userId)")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    Text(application.domain)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()

                ApplicationStatusBadge(status: application.status)
            }

            // Specializations
            if !application.specializations.isEmpty {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(application.specializations, id: \.self) { spec in
                        Text(spec)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(ColorTokens.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            // Expandable Detail
            if isExpanded {
                expandedContent
            }

            // Expand/Collapse Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.primary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.primary)
                }
            }
            .buttonStyle(.plain)

            // Action Buttons
            if application.status == .pending {
                HStack(spacing: Spacing.md) {
                    // Approve button (placeholder)
                    Button {
                        // Approve goes through CreatorEndpoints, not admin
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.success)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(ColorTokens.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .buttonStyle(.plain)

                    // Reject button
                    Button(action: onReject) {
                        HStack(spacing: Spacing.xs) {
                            if isActionInProgress {
                                ProgressView()
                                    .tint(ColorTokens.error)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text("Reject")
                        }
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(ColorTokens.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }
                    .buttonStyle(.plain)
                    .disabled(isActionInProgress)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider()
                .overlay(ColorTokens.surfaceElevatedDark)

            // Motivation
            if let motivation = application.motivation, !motivation.isEmpty {
                DetailRow(label: "Motivation", value: motivation)
            }

            // Experience
            if let experience = application.experience, !experience.isEmpty {
                DetailRow(label: "Experience", value: experience)
            }

            // Portfolio
            if let portfolioUrl = application.portfolioUrl, !portfolioUrl.isEmpty {
                DetailRow(label: "Portfolio", value: portfolioUrl)
            }

            // Sample Content Links
            if let links = application.sampleContentLinks, !links.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Sample Content")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiaryDark)

                    ForEach(links, id: \.self) { link in
                        Text(link)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.info)
                            .lineLimit(1)
                    }
                }
            }

            // Endorsements count
            if let endorsements = application.endorsements {
                DetailRow(label: "Endorsements", value: "\(endorsements.count)")
            }

            // Created date
            DetailRow(label: "Applied", value: formattedDate(application.createdAt))
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: dateString) else {
            isoFormatter.formatOptions = [.withInternetDateTime]
            guard let fallbackDate = isoFormatter.date(from: dateString) else {
                return dateString
            }
            return formatForDisplay(fallbackDate)
        }
        return formatForDisplay(date)
    }

    private func formatForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }
}

// MARK: - Application Status Badge

private struct ApplicationStatusBadge: View {
    let status: ApplicationStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(Typography.micro)
            .foregroundStyle(statusColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .pending:
            return ColorTokens.warning
        case .approved:
            return ColorTokens.success
        case .rejected:
            return ColorTokens.error
        }
    }
}
