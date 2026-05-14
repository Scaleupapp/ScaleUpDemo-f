import SwiftUI

/// Routes the v2 "You" tab sections push.
///
/// Each row hops the user into the existing v1 deep view — keeping the
/// surface light while v2-specific drill-downs are still in design.
enum V2YouRoute: Hashable {
    case plan
    case progress
    case objectives
    case compassHistory
    case content
    case settings
    case creator
    case admin
}

/// Maps each route to the v1 view (or a v2-specific stub).
struct V2YouSectionDestination: View {
    let route: V2YouRoute

    var body: some View {
        switch route {
        case .plan:
            // v1 plan deep view; coexists with v2 Home one-hero.
            PlanTabView()

        case .progress:
            V2YouAnalyticsView()

        case .objectives:
            ObjectivesListShim()

        case .compassHistory:
            V2CompassHistoryStub()

        case .content:
            // v1 Discover serves as "my content" landing until v2 has a richer view.
            DiscoverView()

        case .settings:
            SettingsView()

        case .creator:
            V2YouComingSoon(title: "Creator hub", body: "Open this from v1 Profile for now.")

        case .admin:
            V2YouComingSoon(title: "Admin tools", body: "Open this from v1 Profile for now.")
        }
    }
}

/// Light v1-objectives stub since the existing flow lives inside ProfileTabView.
private struct ObjectivesListShim: View {
    var body: some View {
        V2YouComingSoon(
            title: "My objectives",
            body: "Switch objectives from the top header. Add/manage in the next v2 update."
        )
    }
}

/// Light placeholder until we ship the v2 Compass history view.
private struct V2CompassHistoryStub: View {
    var body: some View {
        V2YouComingSoon(
            title: "My Compass activity",
            body: "All your Compass conversations, quizzes generated, and notes created will appear here."
        )
    }
}

private struct V2YouComingSoon: View {
    let title: String
    let message: String

    init(title: String, body: String) {
        self.title = title
        self.message = body
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.gold)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
        .navigationTitle(title)
    }
}
