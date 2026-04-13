import Foundation

// MARK: - Analytics Provider
//
// Protocol for any analytics backend (Mixpanel today, potentially Amplitude/GA4 later).
// Adding a new provider = implement this protocol and register it in AnalyticsService.
// No ViewModel call site changes required.

protocol AnalyticsProvider: Sendable {
    func initialize(token: String)
    func identify(userId: String)
    func track(event: String, properties: [String: Any])
    func setUserProperties(_ properties: [String: Any])
    func reset()
    func flush()
}
