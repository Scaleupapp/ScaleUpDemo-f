import SwiftUI

/// V2 Plan Creation — the final onboarding step.
///
/// Order: Objective → Confirmation → Topics → Proficiency → Diagnostic
///        → Reality Check → **Plan Creation**.
///
/// Plan generation was triggered at the end of the Reality Check. This screen
/// polls /api/v2/plan/generation-status and shows the progress, then drops the
/// user into Home once the plan is ready (or after a graceful timeout — Home
/// has its own "plan brewing" state as a safety net).
struct V2PlanCreationView: View {
    let attemptId: String
    let onDone: () -> Void

    @State private var status: String = "generating"
    @State private var elapsed: Int = 0
    @State private var pollTask: Task<Void, Never>?

    // After this many seconds we let the user proceed regardless — Home's
    // own plan-brewing fallback covers the rest.
    private let softTimeout = 75

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated mark
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.12))
                    .frame(width: 120, height: 120)
                if isReady {
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(ColorTokens.gold)
                }
            }
            .padding(.bottom, 28)

            Text(isReady ? "Your plan is ready" : "Creating your plan")
                .font(V2Theme.h1)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.bottom, 10)

            Text(isReady
                 ? "We've built your week-by-week roadmap from your objective, topics, and diagnostic."
                 : "We're turning your objective, topics, and diagnostic into a personalized week-by-week plan.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            if !isReady && !isFailed {
                // The honest "what we're doing" checklist — moves as it works
                VStack(alignment: .leading, spacing: 10) {
                    stepRow("Mapping your topics", done: elapsed > 2)
                    stepRow("Sequencing your weeks", done: elapsed > 10)
                    stepRow("Picking your content + practice", done: elapsed > 20)
                    stepRow("Projecting your readiness curve", done: elapsed > 32)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(ColorTokens.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                .padding(.horizontal, V2Theme.pad)
            }

            if isFailed {
                Text("This is taking longer than usual — your plan will be ready shortly. You can head in now.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                pollTask?.cancel()
                onDone()
            } label: {
                Text(isReady ? "Start learning" : (canSkip ? "Head to Home" : "Creating…"))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background((isReady || canSkip) ? ColorTokens.gold : ColorTokens.surfaceElevated)
                    .foregroundStyle((isReady || canSkip) ? ColorTokens.background : ColorTokens.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!isReady && !canSkip)
            .padding(.horizontal, V2Theme.pad)
            .padding(.bottom, 30)
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    private var isReady: Bool { status == "ready" }
    private var isFailed: Bool { status == "failed" || elapsed >= softTimeout }
    private var canSkip: Bool { elapsed >= 20 }   // let them move on after 20s

    private func stepRow(_ label: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundStyle(done ? ColorTokens.success : ColorTokens.textTertiary)
            Text(label)
                .font(V2Theme.body)
                .foregroundStyle(done ? ColorTokens.textPrimary : ColorTokens.textSecondary)
            Spacer()
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                do {
                    let s = try await V2OnboardingService.shared.planGenerationStatus(attemptId: attemptId)
                    await MainActor.run { status = s.status }
                    if s.status == "ready" || s.status == "failed" { break }
                } catch {
                    // transient — keep polling
                }
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { elapsed += 3 }
                if elapsed >= softTimeout { break }
            }
        }
    }
}
