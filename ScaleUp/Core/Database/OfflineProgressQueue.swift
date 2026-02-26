import Foundation
import SwiftData
import Observation
import os

// MARK: - Offline Progress Queue

/// Manages a local queue of progress updates that could not be sent to the
/// server due to lack of network connectivity. When the connection is restored
/// the queue is automatically drained, replaying each update against the
/// `ProgressService`.
///
/// Usage:
/// 1. Inject the queue via `@Environment` or create one with a `ModelContext`.
/// 2. Call `enqueue(...)` whenever a progress update fails due to network issues.
/// 3. The queue observes `NetworkMonitor.isConnected` and processes pending
///    items automatically on reconnection. It also processes on explicit call.
@Observable
@MainActor
final class OfflineProgressQueue {

    // MARK: - Constants

    /// Maximum number of retry attempts before an update is discarded.
    private static let maxRetries = 3

    // MARK: - Published State

    /// The number of updates waiting to be synced.
    var pendingCount: Int = 0

    /// Whether the queue is currently being processed.
    var isProcessing: Bool = false

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let progressService: ProgressService

    // MARK: - Observation

    /// Tracks whether we have already started observing network changes.
    private var isObservingNetwork: Bool = false

    // MARK: - Init

    init(modelContext: ModelContext, progressService: ProgressService) {
        self.modelContext = modelContext
        self.progressService = progressService
        refreshPendingCount()
    }

    // MARK: - Enqueue

    /// Adds a progress update to the offline queue for later syncing.
    ///
    /// - Parameters:
    ///   - contentId: The identifier of the content being tracked.
    ///   - position: Current playback position in seconds.
    ///   - duration: Total duration of the content in seconds.
    ///   - isComplete: If `true`, the content will be marked as complete
    ///     rather than simply updating position.
    func enqueue(
        contentId: String,
        position: Int,
        duration: Int,
        isComplete: Bool = false
    ) {
        let update = OfflineProgressUpdate(
            contentId: contentId,
            currentPosition: position,
            totalDuration: duration,
            isCompleteAction: isComplete
        )
        modelContext.insert(update)
        saveContext()
        refreshPendingCount()

        Log.data.info("Enqueued offline progress update for content \(contentId, privacy: .public)")
    }

    // MARK: - Process Queue

    /// Iterates over all pending updates and attempts to sync each one.
    /// Successful items are deleted from the store. Failed items have their
    /// `retryCount` incremented; items exceeding `maxRetries` are discarded.
    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        defer {
            isProcessing = false
            refreshPendingCount()
        }

        let pendingUpdates = fetchPendingUpdates()

        guard !pendingUpdates.isEmpty else {
            Log.data.debug("Offline progress queue is empty — nothing to process.")
            return
        }

        Log.data.info("Processing \(pendingUpdates.count, privacy: .public) offline progress updates...")

        for update in pendingUpdates {
            do {
                if update.isCompleteAction {
                    _ = try await progressService.markComplete(contentId: update.contentId)
                } else {
                    _ = try await progressService.updateProgress(
                        contentId: update.contentId,
                        position: Double(update.currentPosition),
                        duration: Double(update.totalDuration)
                    )
                }

                // Success — remove from local store
                modelContext.delete(update)
                saveContext()

                Log.data.info("Synced offline update for content \(update.contentId, privacy: .public)")

            } catch {
                update.retryCount += 1

                if update.retryCount >= Self.maxRetries {
                    // Exceeded max retries — discard
                    modelContext.delete(update)
                    Log.data.warning(
                        "Discarded offline update for \(update.contentId, privacy: .public) after \(Self.maxRetries) retries."
                    )
                } else {
                    Log.data.warning(
                        "Retry \(update.retryCount)/\(Self.maxRetries) for content \(update.contentId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }

                saveContext()
            }
        }

        refreshPendingCount()
        Log.data.info("Offline progress queue processing complete. Remaining: \(self.pendingCount, privacy: .public)")
    }

    // MARK: - Clear Queue

    /// Deletes all pending updates from the local store.
    func clearQueue() {
        let pendingUpdates = fetchPendingUpdates()
        for update in pendingUpdates {
            modelContext.delete(update)
        }
        saveContext()
        refreshPendingCount()

        Log.data.info("Cleared offline progress queue.")
    }

    // MARK: - Network Observation

    /// Starts observing the shared `NetworkMonitor` for connectivity changes.
    /// When the device reconnects, the queue is automatically processed.
    /// Safe to call multiple times — observation is only set up once.
    func startObservingNetwork() {
        guard !isObservingNetwork else { return }
        isObservingNetwork = true

        // Use withObservationTracking in a Task to react to changes
        Task { [weak self] in
            await self?.observeNetworkChanges()
        }
    }

    // MARK: - Private Helpers

    private func observeNetworkChanges() async {
        var wasConnected = NetworkMonitor.shared.isConnected

        while !Task.isCancelled {
            // Sleep briefly to avoid tight polling
            try? await Task.sleep(for: .seconds(2))

            let isNowConnected = NetworkMonitor.shared.isConnected

            if isNowConnected && !wasConnected {
                Log.data.info("Network restored — processing offline progress queue.")
                await processQueue()
            }

            wasConnected = isNowConnected
        }
    }

    private func fetchPendingUpdates() -> [OfflineProgressUpdate] {
        let descriptor = FetchDescriptor<OfflineProgressUpdate>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Log.data.error("Failed to fetch offline progress updates: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func refreshPendingCount() {
        pendingCount = fetchPendingUpdates().count
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            Log.data.error("Failed to save model context: \(error.localizedDescription, privacy: .public)")
        }
    }
}
