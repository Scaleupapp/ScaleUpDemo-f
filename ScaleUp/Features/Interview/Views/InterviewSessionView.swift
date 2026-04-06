import SwiftUI

/// Root container that manages the interview lifecycle state transitions.
/// Presented as a fullScreenCover from InterviewSetupView.
struct InterviewSessionView: View {
    @State var viewModel: InterviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            switch viewModel.state {
            case .setup:
                InterviewSetupView(viewModel: viewModel)

            case .cameraCheck:
                InterviewCameraCheckView(viewModel: viewModel)

            case .connecting:
                connectingState

            case .interviewing:
                InterviewLiveView(viewModel: viewModel)

            case .concluding:
                concludingState

            case .saving, .evaluating:
                InterviewResultsView(viewModel: viewModel)

            case .results:
                InterviewResultsView(viewModel: viewModel)

            case .error(let message):
                errorView(message)
            }
        }
        .animation(Motion.easeOut, value: viewModel.state)
    }

    // MARK: - Error State

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(Typography.titleMedium)
                .foregroundStyle(.white)

            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                viewModel.state = .setup
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Again")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ColorTokens.gold)
                .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Connecting State

    private var connectingState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.15))
                    .frame(width: 100, height: 100)

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ColorTokens.gold)
            }

            Text("Connecting to interviewer...")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Connecting to AI interviewer...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
    }

    // MARK: - Concluding State

    private var concludingState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.success.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.success)
            }

            Text("Interview Complete")
                .font(Typography.titleLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Wrapping up and preparing evaluation...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)

            ProgressView()
                .tint(ColorTokens.gold)

            Spacer()
        }
    }
}
