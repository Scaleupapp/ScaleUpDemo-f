import SwiftUI

// MARK: - Milestones View

/// Achievement/trophy room showing all journey milestones with filtering,
/// progress summary, and individual milestone cards.
struct MilestonesView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: MilestonesViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.milestones.isEmpty {
                        milestonesSkeletonView
                    } else if let error = viewModel.error, viewModel.milestones.isEmpty {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadMilestones() }
                            }
                        )
                    } else if viewModel.milestones.isEmpty {
                        EmptyStateView(
                            icon: "trophy",
                            title: "No Milestones Yet",
                            subtitle: "Start your learning journey to unlock milestones and track your achievements."
                        )
                    } else {
                        milestonesContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MilestonesViewModel(
                    journeyService: dependencies.journeyService
                )
            }
        }
        .task {
            if let viewModel, viewModel.milestones.isEmpty {
                await viewModel.loadMilestones()
            }
        }
    }

    // MARK: - Milestones Content

    @ViewBuilder
    private func milestonesContent(viewModel: MilestonesViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Summary Header
                summaryCard(viewModel: viewModel)

                // Filter Chips
                filterBar(viewModel: viewModel)

                // Milestone Cards
                if viewModel.filteredMilestones.isEmpty {
                    noFilterResultsView(viewModel: viewModel)
                } else {
                    milestonesList(viewModel: viewModel)
                }

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.loadMilestones()
        }
    }

    // MARK: - Summary Card

    @ViewBuilder
    private func summaryCard(viewModel: MilestonesViewModel) -> some View {
        HStack(spacing: Spacing.lg) {
            ProgressRing(
                progress: viewModel.completionProgress,
                size: 80,
                lineWidth: 8
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(viewModel.completedCount) of \(viewModel.totalCount)")
                    .font(Typography.titleLarge)
                    .foregroundStyle(ColorTokens.textPrimaryDark)

                Text("milestones completed")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)

                // Completion encouragement
                if viewModel.completedCount == viewModel.totalCount && viewModel.totalCount > 0 {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.success)
                        Text("All complete!")
                            .font(Typography.bodySmall)
                            .foregroundStyle(ColorTokens.success)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surfaceDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.primary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private func filterBar(viewModel: MilestonesViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(MilestonesViewModel.MilestoneFilter.allCases, id: \.self) { filter in
                    filterChip(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedFilter == filter,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedFilter = filter
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : ColorTokens.textSecondaryDark
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected
                        ? ColorTokens.primary
                        : ColorTokens.surfaceElevatedDark
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Milestones List

    @ViewBuilder
    private func milestonesList(viewModel: MilestonesViewModel) -> some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(viewModel.filteredMilestones) { milestone in
                milestoneCard(milestone: milestone, viewModel: viewModel)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Milestone Card

    @ViewBuilder
    private func milestoneCard(milestone: Milestone, viewModel: MilestonesViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            // Top row: icon, title, status badge
            HStack(spacing: Spacing.sm) {
                // Milestone type icon
                Image(systemName: viewModel.iconName(for: milestone))
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.statusColor(for: milestone))
                    .frame(width: 40, height: 40)
                    .background(
                        viewModel.statusColor(for: milestone).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimaryDark)
                        .lineLimit(1)

                    if let description = milestone.description {
                        Text(description)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondaryDark)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Status badge
                statusBadge(for: milestone)
            }

            // Progress bar
            VStack(spacing: Spacing.xs) {
                GeometryReader { geo in
                    let progress = milestone.targetValue > 0
                        ? min(Double(milestone.currentValue) / Double(milestone.targetValue), 1.0)
                        : 0.0

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surfaceElevatedDark)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.statusColor(for: milestone))
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(milestone.currentValue) / \(milestone.targetValue)")
                        .font(Typography.mono)
                        .foregroundStyle(ColorTokens.textSecondaryDark)

                    Spacer()

                    if let completedAt = milestone.completedAt,
                       let formatted = viewModel.formattedDate(completedAt) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.success)
                            Text(formatted)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiaryDark)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .opacity(milestone.status == "locked" ? 0.6 : 1.0)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(for milestone: Milestone) -> some View {
        switch (milestone.status ?? "").lowercased() {
        case "completed":
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("Done")
                    .font(Typography.micro)
            }
            .foregroundStyle(ColorTokens.success)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.success.opacity(0.12))
            .clipShape(Capsule())

        case "in_progress":
            HStack(spacing: Spacing.xs) {
                Circle()
                    .stroke(ColorTokens.warning, lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                Text("Active")
                    .font(Typography.micro)
            }
            .foregroundStyle(ColorTokens.warning)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.warning.opacity(0.12))
            .clipShape(Capsule())

        default:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("Locked")
                    .font(Typography.micro)
            }
            .foregroundStyle(ColorTokens.textTertiaryDark)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorTokens.surfaceElevatedDark)
            .clipShape(Capsule())
        }
    }

    // MARK: - No Filter Results

    @ViewBuilder
    private func noFilterResultsView(viewModel: MilestonesViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.textTertiaryDark)

            Text("No \(viewModel.selectedFilter.rawValue.lowercased()) milestones")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Skeleton Loading View

    private var milestonesSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Summary skeleton
                HStack(spacing: Spacing.lg) {
                    SkeletonLoader(width: 80, height: 80, cornerRadius: 40)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SkeletonLoader(width: 120, height: 22)
                        SkeletonLoader(width: 160, height: 14)
                    }
                    Spacer()
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(ColorTokens.surfaceDark)
                )
                .padding(.horizontal, Spacing.md)

                // Filter bar skeleton
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonLoader(width: 80, height: 34, cornerRadius: CornerRadius.full)
                    }
                }
                .padding(.horizontal, Spacing.md)

                // Milestone cards skeleton
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            SkeletonLoader(width: 40, height: 40, cornerRadius: CornerRadius.small)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                SkeletonLoader(width: 160, height: 16)
                                SkeletonLoader(width: 200, height: 12)
                            }
                            Spacer()
                            SkeletonLoader(width: 64, height: 24, cornerRadius: CornerRadius.full)
                        }
                        SkeletonLoader(height: 6, cornerRadius: 4)
                        HStack {
                            SkeletonLoader(width: 60, height: 12)
                            Spacer()
                        }
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }
}
