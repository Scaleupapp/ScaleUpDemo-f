import Foundation

// MARK: - App Configuration

/// Centralized, compile-time application configuration.
///
/// Groups API settings, timeouts, pagination limits, cache budgets,
/// feature toggles, and app metadata in one discoverable location.
/// Values that differ between `DEBUG` and `RELEASE` are resolved via
/// conditional compilation.
enum AppConfig {

    // MARK: - API

    /// Base URL for all API requests. Points to localhost in DEBUG,
    /// production endpoint in RELEASE.
    static let apiBaseURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:5001/api/v1")!
        #else
        return URL(string: "https://api.scaleup.app/api/v1")!
        #endif
    }()

    // MARK: - Timeouts

    /// Maximum time (seconds) to wait for a single request.
    static let requestTimeout: TimeInterval = 30

    /// Maximum time (seconds) to wait for a resource download.
    static let resourceTimeout: TimeInterval = 60

    // MARK: - Pagination

    /// Default number of items per page for most list endpoints.
    static let defaultPageSize = 20

    /// Page size used specifically for the home feed.
    static let feedPageSize = 10

    // MARK: - Cache Limits

    /// Maximum disk space (bytes) for the Nuke image cache. Default 200 MB.
    static let imageCacheLimit: Int = 200 * 1024 * 1024

    /// Maximum disk space (bytes) for the shared URLSession cache. Default 50 MB.
    static let urlCacheLimit: Int = 50 * 1024 * 1024

    // MARK: - Progress Tracking

    /// Interval (seconds) between automatic progress sync calls.
    static let progressSyncInterval: TimeInterval = 10

    /// Debounce interval (seconds) for search text input.
    static let searchDebounceInterval: TimeInterval = 0.5

    // MARK: - Quiz

    /// Default per-question time limit (seconds) when none is specified.
    static let defaultQuizTimeLimit: TimeInterval = 30

    // MARK: - Feature Flags (Compile-Time)

    /// Whether offline content support is available.
    static let isOfflineEnabled = true

    /// Whether analytics events are dispatched. Disabled in DEBUG.
    static let isAnalyticsEnabled: Bool = {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }()

    // MARK: - App Info

    /// Short version string from Info.plist (e.g. "1.2").
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number from Info.plist (e.g. "42").
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Combined version and build display string (e.g. "1.2 (42)").
    static var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }

    // MARK: - URL Scheme

    /// Custom URL scheme used for deep links (e.g. scaleup://content/abc).
    static let urlScheme = "scaleup"
}
