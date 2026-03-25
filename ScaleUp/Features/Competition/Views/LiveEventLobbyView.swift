import SwiftUI

struct LiveEventLobbyView: View {
    let event: LiveEvent

    @State private var viewModel: LiveEventViewModel
    @State private var navigateToSession = false
    @Environment(\.dismiss) private var dismiss

    private let purpleAccent = Color(red: 139.0/255.0, green: 92.0/255.0, blue: 246.0/255.0)

    init(event: LiveEvent) {
        self.event = event
        self._viewModel = State(initialValue: LiveEventViewModel(event: event))
    }

    private var isLobbyOpen: Bool {
        // Lobby is open 5 min before scheduled time
        guard let date = parseISO(event.scheduledAt) else { return false }
        return date.timeIntervalSinceNow <= 5 * 60
    }

    var body: some View {
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
            // Back button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            Spacer()

            VStack(spacing: Spacing.xl) {
                // LIVE EVENT badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(purpleAccent)
                        .frame(width: 6, height: 6)
                    Text("LIVE EVENT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(purpleAccent.opacity(0.2))
                .clipShape(Capsule())

                // Topic name
                Text(event.formattedTitle)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Status indicator
                if viewModel.isInLobby {
                    // Participant count
                    participantCounter

                    // Countdown timer
                    countdownSection
                } else {
                    // Registered / waiting state
                    registeredState
                }

                // Rules reminder
                rulesCard
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Bottom button
            if viewModel.isInLobby {
                leaveLobbyButton
            } else {
                registeredFooter
            }
        }
    }

    // MARK: - Registered State (before lobby opens)

    private var registeredState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("You're registered!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            if let date = parseISO(event.scheduledAt) {
                let remaining = max(0, date.timeIntervalSinceNow)
                if remaining > 5 * 60 {
                    Text("Lobby opens 5 minutes before start")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Text(formatEventDate(date))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(purpleAccent)
                } else {
                    Text("Lobby is opening...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(purpleAccent)
                }
            }

            Text("\(viewModel.participantCount) registered")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
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

            Text("in lobby")
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
            ruleRow(icon: "questionmark.circle.fill", text: "10 questions, tiered difficulty")
            ruleRow(icon: "timer", text: "Timed per question (20-45s)")
            ruleRow(icon: "person.3.fill", text: "Everyone plays at the same time")
            ruleRow(icon: "trophy.fill", text: "Rankings calculated at the end")
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

    // MARK: - Bottom Buttons

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

    private var registeredFooter: some View {
        VStack(spacing: 8) {
            Text("You'll be notified when the lobby opens")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.vertical, 14)
            }
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

    private func parseISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func formatEventDate(_ date: Date) -> String {
        let df = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            df.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            df.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            df.dateFormat = "EEE, MMM d 'at' h:mm a"
        }
        return df.string(from: date)
    }

    private func countdownRemaining(from scheduledAt: String) -> TimeInterval {
        guard let date = parseISO(scheduledAt) else { return 0 }
        return max(0, date.timeIntervalSinceNow)
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
