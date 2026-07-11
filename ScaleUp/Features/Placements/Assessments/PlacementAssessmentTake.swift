import SwiftUI

// MARK: - Wave 3: Instrumentation for institution assessment takes
//
// These types layer integrity telemetry + a deadline countdown ON TOP of the
// shared take surfaces (the MCQ `QuizSessionView` reached via the placement MCQ
// sheet, and the placement interview take). They are applied ONLY from
// PlacementsAssessmentsView's take sheets — the D2C take paths never see them.
//
// Scope guarantee: nothing here is referenced outside `Features/Placements`,
// and the modifier is only attached when a take is launched from a placement
// assessment *session* (the sessionId is threaded in from the start payload).

/// Parses an ISO8601 timestamp, tolerating an optional fractional-seconds part.
private func parseISO(_ s: String?) -> Date? {
    guard let s else { return nil }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: s) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: s)
}

/// Tracks cumulative integrity counters for one placement take and enforces the
/// deadline. All counters are monotonic; the server clamps to the max it has
/// seen, so re-posting the same or lower values is harmless.
@Observable
@MainActor
final class PlacementTakeInstrumenter {
    let sessionId: String
    let deadline: Date?

    /// Seconds left until the deadline. 0 when no deadline is set.
    private(set) var remaining: TimeInterval = 0
    /// Flips true exactly once when the deadline passes.
    private(set) var timeUp = false

    // Cumulative (monotonic) counters posted to the backend snapshot.
    private var appBackgroundedCount = 0
    private var focusLossSeconds = 0
    // No instrumented text-input take surface exists yet (MCQ / interview) → we
    // never send pasteCount. Kept for when a typed take surface is added.
    private var pasteCount = 0
    private var tracksPaste = false

    private var backgroundEnteredAt: Date?
    private var tickTask: Task<Void, Never>?

    init(sessionId: String, deadlineAt: String?) {
        self.sessionId = sessionId
        self.deadline = parseISO(deadlineAt)
        if let deadline { remaining = max(0, deadline.timeIntervalSinceNow) }
    }

    var hasDeadline: Bool { deadline != nil }

    /// Begins the once-a-second countdown loop (no-op when there is no deadline).
    func start() {
        guard let deadline, tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.remaining = max(0, deadline.timeIntervalSinceNow)
                if self.remaining <= 0 {
                    if !self.timeUp { self.timeUp = true }
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    // MARK: Scene-phase driven telemetry

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            appBackgroundedCount += 1
            backgroundEnteredAt = Date()
        case .active:
            if let started = backgroundEnteredAt {
                focusLossSeconds += Int(Date().timeIntervalSince(started).rounded())
                backgroundEnteredAt = nil
                postSnapshot()   // POST on each foreground-return
            }
        default:
            break
        }
    }

    /// Best-effort snapshot POST. Silent on failure (incl. 409 once terminal).
    func postSnapshot() {
        let body = PlacementIntegritySnapshot(
            appBackgroundedCount: appBackgroundedCount,
            focusLossSeconds: focusLossSeconds,
            pasteCount: tracksPaste ? pasteCount : nil
        )
        let sessionId = sessionId
        Task {
            _ = try? await PlacementsAssessmentsApi.shared.postIntegritySnapshot(
                sessionId: sessionId,
                snapshot: body
            )
        }
    }

    /// Called once when the take ends (completion, dismiss, or time-up).
    func finish() {
        // If still counting a background interval, fold it in before the last post.
        if let started = backgroundEnteredAt {
            focusLossSeconds += Int(Date().timeIntervalSince(started).rounded())
            backgroundEnteredAt = nil
        }
        postSnapshot()
    }
}

// MARK: - Container

/// Wraps a take surface with the countdown pill + a one-time disclosure, wires
/// scene-phase telemetry, and drives the graceful time-up handoff. A container
/// `View` (rather than a `ViewModifier`) so it inherits SwiftUI's implicit
/// main-actor isolation cleanly under Swift 6 strict concurrency.
private struct PlacementTakeContainer<Content: View>: View {
    @State private var instr: PlacementTakeInstrumenter
    @State private var showDisclosure = true
    @State private var handedOffTimeUp = false
    @Environment(\.scenePhase) private var scenePhase

    /// Invoked once, after the "Time's up" message shows, to submit + surface
    /// the result. Owner (PlacementsAssessmentsView) performs sync + dismiss.
    private let onTimeUp: () -> Void
    private let content: Content

    init(
        sessionId: String,
        deadlineAt: String?,
        onTimeUp: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _instr = State(initialValue: PlacementTakeInstrumenter(sessionId: sessionId, deadlineAt: deadlineAt))
        self.onTimeUp = onTimeUp
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: .top) { topOverlay }
            .overlay { if instr.timeUp { timeUpOverlay } }
            .onChange(of: scenePhase) { _, newPhase in
                instr.scenePhaseChanged(to: newPhase)
            }
            .onChange(of: instr.timeUp) { _, up in
                guard up, !handedOffTimeUp else { return }
                handedOffTimeUp = true
                instr.finish()
                Task {
                    // Let the student read "Time's up" before we tear down.
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    onTimeUp()
                }
            }
            .task {
                instr.start()
                // Auto-hide the disclosure after it's been read.
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                withAnimation { showDisclosure = false }
            }
            .onDisappear {
                instr.finish()
                instr.stop()
            }
    }

    // MARK: Overlays

    @ViewBuilder
    private var topOverlay: some View {
        if !instr.timeUp {
            VStack(spacing: 8) {
                if instr.hasDeadline {
                    countdownPill
                }
                if showDisclosure {
                    disclosureLine
                        .transition(.opacity)
                }
            }
            .padding(.top, 6)
        }
    }

    private var countdownPill: some View {
        let secs = Int(instr.remaining.rounded())
        let warning = secs <= 300   // under 5 minutes
        let mm = secs / 60
        let ss = secs % 60
        return HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(String(format: "%02d:%02d", mm, ss))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(warning ? Color.white : ColorTokens.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(warning ? ColorTokens.error : ColorTokens.surfaceElevated)
        )
        .overlay(
            Capsule().strokeBorder(
                (warning ? Color.white : ColorTokens.border).opacity(0.35),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }

    private var disclosureLine: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text("This assessment records app-switching during the attempt")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(ColorTokens.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorTokens.surface.opacity(0.92)))
    }

    private var timeUpOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.gold)
                Text("Time's up")
                    .font(V2Theme.h2)
                    .foregroundStyle(.white)
                Text("Submitting what you completed…")
                    .font(V2Theme.body)
                    .foregroundStyle(.white.opacity(0.85))
                ProgressView()
                    .tint(ColorTokens.gold)
            }
            .padding(28)
        }
    }
}

extension View {
    /// Attaches placement-take instrumentation (integrity telemetry + deadline
    /// countdown). Placement-only — never applied to D2C take paths.
    func placementTakeInstrumentation(
        sessionId: String,
        deadlineAt: String?,
        onTimeUp: @escaping () -> Void
    ) -> some View {
        PlacementTakeContainer(sessionId: sessionId, deadlineAt: deadlineAt, onTimeUp: onTimeUp) { self }
    }
}
