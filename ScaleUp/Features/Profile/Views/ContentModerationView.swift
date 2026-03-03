import SwiftUI

@Observable
@MainActor
final class ContentModerationViewModel {
    var content: [Content] = []
    var isLoading = false
    var selectedTab = 0 // 0 = Reported, 1 = All
    var totalCount = 0
    var hasNextPage = false
    var currentPage = 1

    // Search
    var searchText = ""
    var searchTask: Task<Void, Never>?
    var isSearching = false

    // Remove action
    var contentToRemove: Content?
    var showRemoveSheet = false
    var removalReason = ""
    var isRemoving = false

    // Dismiss action
    var contentToDismiss: Content?
    var showDismissConfirm = false

    private let adminService = AdminService()

    func loadContent(reset: Bool = true) async {
        if reset {
            currentPage = 1
            isLoading = true
        }
        do {
            let result = try await adminService.fetchContent(
                status: nil,
                minReports: selectedTab == 0 ? 3 : nil,
                search: searchText.isEmpty ? nil : searchText,
                page: currentPage
            )
            if reset {
                content = result.items
            } else {
                content.append(contentsOf: result.items)
            }
            totalCount = result.total
            hasNextPage = result.hasNextPage
        } catch {
            // Silently fail
        }
        isLoading = false
        isSearching = false
    }

    func loadMore() async {
        guard hasNextPage, !isLoading else { return }
        currentPage += 1
        await loadContent(reset: false)
    }

    func debouncedSearch() {
        searchTask?.cancel()
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await loadContent()
        }
    }

    func removeContent() async {
        guard let item = contentToRemove, !removalReason.isEmpty else { return }
        isRemoving = true
        do {
            try await adminService.removeContent(id: item.id, reason: removalReason)
            Haptics.success()
            content.removeAll { $0.id == item.id }
            totalCount = max(0, totalCount - 1)
            removalReason = ""
            showRemoveSheet = false
        } catch {
            Haptics.error()
        }
        isRemoving = false
    }

    func dismissReports() async {
        guard let item = contentToDismiss else { return }
        do {
            try await adminService.dismissReports(id: item.id)
            Haptics.success()
            content.removeAll { $0.id == item.id }
            totalCount = max(0, totalCount - 1)
        } catch {
            Haptics.error()
        }
    }
}

