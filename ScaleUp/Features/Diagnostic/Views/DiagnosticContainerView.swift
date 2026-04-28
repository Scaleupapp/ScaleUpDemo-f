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
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.warning.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(ColorTokens.warning)
            }
            .padding(.bottom, Spacing.xl)

            // Title
            Text("We hit a snag")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.bottom, Spacing.sm)

            // Body
            Text(
                (viewModel.errorMessage?.isEmpty == false)
                    ? viewModel.errorMessage!
                    : "We couldn't load your questions. This usually clears up in a moment."
            )
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Try again") {
                    Task { await viewModel.retry() }
                }

                Button("Skip for now") { appState.skipDiagnostic() }
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }
}
