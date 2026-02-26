import SwiftUI

// MARK: - Milestones View Model

@Observable
final class MilestonesViewModel {

    // MARK: - State

    var milestones: [Milestone] = []
    var isLoading: Bool = false
    var error: APIError?
    var selectedFilter: MilestoneFilter = .all

    // MARK: - Filter Enum

    enum MilestoneFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case inProgress = "In Progress"
        case locked = "Locked"
    }

    // MARK: - Dependencies

    private let journeyService: JourneyService

    // MARK: - Init

    init(journeyService: JourneyService) {
        self.journeyService = journeyService
    }

    // MARK: - Computed Properties

    var filteredMilestones: [Milestone] {
        switch selectedFilter {
        case .all:
            return milestones
        case .completed:
            return milestones.filter { $0.status == "completed" }
        case .inProgress:
            return milestones.filter { $0.status == "in_progress" }
        case .locked:
            return milestones.filter { $0.status == "locked" }
        }
    }

    var completedCount: Int {
        milestones.filter { $0.status == "completed" }.count
    }

    var totalCount: Int {
        milestones.count
    }

    var completionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    // MARK: - Load Milestones

    @MainActor
    func loadMilestones() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            milestones = try await journeyService.milestones()
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Helpers

    /// Returns a system icon name based on the milestone type.
    func iconName(for milestone: Milestone) -> String {
        switch (milestone.type ?? "").lowercased() {
        case "content":
            return "book.fill"
        case "quiz":
            return "star.fill"
        case "streak":
            return "flame.fill"
        case "phase":
            return "target"
        case "completion":
            return "trophy.fill"
        default:
            return "trophy.fill"
        }
    }

    /// Returns the accent color based on the milestone status.
    func statusColor(for milestone: Milestone) -> Color {
        switch (milestone.status ?? "").lowercased() {
        case "completed":
            return ColorTokens.success
        case "in_progress":
            return ColorTokens.warning
        default:
            return ColorTokens.textTertiaryDark
        }
    }

    /// Formats a completedAt date string for display.
    func formattedDate(_ dateString: String?) -> String? {
        guard let dateString else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        if let date = isoFormatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        }
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