struct ContentModerationView: View {
    @State private var viewModel = ContentModerationViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: Spacing.sm) {
                    moderationTab("Reported", tab: 0, icon: "exclamationmark.triangle.fill")
                    moderationTab("All Content", tab: 1, icon: "doc.text.fill")
                    Spacer()
                    if viewModel.totalCount > 0 {
                        Text("\(viewModel.totalCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTokens.gold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

                // Search bar
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)

                    TextField("Search content by title...", text: $viewModel.searchText)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            viewModel.debouncedSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }

                    if viewModel.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(ColorTokens.gold)
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 10)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)

                // Content
                if viewModel.isLoading && viewModel.content.isEmpty {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                } else if viewModel.content.isEmpty {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: viewModel.searchText.isEmpty
                              ? (viewModel.selectedTab == 0 ? "checkmark.seal" : "doc.text")
                              : "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(viewModel.searchText.isEmpty
                             ? (viewModel.selectedTab == 0 ? "No reported content" : "No content found")
                             : "No results for \"\(viewModel.searchText)\"")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.content) { item in
                            moderationRow(item)
                                .listRowBackground(ColorTokens.surface)
                                .listRowSeparatorTint(ColorTokens.border.opacity(0.3))
                        }

                        // Load more
                        if viewModel.hasNextPage {
                            Button {
                                Task { await viewModel.loadMore() }
                            } label: {
                                HStack {
                                    Spacer()
                                    if viewModel.isLoading {
                                        ProgressView().tint(ColorTokens.gold)
                                    } else {
                                        Text("Load More")
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(ColorTokens.gold)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, Spacing.sm)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // Result count footer
                        if viewModel.totalCount > 0 {
                            Text("Showing \(viewModel.content.count) of \(viewModel.totalCount)")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Content Moderation")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadContent()
        }
        .refreshable {
            await viewModel.loadContent()
        }
        .onChange(of: viewModel.selectedTab) {
            Task { await viewModel.loadContent() }
        }
        .onChange(of: viewModel.searchText) {
            viewModel.debouncedSearch()
        }
        .sheet(isPresented: $viewModel.showRemoveSheet) {
            removeContentSheet
        }
        .alert("Dismiss Reports", isPresented: $viewModel.showDismissConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Dismiss") {
                Task { await viewModel.dismissReports() }
            }
        } message: {
            if let item = viewModel.contentToDismiss {
                Text("Dismiss all reports for \"\(item.title)\"? The content will remain published.")
            }
        }
    }

    // MARK: - Tab Chip

    private func moderationTab(_ title: String, tab: Int, icon: String) -> some View {
        Button {
            Haptics.selection()
            viewModel.selectedTab = tab
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(Typography.bodySmall)
            }
            .foregroundStyle(viewModel.selectedTab == tab ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(viewModel.selectedTab == tab ? ColorTokens.gold : ColorTokens.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Row

    private func moderationRow(_ item: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // Thumbnail
                if let thumb = item.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ColorTokens.surfaceElevated
                        }
                    }
                    .frame(width: 72, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(2)
                    if let creator = item.creatorId {
                        Text(creator.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // Report count badge
                    if let reports = item.reportCount, reports > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                            Text("\(reports)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ColorTokens.error)
                        .clipShape(Capsule())
                    }

                    // Status badge
                    if let status = item.status {
                        Text(status.rawValue.capitalized)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(statusColor(status))
                    }
                }
            }

            // Action buttons
            HStack(spacing: Spacing.sm) {
                Button {
                    viewModel.contentToRemove = item
                    viewModel.removalReason = ""
                    viewModel.showRemoveSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Remove")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ColorTokens.error)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(ColorTokens.error.opacity(0.12))
                    .clipShape(Capsule())
                }

                if let reports = item.reportCount, reports > 0 {
                    Button {
                        viewModel.contentToDismiss = item
                        viewModel.showDismissConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Dismiss Reports")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Remove Content Sheet

    private var removeContentSheet: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let item = viewModel.contentToRemove {
                        // Content preview
                        HStack(spacing: Spacing.sm) {
                            if let thumb = item.thumbnailURL, let url = URL(string: thumb) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        ColorTokens.surfaceElevated
                                    }
                                }
                                .frame(width: 80, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineLimit(2)
                                if let creator = item.creatorId {
                                    Text("by \(creator.displayName)")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                                if let reports = item.reportCount, reports > 0 {
                                    Text("\(reports) report\(reports == 1 ? "" : "s")")
                                        .font(Typography.caption)
                                        .foregroundStyle(ColorTokens.error)
                                }
                            }
                        }
                        .padding(Spacing.md)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Removal Reason")
                            .font(Typography.bodyBold)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("This will be shown to the content creator.")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)

                        TextEditor(text: $viewModel.removalReason)
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(Spacing.sm)
                            .background(ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    }

                    Button {
                        Task { await viewModel.removeContent() }
                    } label: {
                        HStack {
                            if viewModel.isRemoving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Remove Content")
                            }
                        }
                        .font(Typography.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(viewModel.removalReason.isEmpty ? ColorTokens.error.opacity(0.3) : ColorTokens.error)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    .disabled(viewModel.removalReason.isEmpty || viewModel.isRemoving)

                    Spacer()
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Remove Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showRemoveSheet = false }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func statusColor(_ status: ContentStatus) -> Color {
        switch status {
        case .published: return ColorTokens.success
        case .draft, .processing: return ColorTokens.textTertiary
        case .ready: return ColorTokens.info
        case .rejected, .flagged, .removed: return ColorTokens.error
        case .unpublished, .archived: return ColorTokens.warning
        }
    }
}
