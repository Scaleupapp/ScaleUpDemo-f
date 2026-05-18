import SwiftUI

// MARK: - Codable shapes

/// One Compass conversation thread (list row).
/// Date fields are kept as ISO strings to avoid a custom JSONDecoder strategy
/// (matches the v2 home pattern). Use V2CompassDate to parse on demand.
struct V2CompassSession: Codable, Identifiable, Hashable {
    let sessionId: String
    let title: String?
    let mode: String?
    let startedAt: String?
    let endedAt: String?
    let messageCount: Int?
    let firstUserMessage: String?
    let lastAssistantMessage: String?
    let topic: String?
    let scope: String?

    var id: String { sessionId }
}

/// One message inside a Compass session transcript.
struct V2CompassMessage: Codable, Hashable {
    let role: String
    let content: String?
    let mode: String?
    let contentTitle: String?
    let createdAt: String?

    var isUser: Bool { role == "user" }
}

/// ISO-8601 parsing helper shared by Compass + Activities views.
enum V2CompassDate {
    nonisolated(unsafe) private static let fracFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ iso: String?) -> Date? {
        guard let iso = iso, !iso.isEmpty else { return nil }
        return fracFormatter.date(from: iso) ?? plainFormatter.date(from: iso)
    }
}

/// Top-level response data for the list endpoint.
struct V2CompassHistoryData: Codable {
    let sessions: [V2CompassSession]?
    let pagination: V2CompassHistoryPagination?
    let nextCursor: String?
}

struct V2CompassHistoryPagination: Codable {
    let page: Int?
    let limit: Int?
    let total: Int?
    let hasMore: Bool?
}

/// Top-level response data for the single-session detail endpoint.
/// Backend returns the session fields at the `data` root (no `session` wrapper),
/// so this is the type we decode into V2APIResponse<V2CompassSessionDetail>.
struct V2CompassSessionDetail: Codable {
    let sessionId: String?
    let title: String?
    let mode: String?
    let startedAt: String?
    let endedAt: String?
    let messageCount: Int?
    let messages: [V2CompassMessage]?
}

// MARK: - Mode helpers

enum V2CompassMode: String, CaseIterable, Identifiable {
    case all, coach, tutor, conversation, note

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .all: return "All"
        case .coach: return "Coach"
        case .tutor: return "Tutor"
        case .conversation: return "Conversation"
        case .note: return "Notes"
        }
    }

    /// Backend mode strings that this filter chip should match.
    func matches(_ raw: String?) -> Bool {
        guard self != .all else { return true }
        guard let raw = raw?.lowercased() else { return false }
        switch self {
        case .all: return true
        case .coach: return raw == "coach"
        case .tutor: return raw == "tutor"
        case .conversation: return raw == "conversation" || raw == "greeting"
        case .note: return raw == "note"
        }
    }
}

/// Pretty label + dot color for any backend mode string.
enum V2CompassModeDisplay {
    static func label(for raw: String?) -> String {
        switch (raw ?? "").lowercased() {
        case "coach": return "Coach"
        case "tutor": return "Tutor"
        case "conversation": return "Chat"
        case "quiz_config": return "Quiz setup"
        case "interview_config": return "Interview setup"
        case "note": return "Notes"
        case "insight": return "Insight"
        case "mentor": return "Mentor"
        case "greeting": return "Chat"
        default: return "Chat"
        }
    }

    static func dotColor(for raw: String?) -> Color {
        switch (raw ?? "").lowercased() {
        case "coach": return ColorTokens.gold
        case "tutor": return ColorTokens.success
        case "conversation", "greeting": return ColorTokens.textSecondary
        case "note": return ColorTokens.warning
        default: return ColorTokens.info
        }
    }
}

// MARK: - View model

@Observable
@MainActor
final class V2CompassHistoryViewModel {
    var sessions: [V2CompassSession] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var error: String?
    var page: Int = 1
    var hasMore: Bool = false

