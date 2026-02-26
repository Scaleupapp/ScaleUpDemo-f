import SwiftUI

// MARK: - Feature Flags Environment Key

/// Provides `FeatureFlags` through the SwiftUI environment.
private struct FeatureFlagsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = FeatureFlags()
}

extension EnvironmentValues {
    /// Access runtime feature flags via `@Environment(\.featureFlags)`.
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }
}

// MARK: - Performance Monitor Environment Key

/// Provides `PerformanceMonitor` through the SwiftUI environment.
private struct PerformanceMonitorKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = PerformanceMonitor()
}

extension EnvironmentValues {
    /// Access the performance monitor via `@Environment(\.performanceMonitor)`.
    var performanceMonitor: PerformanceMonitor {
        get { self[PerformanceMonitorKey.self] }
        set { self[PerformanceMonitorKey.self] = newValue }
    }
}

// MARK: - Cache Manager Environment Key

/// Provides `CacheManager` through the SwiftUI environment.
private struct CacheManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = CacheManager()
}

extension EnvironmentValues {
    /// Access the cache manager via `@Environment(\.cacheManager)`.
    var cacheManager: CacheManager {
        get { self[CacheManagerKey.self] }
        set { self[CacheManagerKey.self] = newValue }
    }
}
