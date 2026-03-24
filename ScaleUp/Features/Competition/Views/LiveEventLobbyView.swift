import SwiftUI

struct LiveEventLobbyView: View {
    let event: LiveEvent

    @State private var viewModel: LiveEventViewModel
    @State private var navigateToSession = false
    @Environment(\.dismiss) private var dismiss

    private let purpleAccent = Color(red: 139.0/255.0, green: 92.0/255.0, blue: 246.0/255.0) // #8B5CF6

    init(event: LiveEvent) {
        self.event = event
        self._viewModel = State(initialValue: LiveEventViewModel(event: event))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if viewModel.error != nil {
                    errorState
                } else {
                    lobbyContent
                }
            }
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToSession) {
                LiveEventSessionView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.joinLobby()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.isLive) { _, isLive in
            if isLive {
                navigateToSession = true
            }
        }
    }

    // MARK: - Lobby Content

    private var lobbyContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                // LIVE EVENT badge
                Text("LIVE EVENT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(purpleAccent)
                    .clipShape(Capsule())

                // Topic name
                Text(event.topic)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Participant count
                participantCounter

                // Countdown timer
                countdownSection

                // Rules reminder
                rulesCard
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Leave Lobby
            leaveLobbyButton
        }
    }

    // MARK: - Participant Counter

    private var participantCounter: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(purpleAccent)

            Text("\(viewModel.participantCount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: viewModel.participantCount)

            Text("participants")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(purpleAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(spacing: 8) {
            if let state = viewModel.lobbyState {
                let remaining = countdownRemaining(from: state.scheduledAt)
                if remaining > 0 {
                    Text("Starts in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Text(formatCountdown(remaining))
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(purpleAccent)
                } else {
                    Text("Starting soon...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(purpleAccent)
                }
            } else {
                ProgressView()
                    .tint(purpleAccent)
                Text("Joining lobby...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    // MARK: - Rules Card

    private var rulesCard: some View {
        VStack(spacing: 10) {
            ruleRow(icon: "questionmark.circle.fill", text: "10 questions")
            ruleRow(icon: "timer", text: "Tiered timers")
            ruleRow(icon: "person.3.fill", text: "Everyone plays at once")
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(purpleAccent.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(purpleAccent)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()
        }
    }

    // MARK: - Leave Lobby

    private var leaveLobbyButton: some View {
        Button {
            viewModel.cleanup()
            dismiss()
        } label: {
            Text("Leave Lobby")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.vertical, 14)
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(viewModel.error ?? "Something went wrong")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.joinLobby() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(purpleAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func countdownRemaining(from scheduledAt: String) -> TimeInterval {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: scheduledAt) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: scheduledAt) else { return 0 }
            return max(0, date.timeIntervalSinceNow)
        }
        return max(0, date.timeIntervalSinceNow)
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
