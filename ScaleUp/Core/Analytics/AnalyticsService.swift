import Foundation
import UIKit

// MARK: - Analytics Service
//
// Fan-out dispatcher for every analytics event in the app.
// Public API:
//   AnalyticsService.shared.configure(mixpanelToken:)   // once, at app launch
//   AnalyticsService.shared.track(.appOpened)           // fire an event
//   AnalyticsService.shared.identify(userId:)           // on login
//   AnalyticsService.shared.setUserProperties(_:)       // after onboarding
//   AnalyticsService.shared.reset()                     // on logout
//
// All calls are fire-and-forget. Providers handle their own threading.

@MainActor
final class AnalyticsService {

    static let shared = AnalyticsService()

    private var providers: [AnalyticsProvider] = []
    private var isConfigured = false
    private var identifiedUserId: String?

    private init() {}

    // MARK: - Configuration

    /// Call once at app launch, before any tracking.
    func configure(mixpanelToken: String) {
        guard !isConfigured else { return }

        let mixpanel = MixpanelProvider()
        mixpanel.initialize(token: mixpanelToken)
        providers.append(mixpanel)

        isConfigured = true
    }

    // MARK: - Identify

    /// Associate all subsequent events with this user.
    /// Safe to call repeatedly — no-ops if already identified with the same ID.
    func identify(userId: String) {
        guard identifiedUserId != userId else { return }
        identifiedUserId = userId
        providers.forEach { $0.identify(userId: userId) }
    }

    // MARK: - Track

    func track(_ event: AnalyticsEvent) {
        guard isConfigured else { return }
        let enriched = enrich(event.properties)
        providers.forEach { $0.track(event: event.name, properties: enriched) }
    }

    // MARK: - User Properties

    func setUserProperties(_ properties: AnalyticsUserProperties) {
        guard isConfigured else { return }
        providers.forEach { $0.setUserProperties(properties.dictionary) }
    }

    func setUserProperty(_ key: String, value: Any) {
        guard isConfigured else { return }
        providers.forEach { $0.setUserProperties([key: value]) }
    }

    // MARK: - Lifecycle

    /// Clear identity on logout. Events fired after this are anonymous.
    func reset() {
        identifiedUserId = nil
        providers.forEach { $0.reset() }
    }

    /// Force-send any queued events. Call on app background.
    func flush() {
        providers.forEach { $0.flush() }
    }

    // MARK: - Session Management

    private var sessionStartTime: Date?

    /// Call when the app enters foreground.
    func handleAppForeground() {
        sessionStartTime = Date()
        track(.sessionStarted)
        fireDailyActiveIfNeeded()
    }

    /// Call when the app enters background.
    func handleAppBackground() {
        if let start = sessionStartTime {
            let duration = Int(Date().timeIntervalSince(start))
            track(.sessionEnded(durationSeconds: duration))
        }
        sessionStartTime = nil
        flush()
    }

    /// Fires `daily_active` at most once per calendar day.
    private func fireDailyActiveIfNeeded() {
        let key = "analytics.dailyActive.lastFired"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let defaults = UserDefaults.standard
        if defaults.string(forKey: key) != today {
            defaults.set(today, forKey: key)
            track(.dailyActive)
        }
    }

    // MARK: - Feature First Used

    /// Fires `feature_first_used` at most once per feature per device install.
    func trackFeatureFirstUsed(_ feature: String) {
        let key = "analytics.featureFirstUsed.\(feature)"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        track(.featureFirstUsed(feature: feature))
    }

    // MARK: - C2O Transition Tracking
    //
    // Tracks "content → quiz" and "quiz weakness → remediation content" patterns.
    // A transition fires when the second event happens within a time window of the first.

    private let c2oWindowSeconds: TimeInterval = 30 * 60  // 30 min for content→quiz

    /// Record content completion. Seeds the transition window.
    func recordContentCompleted(contentId: String) {
        UserDefaults.standard.set(contentId, forKey: "analytics.transition.lastContentId")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "analytics.transition.lastContentAt")
    }

    /// Call when a quiz starts. Fires content_to_quiz_transition if within window.
    func checkContentToQuizTransition(quizId: String) {
        let defaults = UserDefaults.standard
        let lastAt = defaults.double(forKey: "analytics.transition.lastContentAt")
        guard lastAt > 0, Date().timeIntervalSince1970 - lastAt < c2oWindowSeconds else { return }
        guard let lastContentId = defaults.string(forKey: "analytics.transition.lastContentId") else { return }
        track(.contentToQuizTransition(contentId: lastContentId, quizId: quizId))
        defaults.removeObject(forKey: "analytics.transition.lastContentAt")
    }

    /// Record quiz completion with weak topics. Seeds the remediation window.
    func recordQuizCompleted(quizId: String, weakTopics: [String]) {
        UserDefaults.standard.set(quizId, forKey: "analytics.transition.lastQuizId")
        UserDefaults.standard.set(weakTopics, forKey: "analytics.transition.lastQuizWeakTopics")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "analytics.transition.lastQuizAt")
    }

    /// Call when content starts. Fires quiz_weakness_to_content if topic matches a recent weakness.
    func checkQuizWeaknessToContent(contentId: String, topic: String?) {
        let defaults = UserDefaults.standard
        let lastAt = defaults.double(forKey: "analytics.transition.lastQuizAt")
        guard lastAt > 0, Date().timeIntervalSince1970 - lastAt < 24 * 60 * 60 else { return }
        guard let lastQuizId = defaults.string(forKey: "analytics.transition.lastQuizId"),
              let weakTopics = defaults.stringArray(forKey: "analytics.transition.lastQuizWeakTopics"),
              let topic, weakTopics.contains(topic) else { return }
        track(.quizWeaknessToContent(quizId: lastQuizId, contentId: contentId, topic: topic))
    }

    /// Record interview completion. Seeds the interview-gap window.
    func recordInterviewCompleted(sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: "analytics.transition.lastInterviewId")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "analytics.transition.lastInterviewAt")
    }

    /// Call when content starts. Fires interview_gap_to_content if within window.
    func checkInterviewGapToContent(contentId: String) {
        let defaults = UserDefaults.standard
        let lastAt = defaults.double(forKey: "analytics.transition.lastInterviewAt")
        guard lastAt > 0, Date().timeIntervalSince1970 - lastAt < 48 * 60 * 60 else { return }
        guard let lastInterviewId = defaults.string(forKey: "analytics.transition.lastInterviewId") else { return }
        track(.interviewGapToContent(sessionId: lastInterviewId, contentId: contentId))
    }

    // MARK: - Enrichment

    /// Auto-attach app/device context to every event.
    private func enrich(_ properties: [String: Any]) -> [String: Any] {
        var props = properties
        props["app_version"] = Self.appVersion
        props["build_number"] = Self.buildNumber
        props["platform"] = "ios"
        return props
    }

    private static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }()

    private static let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }()
}
