import Foundation

// MARK: - Debouncer

/// A simple actor-based debounce utility for delaying rapid-fire actions
/// such as search queries. Only the last action within the duration window
/// will execute.
actor Debouncer {

    // MARK: - Properties

    private var task: Task<Void, Never>?
    private let duration: Duration

    // MARK: - Init

    init(duration: Duration = .milliseconds(500)) {
        self.duration = duration
    }

    // MARK: - Debounce

    /// Cancels any pending action and schedules a new one after the
    /// configured duration. If another call arrives before the delay
    /// elapses, the previous action is discarded.
    func debounce(action: @Sendable @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancels the currently pending debounced action, if any.
    func cancel() {
        task?.cancel()
        task = nil
    }
}
