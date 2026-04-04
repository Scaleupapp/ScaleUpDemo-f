import SwiftUI

struct InterviewHistoryView: View {
    @State private var sessions: [InterviewSessionSummary] = []
    @State private var isLoading = true
    @State private var showNewInterview = false
    @State private var error: String?

    private let service = InterviewService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading && sessions.isEmpty {
                loadingView
            } else if sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .navigationTitle("Interview History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewInterview = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .fullScreenCover(isPresented: $showNewInterview) {
            InterviewSessionView(viewModel: InterviewViewModel())
        }
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink {
                    InterviewResultsDetailView(sessionId: session.id)
                } label: {
                    sessionRow(session)
                }
                .listRowBackground(ColorTokens.surface)
                .listRowSeparatorTint(ColorTokens.divider)
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: InterviewSessionSummary) -> some View {
        HStack(spacing: Spacing.md) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(session.interviewType.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: session.interviewType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(session.interviewType.color)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.interviewType.displayName)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(ColorTokens.textPrimary)

                if let role = session.targetRole, !role.isEmpty {
                    Text(role)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(session.difficulty.displayName)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if !session.durationString.isEmpty {
                        Text(session.durationString)
                            .font(Typography.micro)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Text(session.timeAgo)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Spacer()

            // Score or status badge
            sessionBadge(session)
        }
        .padding(.vertical, 4)
    }

    private func sessionBadge(_ session: InterviewSessionSummary) -> some View {
        Group {
            if let score = session.overallScore, session.status == .evaluated {
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreBadgeColor(score))
                    .frame(width: 44, height: 44)
                    .background(scoreBadgeColor(score).opacity(0.15))
                    .clipShape(Circle())
            } else {
                Text(statusLabel(session.status))
                    .font(Typography.micro)
                    .foregroundStyle(statusColor(session.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(session.status).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private func scoreBadgeColor(_ score: Int) -> Color {
        if score >= 70 { return ColorTokens.success }
        if score >= 40 { return ColorTokens.warning }
        return ColorTokens.error
    }

    private func statusLabel(_ status: InterviewStatus) -> String {
        switch status {
        case .setup: return "Setup"
        case .in_progress: return "In Progress"
        case .completed: return "Completed"
        case .evaluating: return "Evaluating..."
        case .evaluated: return "Evaluated"
        case .abandoned: return "Abandoned"
        }
    }

    private func statusColor(_ status: InterviewStatus) -> Color {
        switch status {
        case .evaluated: return ColorTokens.success
        case .evaluating, .in_progress: return ColorTokens.info
        case .abandoned: return ColorTokens.textTertiary
        default: return ColorTokens.warning
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text("No Interviews Yet")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Practice with an AI interviewer to sharpen\nyour skills and get detailed feedback")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Haptics.medium()
                showNewInterview = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Start Your First Interview")
                        .font(Typography.bodyBold)
                }
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 14)
                .background(ColorTokens.gold)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.sm)

            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(ColorTokens.gold)
            Text("Loading interviews...")
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Data

    private func loadSessions() async {
        isLoading = true
        do {
            sessions = try await service.listSessions()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteSessions(at offsets: IndexSet) {
        let toDelete = offsets.map { sessions[$0] }
        sessions.remove(atOffsets: offsets)

        for session in toDelete {
            Task {
                try? await service.deleteSession(sessionId: session.id)
            }
        }
    }
}

// MARK: - Detail View Wrapper (loads full session)

struct InterviewResultsDetailView: View {
    let sessionId: String
    @State private var viewModel = InterviewViewModel()

    var body: some View {
        InterviewResultsView(viewModel: viewModel)
            .task {
                await viewModel.loadSession(sessionId)
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}