    private let pageSize: Int = 20

    func load() async {
        isLoading = true
        defer { isLoading = false }
        page = 1
        do {
            let resp: V2APIResponse<V2CompassHistoryData> = try await V2APIClient.shared.get(
                "/you/compass/history?page=1&limit=\(pageSize)"
            )
            sessions = resp.data.sessions ?? []
            hasMore = resp.data.pagination?.hasMore ?? (resp.data.nextCursor != nil)
            error = nil
        } catch {
            self.error = "Could not load Compass history."
        }
    }

    func loadMoreIfNeeded(after session: V2CompassSession) async {
        guard hasMore, !isLoadingMore else { return }
        guard let last = sessions.last, last.sessionId == session.sessionId else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = page + 1
        do {
            let resp: V2APIResponse<V2CompassHistoryData> = try await V2APIClient.shared.get(
                "/you/compass/history?page=\(nextPage)&limit=\(pageSize)"
            )
            let incoming = resp.data.sessions ?? []
            // De-dupe by sessionId.
            let existing = Set(sessions.map(\.sessionId))
            sessions.append(contentsOf: incoming.filter { !existing.contains($0.sessionId) })
            page = nextPage
            hasMore = resp.data.pagination?.hasMore ?? false
        } catch {
            // Silent — keep what we have.
        }
    }
}

@Observable
@MainActor
final class V2CompassSessionDetailViewModel {
    var detail: V2CompassSessionDetail?
    var isLoading: Bool = false
    var error: String?

    private let sessionId: String

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Backend returns the session fields at `data` root (sessionId, messages, …)
            let resp: V2APIResponse<V2CompassSessionDetail> = try await V2APIClient.shared.get(
                "/you/compass/history?sessionId=\(sessionId)"
            )
            detail = resp.data
            error = nil
        } catch {
            self.error = "Could not load transcript."
        }
    }
}

// MARK: - Main view

struct V2CompassHistoryView: View {
    @State private var vm = V2CompassHistoryViewModel()
    @State private var didLoad = false
    @State private var selectedMode: V2CompassMode = .all
    @State private var selectedSession: V2CompassSession?

