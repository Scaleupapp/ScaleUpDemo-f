import SwiftUI

struct NoteRequestDetailView: View {
    let request: NoteRequest

    @Environment(AppState.self) private var appState
    @State private var upvoteCount: Int
    @State private var isUpvoted: Bool
    @State private var isUpvoting = false
    @State private var isClaiming = false
    @State private var showFulfillSheet = false
    @State private var showCreateNotes = false

    private let service = NoteRequestService()

    init(request: NoteRequest) {
        self.request = request
        _upvoteCount = State(initialValue: request.upvoteCount)
        _isUpvoted = State(initialValue: request.isUpvotedByMe ?? false)
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerCard
                    detailsCard
                    actionsSection
                    fulfilledSection
                    Spacer().frame(height: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationTitle("Request Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateNotes) {
            CreateNotesView()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Title
            Text(request.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            // Description
            if let desc = request.description, !desc.isEmpty {
                Text(desc)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // Domain + Difficulty + Status
            HStack(spacing: Spacing.sm) {
                Text(request.domain.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(Capsule())

                if let difficulty = request.difficulty {
                    Text(difficulty.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.info)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.info.opacity(0.12))
                        .clipShape(Capsule())
                }

                statusBadge(request.status)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: Spacing.md) {
            // Requester
            if let user = request.requestedBy {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Requested by")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(user.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }

            // Time
            if !request.timeAgo.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(request.timeAgo)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Spacer()
                }
            }

            // College
            if let college = request.collegeName, !college.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text(college)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                }
            }

            // Topics
            if let topics = request.topics, !topics.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "tag")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.textTertiary)
                    ForEach(topics, id: \.self) { topic in
                        Text(topic)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTokens.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Spacing.md) {
            // Upvote button
            Button {
                Task { await toggleUpvote() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isUpvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 20))
                    Text("\(upvoteCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(isUpvoted ? "Upvoted" : "Upvote")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(isUpvoted ? ColorTokens.gold : ColorTokens.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isUpvoted ? ColorTokens.gold.opacity(0.12) : ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUpvoted ? ColorTokens.gold.opacity(0.3) : ColorTokens.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isUpvoting)

            // Contributor actions
            if request.status == "open" && isCreatorOrAdmin {
                Button {
                    Task { await claimRequest() }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 16))
                        Text(isClaiming ? "Claiming..." : "Claim This Request")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.info)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isClaiming)
            }

            if request.status == "in_progress" && isCreatorOrAdmin {
                PrimaryButton(title: "Fulfill — Upload Notes", icon: "doc.fill.badge.plus") {
                    showCreateNotes = true
                }
            }
        }
    }

    // MARK: - Fulfilled Section

    @ViewBuilder
    private var fulfilledSection: some View {
        if request.status == "fulfilled", let content = request.fulfilledContentId {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Fulfilled Notes")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)

                NavigationLink {
                    NotesDetailView(contentId: content._id)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.gold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(content.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let domain = content.domain {
                                Text(domain.capitalized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .padding(Spacing.md)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if let user = request.fulfilledBy {
                    Text("Fulfilled by \(user.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(Spacing.lg)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

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

    private var isCreatorOrAdmin: Bool {
        let role = appState.currentUser?.role
        return role == .creator || role == .admin
    }

    // MARK: - Actions

    private func toggleUpvote() async {
        isUpvoting = true
        Haptics.light()
        do {
            let resp = try await service.toggleUpvote(id: request.id)
            isUpvoted = resp.upvoted
            upvoteCount = resp.upvoteCount
        } catch {
            // Silently fail
        }
        isUpvoting = false
    }

    private func claimRequest() async {
        isClaiming = true
        Haptics.medium()
        do {
            try await service.claimRequest(id: request.id)
            Haptics.success()
        } catch {
            Haptics.error()
        }
        isClaiming = false
    }
}
