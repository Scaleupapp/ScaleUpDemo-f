import Foundation
import SwiftData

// MARK: - Offline Progress Update

/// SwiftData model for queuing progress updates when the device is offline.
/// Each record represents a single progress update or "mark complete" action
/// that will be synced to the server when connectivity is restored.
@Model
final class OfflineProgressUpdate {

    // MARK: - Properties

    /// The content item this progress update relates to.
    var contentId: String

    /// Current playback position in seconds.
    var currentPosition: Int

    /// Total duration of the content in seconds.
    var totalDuration: Int

    /// When `true`, this entry represents a "mark complete" action
    /// rather than an incremental position update.
    var isCompleteAction: Bool

    /// Timestamp when the update was enqueued locally.
    var createdAt: Date

    /// Number of times the system has attempted (and failed) to sync this update.
    /// Items exceeding the maximum retry count are discarded.
    var retryCount: Int

    // MARK: - Init

    init(
        contentId: String,
        currentPosition: Int,
        totalDuration: Int,
        isCompleteAction: Bool = false
    ) {
        self.contentId = contentId
        self.currentPosition = currentPosition
        self.totalDuration = totalDuration
        self.isCompleteAction = isCompleteAction
        self.createdAt = Date()
        self.retryCount = 0
    }
}