    public init() {}

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            content
        }
        .navigationTitle("Compass history")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didLoad {
                didLoad = true
                await vm.load()
            }
        }
        .refreshable { await vm.load() }
        .sheet(item: $selectedSession) { session in
            V2CompassSessionDetailSheet(session: session)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.sessions.isEmpty {
            VStack(spacing: 12) {
                ProgressView().tint(ColorTokens.gold)
                Text("Loading your Compass activity…")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error, vm.sessions.isEmpty {
            emptyState(icon: "exclamationmark.triangle", title: err, hint: "Pull to retry")
        } else if vm.sessions.isEmpty {
            emptyState(
                icon: "bubble.left.and.bubble.right",
                title: "No Compass chats yet",
                hint: "Start a coach or tutor session from Compass."
            )
        } else {
            list
        }
    }

    private var filteredSessions: [V2CompassSession] {
        guard selectedMode != .all else { return vm.sessions }
        return vm.sessions.filter { selectedMode.matches($0.mode) }
    }

    @ViewBuilder
    private var list: some View {
        ScrollView {
            VStack(spacing: V2Theme.gap) {
                filterStrip
                    .padding(.horizontal, V2Theme.pad)
                    .padding(.top, 8)

                if filteredSessions.isEmpty {
                    VStack(spacing: 6) {
                        Text("No \(selectedMode.chipLabel.lowercased()) sessions yet")
                            .font(V2Theme.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: V2Theme.gap) {
                        ForEach(filteredSessions) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                sessionRow(session)
                            }
                            .buttonStyle(.plain)
                            .task {
                                await vm.loadMoreIfNeeded(after: session)
                            }
                        }

                        if vm.isLoadingMore {
                            ProgressView().tint(ColorTokens.gold)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, V2Theme.pad)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("FILTER")
                    .v2Eyebrow(ColorTokens.textTertiary)
                    .padding(.trailing, 4)
                ForEach(V2CompassMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Text(mode.chipLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedMode == mode ? ColorTokens.background : ColorTokens.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selectedMode == mode ? ColorTokens.gold : ColorTokens.surface)
                            )
                            .overlay(
                                Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: selectedMode == mode ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ s: V2CompassSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(headerLine(for: s))
                    .v2Eyebrow(ColorTokens.textTertiary)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Circle()
                        .fill(V2CompassModeDisplay.dotColor(for: s.mode))
                        .frame(width: 6, height: 6)
                    Text(V2CompassModeDisplay.label(for: s.mode).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                if let topic = s.topic, !topic.isEmpty {
                    Text("· \(topic)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            if let q = s.firstUserMessage, !q.isEmpty {
                Text("\u{201C}\(q)\u{201D}")
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
            }

            if let a = s.lastAssistantMessage, !a.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2192}")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(a)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 6) {
                Text("\(s.messageCount ?? 0) messages")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                if let mins = durationMinutes(start: V2CompassDate.parse(s.startedAt), end: V2CompassDate.parse(s.endedAt)), mins > 0 {
                    Text("·")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(mins) min")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Theme.cardRadius, style: .continuous)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )
    }

    private func emptyState(icon: String, title: String, hint: String?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(title)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            if let hint = hint {
                Text(hint)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(V2Theme.pad)
    }

    // MARK: helpers

    private func headerLine(for s: V2CompassSession) -> String {
        guard let started = V2CompassDate.parse(s.startedAt) else { return "" }
        let day = relativeDay(started)
        let time = Self.timeFormatter.string(from: started)
        return "\(day) · \(time)"
    }

    nonisolated(unsafe) private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func durationMinutes(start: Date?, end: Date?) -> Int? {
        guard let start = start, let end = end else { return nil }
        let secs = max(0, end.timeIntervalSince(start))
        return Int(secs / 60.0)
    }
}

// MARK: - Transcript sheet

struct V2CompassSessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: V2CompassSession
    @State private var vm: V2CompassSessionDetailViewModel
    @State private var didLoad = false

    init(session: V2CompassSession) {
        self.session = session
        self._vm = State(initialValue: V2CompassSessionDetailViewModel(sessionId: session.sessionId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Compass · \(V2CompassModeDisplay.label(for: vm.detail?.mode ?? session.mode))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .task {
                if !didLoad {
                    didLoad = true
                    await vm.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.detail == nil {
            VStack(spacing: 12) {
                ProgressView().tint(ColorTokens.gold)
                Text("Loading transcript…")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(err)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow
                        .padding(.horizontal, V2Theme.pad)
                        .padding(.top, 8)

                    ForEach((vm.detail?.messages ?? []).indices, id: \.self) { idx in
                        V2CompassTranscriptBubble(message: (vm.detail?.messages ?? [])[idx])
                            .padding(.horizontal, V2Theme.pad)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var headerRow: some View {
        let startedDate = V2CompassDate.parse(vm.detail?.startedAt ?? session.startedAt)
        let count = vm.detail?.messageCount ?? session.messageCount ?? (vm.detail?.messages?.count ?? 0)
        return HStack(spacing: 6) {
            if let started = startedDate {
                Text("Started \(Self.headerFormatter.string(from: started))")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Text("·")
                .foregroundStyle(ColorTokens.textTertiary)
            Text("\(count) messages")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    nonisolated(unsafe) private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// Ported (visual) from V2CompassView's private MessageView. Kept self-contained
/// so we don't take a dependency on a private struct.
private struct V2CompassTranscriptBubble: View {
    let message: V2CompassMessage
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 40)
                Text(message.content ?? "")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.goldLight)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorTokens.gold.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                            )
                    )
            } else {
                Text(message.content ?? "")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                            )
                    )
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}
