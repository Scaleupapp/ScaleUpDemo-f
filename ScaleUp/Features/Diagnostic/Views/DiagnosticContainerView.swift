import SwiftUI

struct DiagnosticContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DiagnosticViewModel()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            switch viewModel.phase {
            case .welcome:
                DiagnosticWelcomeView(viewModel: viewModel) {
                    Task { await viewModel.abandonCurrent(at: "welcome") }
                    appState.skipDiagnostic()
                }
            case .selfRating:
                DiagnosticSelfRatingView(viewModel: viewModel)
            case .quiz:
                DiagnosticQuestionView(viewModel: viewModel)
            case .results:
                DiagnosticResultsView(viewModel: viewModel) {
                    appState.markDiagnosticComplete()
                    appState.completeDiagnostic()
                }
            case .error:
                errorView
            }
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ColorTokens.gold)
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.warning)

            Text(viewModel.errorMessage ?? "Something went wrong")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button("Skip for now") { appState.skipDiagnostic() }
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.gold)
        }
    }
}
