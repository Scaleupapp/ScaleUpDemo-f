import SwiftUI

struct MyContentView: View {
    @State private var viewModel = MyContentViewModel()
    @State private var showCreateContent = false
    @State private var editingContent: Content?
    @State private var deletingContent: Content?

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.content.isEmpty {
                VStack(spacing: Spacing.md) {
                    ProgressView().tint(ColorTokens.gold)
                    Text("Loading your content...")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else if viewModel.content.isEmpty {
                emptyState
            } else {
                contentList
            }
        }
        .navigationTitle("My Content")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateContent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .sheet(isPresented: $showCreateContent) {
            CreateContentView { _ in
                Task { await viewModel.loadContent() }
            }
        }
        .sheet(item: $editingContent) { content in
            EditContentView(content: content) {
                Task { await viewModel.loadContent() }
            }
        }
        .alert("Delete Content", isPresented: Binding(
            get: { deletingContent != nil },
            set: { if !$0 { deletingContent = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingContent = nil }
            Button("Delete", role: .destructive) {
                if let item = deletingContent {
                    Task { await viewModel.delete(id: item.id) }
                    deletingContent = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(deletingContent?.title ?? "")\"? This action cannot be undone.")
        }
        .task {
            if viewModel.content.isEmpty {
                await viewModel.loadContent()
            }
        }
        .refreshable {
            await viewModel.loadContent()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.gold)
            }

            VStack(spacing: Spacing.sm) {
                Text("Your creative space")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Start creating content that inspires\nand educates your audience")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                showCreateContent = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Create Your First Content")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 16)
                .background(ColorTokens.gold)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .shadow(color: ColorTokens.gold.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Status filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        filterChip("All", filter: nil, count: viewModel.content.count)
                        filterChip("Published", filter: .published, count: viewModel.statusCounts[.published] ?? 0)
                        filterChip("Processing", filter: .processing, count: viewModel.statusCounts[.processing] ?? 0)
                        filterChip("Ready", filter: .ready, count: viewModel.statusCounts[.ready] ?? 0)
                        filterChip("Draft", filter: .draft, count: viewModel.statusCounts[.draft] ?? 0)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Content items
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.filteredContent) { item in
                        contentRow(item)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.top, Spacing.sm)
        }
    }

    private func filterChip(_ label: String, filter: ContentStatus?, count: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(Typography.bodySmall)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(viewModel.selectedFilter == filter ? .black : ColorTokens.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(viewModel.selectedFilter == filter ? Color.black.opacity(0.2) : ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(viewModel.selectedFilter == filter ? .black : ColorTokens.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(viewModel.selectedFilter == filter ? ColorTokens.gold : ColorTokens.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func contentRow(_ item: Content) -> some View {
        HStack(spacing: Spacing.sm) {
            // Thumbnail
            ZStack {
                if let thumb = item.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            ColorTokens.surfaceElevated
                        }
                    }
                } else {
                    ColorTokens.surfaceElevated
                        .overlay {
                            Image(systemName: contentTypeIcon(item.contentType as ContentType?))
                                .font(.system(size: 16))
                                .foregroundStyle(ColorTokens.gold.opacity(0.5))
                        }
                }
            }
            .frame(width: 72, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    statusBadge(item.status ?? .draft)

                    if !item.formattedDuration.isEmpty {
                        Text(item.formattedDuration)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            // Actions menu
            Menu {
                Button {
                    editingContent = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                if item.status == .ready {
                    Button {
                        Task { await viewModel.publish(id: item.id) }
                    } label: {
                        Label("Publish", systemImage: "arrow.up.circle")
                    }
                }
                if item.status == .published {
                    Button {
                        Task { await viewModel.unpublish(id: item.id) }
                    } label: {
                        Label("Unpublish", systemImage: "arrow.down.circle")
                    }
                }

                Divider()

                if item.status != .published {
                    Button(role: .destructive) {
                        deletingContent = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(Circle())
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func statusBadge(_ status: ContentStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: ContentStatus) -> Color {
        switch status {
        case .published: return ColorTokens.success
        case .processing: return ColorTokens.info
        case .ready: return ColorTokens.gold
        case .draft: return ColorTokens.textTertiary
        case .rejected: return ColorTokens.error
        default: return ColorTokens.textTertiary
        }
    }

    private func contentTypeIcon(_ type: ContentType?) -> String {
        switch type {
        case .video: return "film.fill"
        case .article: return "doc.text.fill"
        case .infographic: return "photo.fill"
        default: return "doc.fill"
        }
    }
}
