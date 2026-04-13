import Foundation
import Mixpanel

// MARK: - Mixpanel Provider
//
// Thin wrapper around Mixpanel's Swift SDK. All calls hit Mixpanel's internal
// serial queue (thread-safe). No locking needed here.

final class MixpanelProvider: AnalyticsProvider, @unchecked Sendable {

    func initialize(token: String) {
        Mixpanel.initialize(
            token: token,
            trackAutomaticEvents: false,
            flushInterval: 30,
            instanceName: "ScaleUp"
        )
    }

    func identify(userId: String) {
        Mixpanel.mainInstance().identify(distinctId: userId)
    }

    func track(event: String, properties: [String: Any]) {
        let props = sanitize(properties)
        Mixpanel.mainInstance().track(event: event, properties: props)
    }

    func setUserProperties(_ properties: [String: Any]) {
        let props = sanitize(properties)
        Mixpanel.mainInstance().people.set(properties: props)
    }

    func reset() {
        Mixpanel.mainInstance().reset()
    }

    func flush() {
        Mixpanel.mainInstance().flush()
    }

    // Mixpanel requires all property values to conform to MixpanelType.
    // Non-conforming values are dropped to avoid runtime crashes.
    private func sanitize(_ properties: [String: Any]) -> Properties {
        var out: Properties = [:]
        for (key, value) in properties {
            if let v = value as? MixpanelType {
                out[key] = v
            } else {
                out[key] = String(describing: value)
            }
        }
        return out
    }
}
