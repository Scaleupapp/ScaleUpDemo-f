import SwiftUI

// MARK: - Screen Tracking
//
// Attach to any View to auto-fire `screen_viewed` on appear.
// Usage:  SomeView().trackScreen("TodayTab")

extension View {
    /// Fires `screen_viewed` with the given name whenever the view appears.
    @MainActor
    func trackScreen(_ name: String) -> some View {
        onAppear {
            AnalyticsService.shared.track(.screenViewed(name: name))
        }
    }
}
