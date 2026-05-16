import SwiftUI

/// Tiny helper that loads a v1 InterviewSession by id and routes to the
/// right v1 screen based on its status. Used by V2InterviewHomeView when
/// the user taps a row — completed/evaluated → InterviewResultsView,
/// in_progress → InterviewSessionView so they can resume.
struct V2InterviewSessionLauncher: View {
    let sessionId: String

    @State private var viewModel = InterviewViewModel()
    @State private var loadedStatus: InterviewStatus?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let status = loadedStatus {
                switch status {
                case .completed, .evaluating, .evaluated, .abandoned:
                    InterviewResultsView(viewModel: viewModel)
                case .in_progress, .setup:
                    InterviewSessionView(viewModel: viewModel)
                }
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundStyle(ColorTokens.warning)
                    Text("Couldn't load this interview")
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(loadError)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .background(ColorTokens.background.ignoresSafeArea())
            } else {
                ProgressView()
                    .tint(ColorTokens.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ColorTokens.background.ignoresSafeArea())
            }
        }
        .task {
            await viewModel.loadSession(sessionId)
            // After loadSession, viewModel.fullSession should be populated.
            // Use its status to decide the view. Best-effort fallback:
            if let session = viewModel.fullSession {
                loadedStatus = session.status
            } else {
                loadError = "The session may have been removed."
            }
        }
    }
}
