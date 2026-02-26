import Foundation

// MARK: - Feature Flags

/// Runtime feature toggles that control which capabilities are
/// available in the app.
///
/// All flags default to sensible values and can be mutated at
/// runtime for A/B testing or remote configuration (e.g. Firebase
/// Remote Config). Inject via the SwiftUI environment using
/// `FeatureFlagsKey`.
@Observable
final class FeatureFlags {

    // MARK: - Core Features

    /// Whether the AI-generated learning journey feature is enabled.
    var isJourneyEnabled = true

    /// Whether quiz functionality is available.
    var isQuizEnabled = true

    /// Whether users can apply to become creators.
    var isCreatorApplicationEnabled = true

    /// Whether progress can be synced and tracked while offline.
    var isOfflineProgressEnabled = true

    /// Whether social features (follow, playlists, comments) are available.
    var isSocialFeaturesEnabled = true

    /// Whether admin users can access the admin panel.
    var isAdminPanelEnabled = true

    // MARK: - Experimental

    /// Experimental: use the new video player implementation.
    var isNewPlayerEnabled = false

    /// Experimental: show AI-powered content recommendations.
    var isAIRecommendationsEnabled = true

    // MARK: - Debug

    /// Whether debug-only features and diagnostics are available.
    var isDebugModeEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Show detailed network request/response logs in the console.
    var showNetworkLogs = false

    /// Show an in-app performance overlay with memory and frame stats.
    var showPerformanceOverlay = false
}
