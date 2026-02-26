import Foundation

// MARK: - Progress Tracker

/// Actor that manages periodic progress syncing with the backend.
/// Tracks playback time and syncs progress every 10 seconds of playback.
/// Queues pending updates for offline resilience.
actor ProgressTracker {

    // MARK: - State

    private var contentId: String?
    private var currentPosition: Double = 0
    private var totalDuration: Double = 0
    private var lastSyncPosition: Double = 0
    private var isTracking = false

    /// Threshold in seconds of playback before triggering a sync.
    private let syncInterval: Double = 10

    // MARK: - Dependencies

    private let progressService: ProgressService

    // MARK: - Pending Updates Queue

    private var pendingUpdate: PendingProgressUpdate?

    // MARK: - Init

    init(progressService: ProgressService) {
        self.progressService = progressService
    }

    // MARK: - Start Tracking

    /// Begins tracking progress for a specific content item.
    func startTracking(contentId: String) {
        self.contentId = contentId
        self.currentPosition = 0
        self.totalDuration = 0
        self.lastSyncPosition = 0
        self.isTracking = true
        self.pendingUpdate = nil
    }

    // MARK: - Update Time

    /// Receives time updates from the player. Triggers a sync when the playback
    /// position has advanced at least `syncInterval` seconds since the last sync.
    func updateTime(current: Double, total: Double) async {
        guard isTracking, let contentId else { return }

        currentPosition = current
        totalDuration = total

        // Check if enough playback time has passed to sync
        let delta = current - lastSyncPosition
        if delta >= syncInterval {
            await sync()
        } else {
            // Store as pending for offline queue
            pendingUpdate = PendingProgressUpdate(
                contentId: contentId,
                position: current,
                duration: total,
                timestamp: Date()
            )
        }
    }

    // MARK: - Sync

    /// Performs the actual API call to persist progress.
    func sync() async {
        guard isTracking, let contentId, totalDuration > 0 else { return }

        let position = currentPosition
        let duration = totalDuration

        do {
            _ = try await progressService.updateProgress(
                contentId: contentId,
                position: position,
                duration: duration
            )
            lastSyncPosition = position
            pendingUpdate = nil
        } catch {
            // Store the failed sync as a pending update
            pendingUpdate = PendingProgressUpdate(
                contentId: contentId,
                position: position,
                duration: duration,
                timestamp: Date()
            )
        }
    }

    // MARK: - Stop Tracking

    /// Performs a final sync and optionally marks the content as complete.
    /// - Parameter markComplete: If true, calls `progressService.markComplete`.
    func stopTracking(markComplete: Bool = false) async {
        guard let contentId else {
            isTracking = false
            return
        }

        // Final sync of current position
        if totalDuration > 0 {
            do {
                _ = try await progressService.updateProgress(
                    contentId: contentId,
                    position: currentPosition,
                    duration: totalDuration
                )
            } catch {
                // Queue for later retry
                pendingUpdate = PendingProgressUpdate(
                    contentId: contentId,
                    position: currentPosition,
                    duration: totalDuration,
                    timestamp: Date()
                )
            }
        }

        // Mark complete if requested
        if markComplete {
            do {
                _ = try await progressService.markComplete(contentId: contentId)
            } catch {
                // Silently fail — will be retried on next app launch
            }
        }

        isTracking = false
        pendingUpdate = nil
    }

    // MARK: - Retry Pending

    /// Retries any pending (failed) progress update.
    func retryPending() async {
        guard let pending = pendingUpdate else { return }

        do {
            _ = try await progressService.updateProgress(
                contentId: pending.contentId,
                position: pending.position,
                duration: pending.duration
            )
            pendingUpdate = nil
        } catch {
            // Keep the pending update for next retry
        }
    }

    // MARK: - Accessors

    /// Returns whether there is an unsynchronized pending update.
    func hasPendingUpdate() -> Bool {
        pendingUpdate != nil
    }

    /// Returns the current tracked position.
    func getCurrentPosition() -> Double {
        currentPosition
    }
}

// MARK: - Pending Progress Update

/// Represents a progress update that failed to sync and is queued for retry.
struct PendingProgressUpdate {
    let contentId: String
    let position: Double
    let duration: Double
    let timestamp: Date
}
