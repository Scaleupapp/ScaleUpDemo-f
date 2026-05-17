import SwiftUI
import SafariServices

/// Sheet host that renders the active V2TaskRouter route as a presentable view.
/// Attach via `.sheet(item: $router.route) { route in V2TaskSheet(route: route, ...) }`.
struct V2TaskSheet: View {
    let route: V2TaskRouter.Route
    let onClose: () -> Void

    /// Injected by V2MainTabView — forwarded into the nested tutor sheet so
    /// V2CompassView has its required environment.
    @Environment(V2TaskRouter.self) private var taskRouter
    /// V2CompassView reads AppState directly; re-inject so the review sheet
    /// has it even when SwiftUI doesn't propagate @Observable across hops.
    @Environment(AppState.self) private var appState

    /// Tutor-mode Compass sheet, opened from inside a content view via "Ask Compass".
    @State private var tutorSheet: CompassTutorContext?

    var body: some View {
        Group {
            switch route {
            case .content(let id, let title):
                NavigationStack {
                    V2ContentDispatcher(contentId: id, title: title)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close", action: onClose)
                            }
                            // The merged AI Tutor — opens Compass in tutor mode,
                            // scoped to this content. Same Compass, same history.
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    tutorSheet = CompassTutorContext(contentId: id, title: title)
                                } label: {
                                    Label("Ask Compass", systemImage: "location.north.circle.fill")
                                        .foregroundStyle(ColorTokens.gold)
                                }
                            }
                        }
                }
                .sheet(item: $tutorSheet) { ctx in
                    // Re-inject env — nested sheets don't inherit Observables.
                    V2CompassSheetView(tutorContext: ctx)
                        .environment(taskRouter)
                        .environment(V2NavState())
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }

            case .quiz(let id):
                PlanTaskQuizLoaderSheet(quizId: id, onDismiss: onClose)

            case .quizByTopic(let topic):
                V2QuizRequestLoaderSheet(topic: topic, onClose: onClose)

            case .interview(let scenarioId):
                NavigationStack {
                    V2InterviewLauncher(scenarioId: scenarioId, onClose: onClose)
                }

            case .competition:
                NavigationStack {
                    CompetitionHubView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close", action: onClose)
                            }
                        }
                }

            case .compassReview(let weekNumber, let taskId):
                V2CompassSheetView(
                    currentScreen: .home,
                    reviewContext: CompassReviewContext(weekNumber: weekNumber, taskId: taskId)
                )
                .environment(taskRouter)
                .environment(appState)
                .environment(V2NavState())
                .onAppear {
                    // Mark the synthetic review task complete the moment the
                    // user opens it — the "review" is the act of engaging.
                    // Server is idempotent ($addToSet on reviewedWeeks).
                    if let id = taskId { taskRouter.markComplete(taskId: id) }
                }

            case .external(let url):
                SafariView(url: url, onClose: onClose)

            case .unavailable(let message):
                V2TaskUnavailableView(message: message, onClose: onClose)
            }
        }
    }
}

/// Bridges into v1 InterviewSessionView. Instantiates the InterviewViewModel
/// with the scenarioId from the plan task (when present).
private struct V2InterviewLauncher: View {
    let scenarioId: String?
    let onClose: () -> Void
    @State private var viewModel: InterviewViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                InterviewSessionView(viewModel: vm)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close", action: onClose)
                        }
                    }
            } else {
                ProgressView().tint(ColorTokens.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ColorTokens.background)
            }
        }
        .task {
            // InterviewViewModel default-inits with no scenario; v1 setup flow
            // selects type/duration before starting. v2 jumps directly to setup
            // so the user can still pick.
            viewModel = InterviewViewModel()
        }
    }
}

/// SFSafariViewController wrapper for external-link tasks.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Resolves a Content by id and renders the right viewer for its type.
/// Without this, V2's task router would funnel notes/infographics into
/// PlayerView (video) which is wrong.
private struct V2ContentDispatcher: View {
    let contentId: String
    let title: String

    @State private var content: Content?
    @State private var loadError: String?
    private let service = ContentService()

    var body: some View {
        Group {
            if let content {
                switch content.contentType {
                case .notes:
                    NotesDetailView(contentId: contentId)
                case .video:
                    PlayerView(contentId: contentId)
                case .infographic, .article:
                    // TODO: open a proper in-app reader when one exists.
                    if let urlString = content.contentURL, let url = URL(string: urlString) {
                        SafariView(url: url, onClose: { })
                    } else {
                        PlayerView(contentId: contentId)
                    }
                }
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundStyle(ColorTokens.warning)
                    Text("Couldn't load this content")
                        .font(V2Theme.h3)
                    Text(loadError)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            } else {
                ProgressView().tint(ColorTokens.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        do {
            content = try await service.fetchContent(id: contentId)
        } catch {
            loadError = "This piece of content couldn't be loaded. Try again later."
        }
    }
}

/// Small "we don't have this yet" sheet shown when a task lacks a payload to route on.
private struct V2TaskUnavailableView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hourglass")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.gold)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Got it", action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }
}
