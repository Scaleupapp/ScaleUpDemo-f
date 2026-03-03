import SwiftUI

struct ExploreGridView: View {
    @Bindable var viewModel: DiscoverViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Difficulty filter
                filterChips

                // Grid
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(viewModel.exploreResults) { content in
                        NavigationLink(value: content) {
                            ContentCard(content: content, width: .infinity)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Load more when reaching end
                            if content.id == viewModel.exploreResults.last?.id {
                                Task { await viewModel.loadMoreExplore() }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(ColorTokens.gold)
                        .padding()
                }

                if viewModel.exploreResults.isEmpty && !viewModel.isLoading {
                    emptyState
                }

                Spacer().frame(height: Spacing.xxl)
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterChip(title: "All", isSelected: viewModel.selectedDifficulty == nil) {
                    viewModel.selectedDifficulty = nil
                    Task { await viewModel.filterByDomain(viewModel.selectedDomain) }
                }

                ForEach(Difficulty.allCases) { difficulty in
                    filterChip(title: difficulty.displayName, isSelected: viewModel.selectedDifficulty == difficulty) {
                        viewModel.selectedDifficulty = difficulty
                        Task { await viewModel.filterByDomain(viewModel.selectedDomain) }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(isSelected ? ColorTokens.buttonPrimaryText : ColorTokens.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .background(isSelected ? ColorTokens.gold : ColorTokens.surfaceElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            Text("No content found")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textSecondary)

            Text("Try adjusting your filters")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl)
    }
}
