import SwiftUI

struct ExploreView: View {
    @Bindable var viewModel: ExploreViewModel
    @State private var showFilterSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                filterBar
                contentArea
            }
        }
        .task {
            if viewModel.content.isEmpty {
                await viewModel.loadContent()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterBottomSheet(viewModel: viewModel) {
                showFilterSheet = false
                Task { await viewModel.applyFilters() }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: Spacing.sm) {
            // Domain filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs + 2) {
                    ForEach(viewModel.availableDomains, id: \.self) { domain in
                        TagChip(
                            title: domain,
                            isSelected: viewModel.selectedDomain == domain
                        ) {
                            viewModel.selectDomain(domain)
                            Task { await viewModel.applyFilters() }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            // Difficulty pills + sort + filter
            HStack(spacing: Spacing.sm) {
                // Difficulty filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs + 2) {
                        difficultyPill(label: "All", difficulty: nil, icon: nil)
                        difficultyPill(label: "Beginner", difficulty: .beginner, icon: "leaf.fill")
                        difficultyPill(label: "Intermediate", difficulty: .intermediate, icon: "bolt.fill")
                        difficultyPill(label: "Advanced", difficulty: .advanced, icon: "flame.fill")
                    }
                }

                Spacer()

                // Sort picker
                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            viewModel.sortBy = option
                            Task { await viewModel.applyFilters() }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if viewModel.sortBy == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .medium))
                        Text(viewModel.sortBy.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.xs + 3)
                    .background(ColorTokens.surfaceElevatedDark)
                    .clipShape(Capsule())
                }

                // Filter button
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondaryDark)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.surfaceElevatedDark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.content.isEmpty {
            gridSkeletonView
        } else if viewModel.content.isEmpty && !viewModel.isLoading {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Content Found",
                subtitle: "Try adjusting your filters or explore a different domain.",
                buttonTitle: "Reset Filters"
            ) {
                viewModel.resetFilters()
                Task { await viewModel.applyFilters() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error, viewModel.content.isEmpty {
            ErrorStateView(
                message: error.errorDescription ?? "Failed to load content."
            ) {
                Task { await viewModel.loadContent() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            contentGrid
        }
    }

    // MARK: - Content Grid

    private var contentGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.content) { item in
                    NavigationLink(value: item) {
                        exploreCard(item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == viewModel.content.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

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

            Spacer()
                .frame(height: Spacing.xxl)
        }
    }

    // MARK: - Explore Card

    private func exploreCard(_ item: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with overlay elements
            ZStack {
                thumbnailView(item)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .clipped()

                // Bottom gradient
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 35)
                }

                // Duration badge — top right
                if let duration = item.duration {
                    VStack {
                        HStack {
                            Spacer()
                            Text(formatDuration(duration))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                    }
                    .padding(Spacing.xs + 2)
                }

                // Difficulty badge — bottom left
                VStack {
                    Spacer()
                    HStack {
                        Text(item.difficulty.rawValue.capitalized)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(difficultyColor(item.difficulty).opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                }
                .padding(Spacing.xs + 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small + 4))

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(item.creator.firstName) \(item.creator.lastName)")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if item.averageRating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(ColorTokens.anchorGold)
                            Text(String(format: "%.1f", item.averageRating))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ColorTokens.textSecondaryDark)
                        }
                    }

                    if item.viewCount > 0 {
                        if item.averageRating > 0 {
                            Circle()
                                .fill(ColorTokens.textTertiaryDark)
                                .frame(width: 2.5, height: 2.5)
                        }
                        Text(formatViewCount(item.viewCount))
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }
            .padding(.horizontal, Spacing.xs + 2)
            .padding(.vertical, Spacing.sm)
        }
        .background(ColorTokens.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.surfaceElevatedDark, lineWidth: 1)
        )
    }

    // MARK: - Difficulty Pill

    private func difficultyPill(label: String, difficulty: Difficulty?, icon: String?) -> some View {
        Button {
            viewModel.selectDifficulty(difficulty)
            Task { await viewModel.applyFilters() }
        } label: {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                viewModel.selectedDifficulty == difficulty
                    ? .white
                    : ColorTokens.textSecondaryDark
            )
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs + 3)
            .background(
                viewModel.selectedDifficulty == difficulty
                    ? ColorTokens.primary
                    : ColorTokens.surfaceElevatedDark
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid Skeleton

    private var gridSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                        SkeletonLoader(height: 90, cornerRadius: CornerRadius.small + 4)
                        SkeletonLoader(height: 14)
                        SkeletonLoader(width: 80, height: 10)
                    }
                    .padding(Spacing.sm)
                    .background(ColorTokens.surfaceDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func thumbnailView(_ item: Content) -> some View {
        if let thumbnailURL = item.resolvedThumbnailURL, let url = URL(string: thumbnailURL) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(ColorTokens.surfaceElevatedDark)
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
            }
        } else {
            Rectangle()
                .fill(ColorTokens.surfaceElevatedDark)
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK views", Double(count) / 1_000)
        }
        return "\(count) views"
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return ColorTokens.success
        case .intermediate: return ColorTokens.warning
        case .advanced: return ColorTokens.error
        }
    }
}
