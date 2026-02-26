import SwiftUI
import os

// MARK: - App Router

/// Centralized navigation state for the entire app. Controls tab selection,
/// navigation stack paths, and modal sheet presentation.
///
/// Inject via `@Environment(AppRouter.self)` and bind the `selectedTab`
/// and `presentedSheet` properties in `MainTabView`.
@Observable @MainActor
final class AppRouter {

    // MARK: - Tab State

    var selectedTab: MainTabView.Tab = .home

    // MARK: - Navigation Path

    /// The shared navigation path for programmatic push/pop within tabs.
    var navigationPath = NavigationPath()

    // MARK: - Sheet Presentation

    var presentedSheet: AppSheet?

    // MARK: - Private

    private let logger = Logger(subsystem: "com.scaleup", category: "Router")

    // MARK: - App Sheet

    enum AppSheet: Identifiable, Equatable {
        case addToPlaylist(contentId: String)
        case createPlaylist
        case notificationCenter

        var id: String {
            switch self {
            case .addToPlaylist(let contentId):
                return "addToPlaylist-\(contentId)"
            case .createPlaylist:
                return "createPlaylist"
            case .notificationCenter:
                return "notificationCenter"
            }
        }
    }

    // MARK: - Navigation

    /// Routes to the destination described by a `DeepLink`.
    func navigate(to deepLink: DeepLink) {
        logger.info("Navigating to deep link: \(String(describing: deepLink))")

        switch deepLink {
        // Tab navigation
        case .tab(let tab):
            switchTab(tab)

        // Content
        case .content:
            switchTab(.discover)

        case .player:
            switchTab(.discover)

        // Quiz
        case .quiz:
            switchTab(.home)

        case .quizList:
            switchTab(.home)

        // Journey
        case .journey:
            switchTab(.journey)

        case .todayPlan:
            switchTab(.journey)

        // Social
        case .profile:
            switchTab(.profile)

        case .playlist:
            switchTab(.discover)

        // Admin
        case .admin, .adminUsers, .adminApplications:
            switchTab(.profile)
        }
    }

    /// Switches to the specified tab with haptic feedback.
    func switchTab(_ tab: MainTabView.Tab) {
        logger.debug("Switching to tab: \(tab.rawValue)")
        selectedTab = tab
    }

    /// Dismisses the currently presented sheet.
    func dismissSheet() {
        logger.debug("Dismissing sheet")
        presentedSheet = nil
    }

    /// Pops the navigation stack back to root.
    func popToRoot() {
        logger.debug("Popping to root")
        navigationPath = NavigationPath()
    }

    /// Presents a sheet.
    func present(_ sheet: AppSheet) {
        logger.debug("Presenting sheet: \(sheet.id)")
        presentedSheet = sheet
    }
}
