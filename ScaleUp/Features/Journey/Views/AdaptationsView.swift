import SwiftUI

// MARK: - Journey Adaptation Model

/// Local model representing an AI-driven adaptation to the learning journey.
/// Kept file-scoped since there is no dedicated Adaptation model in the shared Models layer.
struct JourneyAdaptation: Identifiable, Hashable {
    let id: String
    let description: String
    let reason: String
    let date: String

    /// Formatted display date parsed from an ISO 8601 string.
    var displayDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        if let parsed = isoFormatter.date(from: date) {
            return displayFormatter.string(from: parsed)
        }
        // Fallback without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let parsed = isoFormatter.date(from: date) {
            return displayFormatter.string(from: parsed)
        }
        return date
    }
}

// MARK: - Adaptations View Model

@Observable
final class AdaptationsViewModel {

    // MARK: - State

    var adaptations: [JourneyAdaptation] = []
    var isLoading: Bool = false
    var error: APIError?

    // MARK: - Dependencies

    private let journeyService: JourneyService

    // MARK: - Init

    init(journeyService: JourneyService) {
        self.journeyService = journeyService
    }

    // MARK: - Load Adaptations

    /// Attempts to fetch journey data and derive adaptations.
    /// Since there is no dedicated adaptations endpoint yet, this pulls
    /// the journey and constructs adaptation entries from available data.
    @MainActor
    func loadAdaptations() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            guard let journey = try await journeyService.getJourney() else {
                adaptations = []
                isLoading = false
                return
            }
            adaptations = deriveAdaptations(from: journey)
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Derive Adaptations

    /// Builds adaptation entries from the journey phases and progress.
    /// When a real adaptations API exists, replace this with a direct fetch.
    private func deriveAdaptations(from journey: Journey) -> [JourneyAdaptation] {
        var items: [JourneyAdaptation] = []

        // Generate adaptation entries from phase transitions
        for (index, phase) in journey.phases.enumerated() {
            if index > 0 {
                let previous = journey.phases[index - 1]
                items.append(
                    JourneyAdaptation(
                        id: "phase-\(phase.name)",
                        description: "Transitioned from \(previous.name.capitalized) to \(phase.name.capitalized) phase",
                        reason: "Completed \(previous.topics.count) topics in the \(previous.name) phase. Ready for \(phase.description.lowercased()).",
                        date: journey.createdAt
                    )
                )
            }
        }

        // Add a pace adaptation if the user is ahead or behind schedule
        let expectedWeek = max(journey.phases.first?.weekNumbers.count ?? 1, 1)
        if journey.currentWeek > expectedWeek {
            items.append(
                JourneyAdaptation(
                    id: "pace-ahead",
                    description: "Learning pace adjusted ahead of schedule",
                    reason: "You are progressing faster than expected. The journey may be completed earlier than planned.",
                    date: journey.createdAt
                )
            )
        }

        return items
    }
}

// MARK: - Adaptations View

/// Shows AI-driven adaptations and adjustments made to the learning journey.
struct AdaptationsView: View {

    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: AdaptationsViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.backgroundDark
                    .ignoresSafeArea()

                if let viewModel {
                    if viewModel.isLoading && viewModel.adaptations.isEmpty {
                        adaptationsSkeletonView
                    } else if let error = viewModel.error, viewModel.adaptations.isEmpty {
                        ErrorStateView(
                            message: error.localizedDescription,
                            retryAction: {
                                Task { await viewModel.loadAdaptations() }
                            }
                        )
                    } else if viewModel.adaptations.isEmpty {
                        onTrackEmptyState
                    } else {
                        adaptationsContent(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Adaptations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AdaptationsViewModel(
                    journeyService: dependencies.journeyService
                )
            }
        }
        .task {
            if let viewModel, viewModel.adaptations.isEmpty {
                await viewModel.loadAdaptations()
            }
        }
    }

    // MARK: - Adaptations Content

    @ViewBuilder
    private func adaptationsContent(viewModel: AdaptationsViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {

                // Header explanation
                adaptationsHeader

                // Adaptation cards
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.adaptations) { adaptation in
                        adaptationCard(adaptation)
                    }
                }
                .padding(.horizontal, Spacing.md)

                // Bottom spacing for tab bar
                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel.loadAdaptations()
        }
    }

    // MARK: - Header

    private var adaptationsHeader: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.primary)

            Text("AI-Powered Adjustments")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            Text("Your journey adapts based on your progress and performance to keep you on the best path.")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Adaptation Card

    @ViewBuilder
    private func adaptationCard(_ adaptation: JourneyAdaptation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Date and icon row
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.primary)
                    .frame(width: 28, height: 28)
                    .background(ColorTokens.primary.opacity(0.12))
                    .clipShape(Circle())

                Text(adaptation.displayDate)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiaryDark)

                Spacer()
            }

            // Description
            Text(adaptation.description)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimaryDark)

            // Reason
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.warning)
                    .padding(.top, 2)

                Text(adaptation.reason)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
            }
            .padding(Spacing.sm)
            .background(ColorTokens.surfaceElevatedDark)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .padding(Spacing.md)
        .background(ColorTokens.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - On Track Empty State

    private var onTrackEmptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.success)

            VStack(spacing: Spacing.sm) {
                Text("Your journey is on track!")
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimaryDark)
                    .multilineTextAlignment(.center)

                Text("No adaptations needed right now. Keep up the great work and your path will adjust automatically as you progress.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
    }

    // MARK: - Skeleton Loading View

    private var adaptationsSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Header skeleton
                VStack(spacing: Spacing.sm) {
                    SkeletonLoader(width: 36, height: 36, cornerRadius: CornerRadius.small)
                    SkeletonLoader(width: 200, height: 20)
                    SkeletonLoader(width: 280, height: 14)
                }
                .padding(.horizontal, Spacing.lg)

                // Adaptation card skeletons
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            SkeletonLoader(width: 28, height: 28, cornerRadius: 14)
                            SkeletonLoader(width: 100, height: 12)
                            Spacer()
                        }
                        SkeletonLoader(height: 16)
                        SkeletonLoader(height: 40, cornerRadius: CornerRadius.small)
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
