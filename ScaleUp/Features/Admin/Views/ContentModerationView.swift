import SwiftUI

// MARK: - Content Moderation View Model

@Observable
@MainActor
final class ContentModerationViewModel {

    // MARK: - Published State

    var contentItems: [Content] = []
    var isLoading: Bool = false
    var error: APIError?

    /// Tracks the content ID currently being moderated.
    var actionInProgressId: String?

    /// Alert state for rejection with note.
    var showRejectAlert: Bool = false
    var contentToReject: Content?
    var rejectNote: String = ""

    // MARK: - Dependencies

    private let adminService: AdminService
    private let contentService: ContentService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(adminService: AdminService, contentService: ContentService, hapticManager: HapticManager) {
        self.adminService = adminService
        self.contentService = contentService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Content

    /// Fetches content that is under review using the content explore endpoint.
    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            // Fetch content and filter for items needing moderation
            let items = try await contentService.explore(page: 1, limit: 50)
            // Filter for content that is not yet published (processing/ready states need review)
            self.contentItems = items
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Approve Content

    /// Approves content by setting its status to published.
    func approveContent(id: String) async {
        actionInProgressId = id

        do {
            try await adminService.moderateContent(id: id, status: "published", note: nil)
            if let index = contentItems.firstIndex(where: { $0.id == id }) {
                contentItems.remove(at: index)
            }
            hapticManager.success()
        } catch {
            hapticManager.error()
        }

        actionInProgressId = nil
    }

    // MARK: - Reject Content

    /// Rejects content with an optional note.
    func rejectContent(id: String, note: String?) async {
        actionInProgressId = id

        do {
            try await adminService.moderateContent(id: id, status: "rejected", note: note)
            if let index = contentItems.firstIndex(where: { $0.id == id }) {
                contentItems.remove(at: index)
            }
            hapticManager.success()
        } catch {
            hapticManager.error()
        }

        actionInProgressId = nil
        rejectNote = ""
    }
}

// MARK: - Content Moderation View

struct ContentModerationView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var viewModel: ContentModerationViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.contentItems.isEmpty {
                    contentSkeletonView
                } else if let error = viewModel.error, viewModel.contentItems.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadContent() }
                        }
                    )
                } else if viewModel.contentItems.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "checkmark.shield",
                        title: "All Clear",
                        subtitle: "No content items require moderation at this time."
                    )
                } else {
                    contentListView(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Content Moderation")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = ContentModerationViewModel(
                    adminService: dependencies.adminService,
                    contentService: dependencies.contentService,
                    hapticManager: dependencies.hapticManager
                )
            }
        }
        .task {
            if let viewModel, viewModel.contentItems.isEmpty {
                await viewModel.loadContent()
            }
        }
    }

    // MARK: - Content List View

    @ViewBuilder
    private func contentListView(viewModel: ContentModerationViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.contentItems) { item in
                    ContentModerationCard(
                        content: item,
                        isActionInProgress: viewModel.actionInProgressId == item.id,
                        onApprove: {
                            Task { await viewModel.approveContent(id: item.id) }
                        },
                        onReject: {
                            viewModel.contentToReject = item
                            viewModel.showRejectAlert = true
                        }
                    )
                }

                // Bottom spacing
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            await viewModel.loadContent()
        }
        // Reject Alert with note input
        .alert("Reject Content", isPresented: Binding(
            get: { viewModel.showRejectAlert },
            set: { viewModel.showRejectAlert = $0 }
        )) {
            TextField("Reason for rejection (optional)", text: Binding(
                get: { viewModel.rejectNote },
                set: { viewModel.rejectNote = $0 }
            ))
            Button("Cancel", role: .cancel) {
                viewModel.contentToReject = nil
                viewModel.rejectNote = ""
            }
            Button("Reject", role: .destructive) {
                if let content = viewModel.contentToReject {
                    let note = viewModel.rejectNote.isEmpty ? nil : viewModel.rejectNote
                    Task {
                        await viewModel.rejectContent(id: content.id, note: note)
                    }
                }
            }
        } message: {
            if let content = viewModel.contentToReject {
                Text("Are you sure you want to reject \"\(content.title)\"?")
            }
        }
    }

    // MARK: - Skeleton Loading View

    private var contentSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonLoader(height: 160, cornerRadius: CornerRadius.medium)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }
}

// MARK: - Content Moderation Card

private struct ContentModerationCard: View {
    let content: Content
    let isActionInProgress: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {

            // Header Row
            HStack(alignment: .top) {
                // Content Type Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(contentTypeColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: contentTypeIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(contentTypeColor)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(content.title)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(2)

                    Text(content.creator.firstName + " " + content.creator.lastName)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                }

                Spacer()

                ContentStatusBadge(status: content.status)
            }

            // Metadata Row
            HStack(spacing: Spacing.md) {
                MetadataItem(
                    icon: "eye",
                    value: "\(content.viewCount)"
                )

                MetadataItem(
                    icon: "heart",
                    value: "\(content.likeCount)"
                )

                if let duration = content.duration {
                    MetadataItem(
                        icon: "clock",
                        value: formatDuration(duration)
                    )
                }

                Spacer()

                Text(formattedDate(content.createdAt))
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            // Tags
            if !content.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(content.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(ColorTokens.surfaceElevatedDark)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Action Buttons
            HStack(spacing: Spacing.md) {
                Button(action: onApprove) {
                    HStack(spacing: Spacing.xs) {
                        if isActionInProgress {
                            ProgressView()
                                .tint(ColorTokens.success)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
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
                .disabled(isActionInProgress)

                Button(action: onReject) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "xmark.circle.fill")
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
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Computed Properties

    private var contentTypeIcon: String {
        switch content.contentType {
        case .video:
            return "play.rectangle.fill"
        case .article:
            return "doc.text.fill"
        case .infographic:
            return "chart.bar.doc.horizontal.fill"
        case .podcast:
            return "headphones"
        case .course:
            return "book.fill"
        case .tutorial:
            return "laptopcomputer"
        case .documentation:
            return "doc.fill"
        }
    }

    private var contentTypeColor: Color {
        switch content.contentType {
        case .video:
            return ColorTokens.error
        case .article:
            return ColorTokens.info
        case .infographic:
            return ColorTokens.success
        case .podcast:
            return ColorTokens.warning
        case .course:
            return ColorTokens.primary
        case .tutorial:
            return ColorTokens.primaryLight
        case .documentation:
            return ColorTokens.textSecondaryDark
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

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

// MARK: - Content Status Badge

private struct ContentStatusBadge: View {
    let status: ContentStatus

    var body: some View {
        Text(displayText)
            .font(Typography.micro)
            .foregroundStyle(statusColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var displayText: String {
        switch status {
        case .draft:
            return "Draft"
        case .processing:
            return "Processing"
        case .ready:
            return "Ready"
        case .published:
            return "Published"
        case .unpublished:
            return "Unpublished"
        case .rejected:
            return "Rejected"
        }
    }

    private var statusColor: Color {
        switch status {
        case .draft:
            return ColorTokens.textTertiaryDark
        case .processing:
            return ColorTokens.info
        case .ready:
            return ColorTokens.warning
        case .published:
            return ColorTokens.success
        case .unpublished:
            return ColorTokens.textSecondaryDark
        case .rejected:
            return ColorTokens.error
        }
    }
}

// MARK: - Metadata Item

private struct MetadataItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text(value)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiaryDark)
        }
    }
}
