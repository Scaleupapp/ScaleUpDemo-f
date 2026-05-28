import SwiftUI

/// Mobile-side capstone-in-progress screen (spec §7.2 step 8). Mobile is
/// the command surface — the learner is coding on the laptop while this
/// screen renders heartbeat stats every ~10 s + offers pause / abort.
///
/// When the session reaches `submitted`/`evaluating`/`graded`, the screen
/// transitions to a "we'll notify you" terminal state. The result is
/// reached by the user re-opening the app from the push notification or
/// by pulling to refresh.
struct CapstoneLiveView: View {
    let bundle: CapstoneLibraryEntry
    let sessionId: String
    let timeBudgetSeconds: Int
    let onClose: () -> Void

    @State private var status: CapstoneSessionStatus = .ready
    @State private var startedAt: Date?
    @State private var pausedTotalSec: Int = 0
    @State private var counters = CapstoneSessionCounters()
    @State private var connectionStatus: CapstoneSessionSocket.ConnectionStatus = .connecting
    @State private var socket: CapstoneSessionSocket?
    @State private var error: String?
    @State private var showAbortConfirm = false
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusHeader

                    timerSection

                    countersGrid

                    connectionBadge

                    bundleBlurb

                    if status == .ready {
                        readyHint
                    }

                    Spacer(minLength: 16)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                actionRow.padding(20).background(.regularMaterial)
            }
            .navigationTitle("Capstone in progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: { Image(systemName: "chevron.down") }
                }
            }
            .onAppear { startSocket() }
            .onDisappear { socket?.close() }
            .alert("Abort capstone?", isPresented: $showAbortConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Abort", role: .destructive) {
                    Task { await abort() }
                }
            } message: {
                Text("Your session will be discarded. This can't be undone.")
            }
            .alert("Something went wrong", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .fullScreenCover(isPresented: $showResult) {
                CapstoneResultView(sessionId: sessionId, onClose: onClose)
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 4) {
            Text(status.displayLabel)
                .font(.title3.weight(.semibold))
            if status == .in_progress {
                Text("Keep coding on the laptop — we're listening.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timerSection: some View {
        TimerDisplay(startedAt: startedAt, totalSeconds: timeBudgetSeconds, pausedTotalSeconds: pausedTotalSec)
    }

    private var countersGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CounterTile(label: "Files changed", value: counters.filesChanged ?? 0)
            CounterTile(label: "Compass turns", value: counters.compassTurns ?? 0)
            CounterTile(label: "Tests passing",
                        value: counters.testsPassing ?? 0,
                        total: counters.testsTotal)
            CounterTile(label: "Tests run", value: counters.testsRun ?? 0)
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(connColor).frame(width: 8, height: 8)
            Text(connLabel).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var bundleBlurb: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Brief").font(.headline)
            Text(bundle.brief).font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var readyHint: some View {
        Text("Open `scaleup-web-seven.vercel.app/capstone` on your laptop and enter the code from the previous screen to start coding.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                showAbortConfirm = true
            } label: {
                Text("Abort")
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.red.opacity(0.18))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if status == .in_progress {
                Button {
                    Task { await togglePause() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if status == .paused {
                Button {
                    Task { await togglePause() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Socket lifecycle

    private func startSocket() {
        // Mobile-side socket uses the user's primary access token, NOT the
        // short-lived pairing JWT (that's laptop-only). The /capstones/start
        // response doesn't include a mobile WS token; we connect via the
        // primary bearer token already in the keychain.
        Task {
            guard let token = await KeychainManager.shared.accessToken else {
                error = "Couldn't authenticate the session socket. Please re-open the app."
                return
            }
            let s = CapstoneSessionSocket(sessionId: sessionId)
            s.onStatus = { connectionStatus = $0 }
            s.onMessage = { msg in
                switch msg {
                case .lifecycle(let st):
                    status = st
                    if [.submitted, .evaluating, .graded].contains(st) {
                        showResult = true
                    }
                case .stats(let stats):
                    if let c = stats.counters { counters = c }
                    if let p = stats.pausedTotalSeconds { pausedTotalSec = p }
                    // Refresh startedAt from the status endpoint on first stats arrival
                    if startedAt == nil {
                        Task { await refreshStartedAt() }
                    }
                case .unknown:
                    break
                }
            }
            socket = s
            s.open(token: token)
            await refreshStartedAt()
        }
    }

    private func refreshStartedAt() async {
        do {
            let s = try await CapstoneService.shared.getStatus(sessionId: sessionId)
            startedAt = s.startedAt
            pausedTotalSec = s.pausedTotalSeconds
            status = s.status
            if let c = s.counters { counters = c }
        } catch {
            // ignore — heartbeat will catch up
        }
    }

    private func togglePause() async {
        do {
            let next: CapstoneControlAction = status == .paused ? .resume : .pause
            _ = try await CapstoneService.shared.control(sessionId: sessionId, action: next)
        } catch {
            self.error = "Couldn't change session state."
        }
    }

    private func abort() async {
        do {
            _ = try await CapstoneService.shared.control(sessionId: sessionId, action: .abort)
            onClose()
        } catch {
            self.error = "Couldn't abort. The laptop will keep its session open — submit or close it there."
        }
    }

    private var connLabel: String {
        switch connectionStatus {
        case .connecting:   return "Connecting"
        case .open:         return "Live"
        case .reconnecting: return "Reconnecting"
        case .closed:       return "Disconnected"
        }
    }
    private var connColor: Color {
        switch connectionStatus {
        case .open: return .green
        case .reconnecting: return .orange
        case .closed: return .gray
        case .connecting: return .blue
        }
    }
}

// MARK: - Subviews

private struct CounterTile: View {
    let label: String
    let value: Int
    var total: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(total != nil ? "\(value)/\(total!)" : "\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TimerDisplay: View {
    let startedAt: Date?
    let totalSeconds: Int
    let pausedTotalSeconds: Int

    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 2) {
            Text(timeString)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text("remaining").font(.caption2).foregroundStyle(.secondary)
        }
        .onReceive(ticker) { now = $0 }
    }

    private var remaining: Int {
        guard let start = startedAt else { return totalSeconds }
        let elapsed = max(0, Int(now.timeIntervalSince(start)) - pausedTotalSeconds)
        return max(0, totalSeconds - elapsed)
    }

    private var timeString: String {
        let r = remaining
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    private var color: Color {
        let frac = Double(remaining) / Double(max(1, totalSeconds))
        if frac > 0.5 { return .green }
        if frac > 0.2 { return .yellow }
        return .red
    }
}
