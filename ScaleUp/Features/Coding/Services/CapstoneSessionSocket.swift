import Foundation

/// WebSocket client for `/ws/coding?sessionId&token&role=mobile`.
/// Auto-reconnects with exponential backoff so spec §12.2 ("5–60 s drop")
/// is handled transparently. Mobile UI shows the badge state via
/// `onStatus`.
@MainActor
final class CapstoneSessionSocket {
    enum ConnectionStatus { case connecting, open, reconnecting, closed }

    enum IncomingMessage {
        case lifecycle(status: CapstoneSessionStatus)
        case stats(SessionStats)
        case unknown
    }

    struct SessionStats: Codable, Sendable {
        let counters: CapstoneSessionCounters?
        let elapsedSeconds: Int?
        let timeBudgetSeconds: Int?
        let remainingSeconds: Int?
        let pausedTotalSeconds: Int?
        let cpuPct: Double?
        let memMb: Double?

        enum CodingKeys: String, CodingKey {
            case counters
            case elapsedSeconds      = "elapsed_seconds"
            case timeBudgetSeconds   = "time_budget_seconds"
            case remainingSeconds    = "remaining_seconds"
            case pausedTotalSeconds  = "paused_total_seconds"
            case cpuPct              = "cpu_pct"
            case memMb               = "mem_mb"
        }
    }

    private let sessionId: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectAttempts: Int = 0
    private var reconnectTask: Task<Void, Never>?
    private var closed = false

    var onStatus: (@MainActor (ConnectionStatus) -> Void)?
    var onMessage: (@MainActor (IncomingMessage) -> Void)?

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    /// Open the socket. Token must be a JWT scoped to this session — the
    /// backend rejects anything else.
    func open(token: String) {
        guard !closed else { return }
        onStatus?(reconnectAttempts == 0 ? .connecting : .reconnecting)
        let host = wsHost()
        guard let url = URL(string: "\(host)/ws/coding?sessionId=\(sessionId)&token=\(token)&role=mobile") else {
            onStatus?(.closed)
            return
        }
        let cfg = URLSessionConfiguration.default
        let s = URLSession(configuration: cfg)
        session = s
        task = s.webSocketTask(with: url)
        task?.resume()
        receiveLoop(token: token)
    }

    func sendControl(_ action: CapstoneControlAction) async {
        struct Out: Codable {
            let type: String
            let action: String
        }
        let payload = Out(type: "session.control", action: action.rawValue)
        guard let data = try? JSONEncoder().encode(payload),
              let str = String(data: data, encoding: .utf8) else { return }
        try? await task?.send(.string(str))
    }

    func close() {
        closed = true
        reconnectTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        onStatus?(.closed)
    }

    // MARK: - Internals

    private func receiveLoop(token: String) {
        Task { [weak self] in
            guard let self else { return }
            while await !self.closed, let t = await self.task {
                do {
                    let msg = try await t.receive()
                    await self.handleMessage(msg)
                } catch {
                    await self.scheduleReconnect(token: token)
                    return
                }
            }
        }
    }

    @MainActor
    private func handleMessage(_ msg: URLSessionWebSocketTask.Message) {
        // First successful message after connect = open.
        if reconnectAttempts != 0 { reconnectAttempts = 0 }
        onStatus?(.open)
        switch msg {
        case .string(let s):
            guard let data = s.data(using: .utf8) else { return }
            decode(data)
        case .data(let d):
            decode(d)
        @unknown default:
            break
        }
    }

    @MainActor
    private func decode(_ data: Data) {
        struct Envelope: Codable { let type: String }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        switch env.type {
        case "session.lifecycle":
            struct Life: Codable { let status: CapstoneSessionStatus }
            if let v = try? JSONDecoder().decode(Life.self, from: data) {
                onMessage?(.lifecycle(status: v.status))
            }
        case "session.stats":
            if let v = try? JSONDecoder().decode(SessionStats.self, from: data) {
                onMessage?(.stats(v))
            }
        default:
            onMessage?(.unknown)
        }
    }

    @MainActor
    private func scheduleReconnect(token: String) {
        guard !closed else { return }
        onStatus?(.reconnecting)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        let attempt = reconnectAttempts
        reconnectAttempts += 1
        let delayMs = min(30_000, 500 * Int(pow(2.0, Double(attempt))))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            guard let self, !(await self.closed) else { return }
            await self.open(token: token)
        }
    }

    private func wsHost() -> String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let v1 = (configured?.isEmpty == false ? configured! : "https://api.scaleupapp.club/api/v1")
        // Strip /api/v1 and swap http(s) → ws(s)
        var host = v1.replacingOccurrences(of: "/api/v1", with: "")
        if host.hasPrefix("https://") {
            host = "wss://" + host.dropFirst("https://".count)
        } else if host.hasPrefix("http://") {
            host = "ws://" + host.dropFirst("http://".count)
        }
        return host
    }
}
