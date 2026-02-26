import SwiftUI

// MARK: - Creator Dashboard View Model

@Observable
@MainActor
final class CreatorDashboardViewModel {

    // MARK: - State

    var profile: CreatorProfile?
    var isLoading = false
    var error: APIError?
    var showEditProfile = false

    // MARK: - Dependencies

    private let creatorService: CreatorService
    private let hapticManager: HapticManager

    // MARK: - Init

    init(creatorService: CreatorService, hapticManager: HapticManager) {
        self.creatorService = creatorService
        self.hapticManager = hapticManager
    }

    // MARK: - Load Profile

    /// Fetches the current user's creator profile from the API.
    func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let fetchedProfile = try await creatorService.profile()
            self.profile = fetchedProfile
        } catch let apiError as APIError {
            self.error = apiError
            hapticManager.error()
        } catch {
            self.error = .unknown(0, error.localizedDescription)
            hapticManager.error()
        }

        isLoading = false
    }

    // MARK: - Refresh

    /// Refreshes the creator profile without showing the loading indicator.
    func refresh() async {
        error = nil

        do {
            let fetchedProfile = try await creatorService.profile()
            self.profile = fetchedProfile
        } catch let apiError as APIError {
            self.error = apiError
        } catch {
            self.error = .unknown(0, error.localizedDescription)
        }
    }

    // MARK: - Apply Updated Profile

    /// Updates the local profile after an edit completes.
    func applyUpdatedProfile(_ updatedProfile: CreatorProfile) {
        self.profile = updatedProfile
    }

    // MARK: - Computed Properties

    /// Maps the creator tier to its corresponding color token.
    var tierColor: Color {
        guard let tier = profile?.tier else { return ColorTokens.textTertiaryDark }
        switch tier {
        case .anchor:
            return ColorTokens.anchorGold
        case .core:
            return ColorTokens.coreSilver
        case .rising:
            return ColorTokens.risingBronze
        }
    }

    /// Maps the creator tier to an appropriate SF Symbol.
    var tierIcon: String {
        guard let tier = profile?.tier else { return "star" }
        switch tier {
        case .anchor:
            return "crown.fill"
        case .core:
            return "shield.fill"
        case .rising:
            return "arrow.up.circle.fill"
        }
    }

    /// Human-readable tier display name.
    var tierDisplayName: String {
        guard let tier = profile?.tier else { return "" }
        switch tier {
        case .anchor:
            return "Anchor"
        case .core:
            return "Core"
        case .rising:
            return "Rising"
        }
    }

    /// Formatted total views with abbreviation for large numbers.
    var formattedViews: String {
        guard let views = profile?.stats.totalViews else { return "0" }
        if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000)
        } else if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000)
        }
        return "\(views)"
    }

    /// Formatted total followers with abbreviation for large numbers.
    var formattedFollowers: String {
        guard let followers = profile?.stats.totalFollowers else { return "0" }
        if followers >= 1_000_000 {
            return String(format: "%.1fM", Double(followers) / 1_000_000)
        } else if followers >= 1_000 {
            return String(format: "%.1fK", Double(followers) / 1_000)
        }
        return "\(followers)"
    }
}
