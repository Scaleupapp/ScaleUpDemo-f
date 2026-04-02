import SwiftUI

struct NoteRequestsListView: View {
    @State private var requests: [NoteRequest] = []
    @State private var isLoading = true
    @State private var sortMode: SortMode = .recent
    @State private var showCreateSheet = false
    @State private var selectedRequest: NoteRequest?

    private let service = NoteRequestService()

    enum SortMode: String, CaseIterable {
        case recent = "recent"
        case upvotes = "upvotes"

        var label: String {
            switch self {
            case .recent: return "Recent"
            case .upvotes: return "Most Upvoted"
            }
        }
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading && requests.isEmpty {
                ProgressView().tint(ColorTokens.gold)
            } else if requests.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        sortPicker
                        requestsList
                        Spacer().frame(height: Spacing.xxxl)
                    }
                }
            }
        }
        .navigationTitle("Note Requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.light()
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateNoteRequestSheet { _ in
                Task { await loadRequests() }
            }
        }
        .onChange(of: showCreateSheet) { _, showing in
            if !showing { Task { await loadRequests() } }
        }
        .navigationDestination(item: $selectedRequest) { request in
            NoteRequestDetailView(request: request)
        }
        .task { await loadRequests() }
        .onAppear {
            if !requests.isEmpty { Task { await loadRequests() } }
        }
        .refreshable { await loadRequests() }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(SortMode.allCases, id: \.self) { mode in
                Button {
                    Haptics.selection()
                    sortMode = mode
                    Task { await loadRequests() }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(sortMode == mode ? .white : ColorTokens.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(sortMode == mode ? ColorTokens.gold : ColorTokens.surface)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Requests List

    private var requestsList: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(requests) { request in
                Button {
                    selectedRequest = request
                } label: {
                    requestRow(request)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Request Row

    private func requestRow(_ request: NoteRequest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text(request.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Domain + Status
            HStack(spacing: Spacing.sm) {
                Text(request.domain.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())

                statusBadge(request.status)

                Spacer()
            }

            // Footer: upvote + requester + time
            HStack(spacing: Spacing.md) {
                // Upvote
                HStack(spacing: 4) {
                    Image(systemName: request.isUpvotedByMe == true ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(request.isUpvotedByMe == true ? ColorTokens.gold : ColorTokens.textTertiary)
                    Text("\(request.upvoteCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(request.isUpvotedByMe == true ? ColorTokens.gold : ColorTokens.textTertiary)
                }

                if let user = request.requestedBy?.user {
                    Text(user.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(request.timeAgo)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: String) -> some View {
        let (label, color) = statusInfo(status)
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "open": return ("Open", ColorTokens.success)
        case "in_progress": return ("In Progress", ColorTokens.info)
        case "fulfilled": return ("Fulfilled", ColorTokens.gold)
        case "closed": return ("Closed", ColorTokens.textTertiary)
        default: return (status.capitalized, ColorTokens.textTertiary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary)

            Text("No note requests yet")
                .font(Typography.titleMedium)
                .foregroundStyle(.white)

            Text("Be the first to request notes on a topic!")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Request Notes", icon: "plus") {
                showCreateSheet = true
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Load

    private func loadRequests() async {
        isLoading = true
        requests = (try? await service.fetchRequests(sort: sortMode.rawValue)) ?? []
        isLoading = false
    }
}

// MARK: - Hashable conformance for navigation

extension NoteRequest: Hashable {
    static func == (lhs: NoteRequest, rhs: NoteRequest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
