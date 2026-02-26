import SwiftUI

// MARK: - Search View

struct SearchView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SearchViewModel?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                VStack(spacing: 0) {
                    // Search bar
                    searchBar(viewModel: viewModel)

                    // Tab picker (only when we have results)
                    if !viewModel.isEmpty && viewModel.hasResults {
                        tabPicker(viewModel: viewModel)
                    }

                    // Content area
                    contentArea(viewModel: viewModel)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            if viewModel == nil {
                viewModel = SearchViewModel(
                    searchService: dependencies.searchService,
                    creatorService: dependencies.creatorService
                )
            }
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private func searchBar(viewModel: SearchViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isSearchFieldFocused
                            ? ColorTokens.primary
                            : ColorTokens.textTertiaryDark
                    )

                TextField("Search content, creators, topics...", text: Bindable(viewModel).query)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFieldFocused)
                    .onChange(of: viewModel.query) { _, _ in
                        Task { await viewModel.search() }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearSearch()
                        isSearchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.textTertiaryDark)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 44)
            .background(ColorTokens.surfaceDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(
                        isSearchFieldFocused
                            ? ColorTokens.primary
                            : ColorTokens.surfaceElevatedDark,
                        lineWidth: 1
                    )
            )

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.primary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Tab Picker

    @ViewBuilder
    private func tabPicker(viewModel: SearchViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases) { tab in
                Button {
                    withAnimation(Animations.quick) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Text(tab.rawValue)
                            .font(Typography.bodySmall)
                            .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(
                                viewModel.selectedTab == tab
                                    ? ColorTokens.primary
                                    : ColorTokens.textSecondaryDark
                            )

                        Rectangle()
                            .fill(
                                viewModel.selectedTab == tab
                                    ? ColorTokens.primary
                                    : Color.clear
                            )
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .background(ColorTokens.backgroundDark)
    }

    // MARK: - Content Area

    @ViewBuilder
    private func contentArea(viewModel: SearchViewModel) -> some View {
        if viewModel.isEmpty {
            // Idle state: recent searches + suggested topics
            idleContent(viewModel: viewModel)
        } else if viewModel.isSearching && !viewModel.hasResults {
            // Loading skeletons
            searchSkeletonView
        } else if viewModel.showEmptyResults {
            // No results
            emptyResultsView(viewModel: viewModel)
        } else {
            // Results
            SearchResultsView(viewModel: viewModel)
        }
    }

    // MARK: - Idle Content (Recent + Suggested)

    @ViewBuilder
    private func idleContent(viewModel: SearchViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {

                // Recent Searches
                if !viewModel.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Recent Searches")
                                .font(Typography.bodyBold)
                                .foregroundStyle(ColorTokens.textPrimaryDark)

                            Spacer()

                            Button {
                                withAnimation(Animations.standard) {
                                    viewModel.clearRecentSearches()
                                }
                            } label: {
                                Text("Clear All")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiaryDark)
                            }
                        }

                        ForEach(Array(viewModel.recentSearches.enumerated()), id: \.offset) { index, searchQuery in
                            recentSearchRow(
                                query: searchQuery,
                                index: index,
                                viewModel: viewModel
                            )
                        }
                    }
                }

                // Suggested Topics
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Suggested Topics")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)

                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(viewModel.suggestedTopics, id: \.self) { topic in
                            TagChip(title: topic) {
                                viewModel.selectSuggestedTopic(topic)
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Recent Search Row

    @ViewBuilder
    private func recentSearchRow(
        query: String,
        index: Int,
        viewModel: SearchViewModel
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textTertiaryDark)
                .frame(width: 20)

            Text(query)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(Animations.quick) {
                    viewModel.removeRecentSearch(at: index)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectSuggestedTopic(query)
        }
    }

    // MARK: - Empty Results

    @ViewBuilder
    private func emptyResultsView(viewModel: SearchViewModel) -> some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results found",
                subtitle: "Try different keywords or browse suggested topics",
                buttonTitle: "Clear Search"
            ) {
                viewModel.clearSearch()
                isSearchFieldFocused = true
            }
            Spacer()
        }
    }

    // MARK: - Skeleton Loading

    private var searchSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: Spacing.sm) {
                        SkeletonLoader(
                            width: 80,
                            height: 45,
                            cornerRadius: CornerRadius.small
                        )

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonLoader(height: 14)
                            SkeletonLoader(width: 140, height: 12)
                            SkeletonLoader(width: 100, height: 10)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.top, Spacing.md)
        }
    }
}
