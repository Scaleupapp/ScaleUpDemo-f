import SwiftUI
import SafariServices

/// Sheet host that renders the active V2TaskRouter route as a presentable view.
/// Attach via `.sheet(item: $router.route) { route in V2TaskSheet(route: route, ...) }`.
struct V2TaskSheet: View {
    let route: V2TaskRouter.Route
    let onClose: () -> Void

    var body: some View {
        Group {
            switch route {
            case .content(let id, _):
                NavigationStack {
                    PlayerView(contentId: id)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close", action: onClose)
                            }
                        }
                }

            case .quiz(let id):
                PlanTaskQuizLoaderSheet(quizId: id, onDismiss: onClose)

            case .interview(let scenarioId):
                NavigationStack {
                    V2InterviewLauncher(scenarioId: scenarioId, onClose: onClose)
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
