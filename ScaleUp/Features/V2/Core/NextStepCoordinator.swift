import SwiftUI

/// Decouples an insight screen's "Do this next" action from its presentation
/// context.
///
/// Insight screens (quiz results, interview results, drill results, the
/// readiness breakdown sheet, …) live in many different presentation contexts —
/// some are sheets, some full-screen covers, some navigation pushes, some
/// Compass chat cards — and most do NOT have the navigation router in scope.
///
/// Rather than teach each screen how to navigate, a screen simply `fire`s a
/// typed `Intent` and dismisses itself. `V2MainTabView` (which owns the router)
/// observes `pending` and performs the real navigation once the current screen
/// has dismissed. This keeps the cards dumb and avoids sheet-over-sheet races.
@MainActor
@Observable
final class NextStepCoordinator {
    static let shared = NextStepCoordinator()
    private init() {}

    enum Intent: Equatable {
        case launchQuiz(topic: String)
        case launchDrill(subtype: String?)
        case tutorOn(topic: String)
        case openPlan
        case reviewQuiz(quizId: String)
        case startInterview
    }

    /// Set by a screen's Next Step action; observed + cleared by `V2MainTabView`.
    var pending: Intent?

    func fire(_ intent: Intent) {
        pending = intent
    }
}
