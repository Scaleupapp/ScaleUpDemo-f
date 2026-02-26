import SwiftUI

// MARK: - Learning History View

/// Full-screen list of the user's content consumption history.
/// Pushed from the "See All" action on the Continue Watching section.
///
/// Features:
/// - Segmented filter (All / In Progress / Completed)
/// - Each row shows thumbnail, title stub, progress bar, and time ago
/// - Completed items display a checkmark badge
/// - Pull to refresh
/// - Infinite scroll pagination
struct LearningHistoryView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: LearningHistoryViewModel?

    var body: some View {
        ZStack {
            ColorTokens.backgroundDark
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading && viewModel.history.isEmpty {
                    historySkeletonView
                } else if let error = viewModel.error, viewModel.history.isEmpty {
                    ErrorStateView(
                        message: error.localizedDescription,
                        retryAction: {
                            Task { await viewModel.loadHistory() }
                        }
                    )
                } else if viewModel.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No History Yet",
                        subtitle: "Content you watch or read will appear here so you can pick up where you left off."
                    )
                } else {
                    historyContent(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Learning History")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = LearningHistoryViewModel(
                    progressService: dependencies.progressService
                )
            }
        }
        .task {
            if let viewModel, viewModel.history.isEmpty {
                await viewModel.loadHistory()
            }
        }
    }

    // MARK: - History Content

    @ViewBuilder
    private func historyContent(viewModel: LearningHistoryViewModel) -> some View {
        VStack(spacing: 0) {
            // Filter Picker
            filterPicker(viewModel: viewModel)

            // List
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.filteredHistory) { item in
                        HistoryItemRow(progress: item)
                            .onAppear {
                                // Trigger pagination when the last item appears
                                if item.id == viewModel.filteredHistory.last?.id {
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
                            Spacer()
                        }
                        .padding(.vertical, Spacing.md)
                    }

                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.top, Spacing.sm)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Filter Picker

    @ViewBuilder
    private func filterPicker(viewModel: LearningHistoryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(HistoryFilter.allCases) { option in
                    FilterChip(
                        title: option.rawValue,
                        isSelected: viewModel.filter == option,
                        action: {
                            withAnimation(Animations.quick) {
                                viewModel.filter = option
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - Skeleton Loading

    private var historySkeletonView: some View {
        VStack(spacing: Spacing.sm) {
            // Filter skeleton
            HStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonLoader(width: 80, height: 32, cornerRadius: CornerRadius.full)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // Row skeletons
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: Spacing.sm) {
                    SkeletonLoader(width: 80, height: 45, cornerRadius: CornerRadius.small)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonLoader(width: 180, height: 14)
                        SkeletonLoader(width: 120, height: 10)
                        SkeletonLoader(height: 4, cornerRadius: 2)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
            }

            Spacer()
        }
    }
}

// MARK: - Filter Chip

/// A small pill-shaped toggle used in the filter bar.
private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : ColorTokens.textSecondaryDark)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected
                        ? ColorTokens.primary
                        : ColorTokens.surfaceElevatedDark
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Item Row

/// A single row in the learning history list.
/// Shows a thumbnail placeholder, content metadata, and either a progress
/// bar with percentage or a completed checkmark badge.
private struct HistoryItemRow: View {
    let progress: ContentProgress

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Thumbnail placeholder
            thumbnailView

            // Metadata
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title stub (contentId used as placeholder)
                Text("Content \(progress.contentId.contentIdString.prefix(8))...")
                    .font(Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .lineLimit(2)

                // Creator name placeholder
                Text("Creator")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                // Progress or completed indicator
                if progress.isCompleted {
                    completedBadge
                } else {
                    progressBar
                }
            }

            Spacer()

            // Time ago
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                if let completedAt = progress.completedAt {
                    Text(timeAgoString(from: completedAt))
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                } else {
                    Text(formatDuration(Int(progress.totalDuration - progress.currentPosition)))
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiaryDark)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceDark)
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(ColorTokens.surfaceElevatedDark)

            if progress.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.success)
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.textTertiaryDark)
            }

            // Mini progress overlay at bottom
            if !progress.isCompleted {
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        Rectangle()
                            .fill(ColorTokens.primary)
                            .frame(
                                width: geo.size.width * progress.percentageCompleted / 100,
                                height: 2
                            )
                    }
                    .frame(height: 2)
                }
            }
        }
        .frame(width: 80, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: Spacing.sm) {
            // Bar track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorTokens.surfaceElevatedDark)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorTokens.progressGradient)
                        .frame(width: geo.size.width * progress.percentageCompleted / 100)
                }
            }
            .frame(height: 4)

            // Percentage text
            Text("\(Int(progress.percentageCompleted))%")
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Completed Badge

    private var completedBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.success)

            Text("Completed")
                .font(Typography.micro)
                .foregroundStyle(ColorTokens.success)
        }
    }

    // MARK: - Helpers

    /// Converts an ISO-8601 date string into a relative "time ago" label.
    private func timeAgoString(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        if let date = formatter.date(from: isoString) {
            return date.timeAgo()
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return date.timeAgo()
        }

        return ""
    }

    /// Formats a duration in seconds into a human-readable string (e.g. "5 min left").
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m left"
            }
            return "\(hours)h left"
        } else if minutes > 0 {
            return "\(minutes) min left"
        }
        return "\(seconds)s left"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LearningHistoryView()
            .environment(DependencyContainer())
            .preferredColorScheme(.dark)
    }
}
