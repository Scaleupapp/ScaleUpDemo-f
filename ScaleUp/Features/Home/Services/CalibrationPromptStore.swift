import Foundation

// MARK: - LEGACY V1 — slated for removal

/// **DEPRECATED — Legacy V1 surface.**
/// Backed v1 HomeView's calibration banner cooldown. v2's coach-led
/// recalibration on V2HomeView/V2YouView uses server-side cooldown only.
/// Scheduled for removal after 2026-06-15.

@MainActor
@available(*, deprecated, message: "Legacy V1 — v2 uses server-side cooldown (see LEGACY_V1.md)")
final class CalibrationPromptStore {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let quietDays = 14
    private let maxPrompts = 3

    private enum Keys {
        static let count       = "calibration.promptCount"
        static let quietUntil  = "calibration.quietUntil"
        static let completed   = "calibration.completed"
    }

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    var promptCount: Int { defaults.integer(forKey: Keys.count) }
    var isCompleted: Bool { defaults.bool(forKey: Keys.completed) }

    func shouldShow() -> Bool {
        if isCompleted { return false }
        if promptCount >= maxPrompts { return false }
        if let quiet = defaults.object(forKey: Keys.quietUntil) as? Date, now() < quiet { return false }
        return true
    }

    func recordShown() {
        defaults.set(promptCount + 1, forKey: Keys.count)
    }

    func recordDismissed() {
        let until = Calendar.current.date(byAdding: .day, value: quietDays, to: now())!
        defaults.set(until, forKey: Keys.quietUntil)
    }

    func recordCompleted() {
        defaults.set(true, forKey: Keys.completed)
    }
}
