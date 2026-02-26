import Foundation
import Nuke

// MARK: - Cache Manager

/// Tracks and manages image (Nuke) and data (URLSession) caches.
///
/// Surfaces current cache sizes as observable properties so views
/// can display storage usage and offer "Clear Cache" actions.
@Observable
@MainActor
final class CacheManager {

    // MARK: - Observable State

    /// Size of the Nuke image disk cache in bytes.
    var imageCacheSize: Int64 = 0

    /// Size of the shared URLSession disk cache in bytes.
    var dataCacheSize: Int64 = 0

    /// Combined cache size in bytes.
    var totalCacheSize: Int64 {
        imageCacheSize + dataCacheSize
    }

    /// Human-readable combined cache size (e.g. "45.2 MB").
    var formattedTotalSize: String {
        Self.formatBytes(totalCacheSize)
    }

    /// Human-readable image cache size.
    var formattedImageCacheSize: String {
        Self.formatBytes(imageCacheSize)
    }

    /// Human-readable data cache size.
    var formattedDataCacheSize: String {
        Self.formatBytes(dataCacheSize)
    }

    // MARK: - Private

    private let logger = Logger(subsystem: "com.scaleup.app", category: "Cache")

    // MARK: - Calculate

    /// Recalculate both image and data cache sizes from disk.
    func calculateCacheSize() async {
        await calculateImageCacheSize()
        calculateDataCacheSize()
        logger.debug("Cache sizes — images: \(self.formattedImageCacheSize), data: \(self.formattedDataCacheSize)")
    }

    // MARK: - Clear

    /// Remove all cached images from the Nuke pipeline.
    func clearImageCache() {
        ImagePipeline.shared.cache.removeAll()
        imageCacheSize = 0
        logger.info("Image cache cleared")
    }

    /// Remove all cached responses from the shared URLSession cache.
    func clearDataCache() {
        URLCache.shared.removeAllCachedResponses()
        dataCacheSize = 0
        logger.info("Data cache cleared")
    }

    /// Clear both image and data caches.
    func clearAllCaches() {
        clearImageCache()
        clearDataCache()
        logger.info("All caches cleared")
    }

    // MARK: - Formatting

    /// Format a byte count into a human-readable string (e.g. "45.2 MB").
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Private Helpers

    /// Compute Nuke disk cache size.
    private func calculateImageCacheSize() async {
        let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache
        // DataCache exposes totalSize synchronously after a flush
        if let cache = dataCache {
            cache.flush()
            imageCacheSize = Int64(cache.totalSize)
        } else {
            // Fallback: count only the in-memory portion
            imageCacheSize = 0
        }
    }

    /// Compute URLSession disk cache size.
    private func calculateDataCacheSize() {
        dataCacheSize = Int64(URLCache.shared.currentDiskUsage)
    }
}

// MARK: - OSLog Import

import os
