import UIKit
import Nuke
import os

// MARK: - App Delegate

/// UIKit application delegate responsible for one-time SDK setup,
/// push notification registration, and global resource configuration.
///
/// Wire into the SwiftUI lifecycle with `@UIApplicationDelegateAdaptor`.
class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Private

    private let logger = Logger(subsystem: "com.scaleup.app", category: "AppDelegate")

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.info("Application did finish launching — configuring infrastructure")

        setupImagePipeline()
        setupURLCache()

        return true
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Log.notifications.info("APNs device token: \(token)")

        // Future: send token to backend for push notification delivery
        // Task { try? await apiClient.request(NotificationEndpoints.registerToken(token)) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.notifications.error("Failed to register for APNs: \(error.localizedDescription)")
    }

    // MARK: - Orientation Support

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationHelper.orientationLock
    }

    // MARK: - Image Pipeline

    /// Configure the shared Nuke image pipeline with memory and disk
    /// cache limits derived from `AppConfig`.
    private func setupImagePipeline() {
        var config = ImagePipeline.Configuration.withDataCache(
            name: "com.scaleup.images",
            sizeLimit: AppConfig.imageCacheLimit
        )

        // Progressive decoding for a smoother loading experience
        config.isProgressiveDecodingEnabled = true

        // Deduplicate identical in-flight requests
        config.isTaskCoalescingEnabled = true

        ImagePipeline.shared = ImagePipeline(configuration: config)

        logger.info("Nuke image pipeline configured — cache limit: \(AppConfig.imageCacheLimit / 1024 / 1024)MB")
    }

    // MARK: - URL Cache

    /// Configure the shared URLCache used by URLSession for HTTP
    /// response caching.
    private func setupURLCache() {
        let cache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,   // 10 MB in-memory
            diskCapacity: AppConfig.urlCacheLimit, // AppConfig value (50 MB)
            directory: nil
        )
        URLCache.shared = cache

        logger.info("URLCache configured — disk limit: \(AppConfig.urlCacheLimit / 1024 / 1024)MB")
    }
}
