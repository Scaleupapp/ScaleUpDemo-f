import SwiftUI

/// V2 Quiz Home — destination for the "Quiz me" Compass chip.
///
/// Shows the user's quiz library: pending quizzes (generated but not taken),
/// a history list with scores, and an entry point to generate a new one via
/// Compass. Replaces the previous transient one-shot config card.
struct V2QuizHomeView: View {
    let onClose: () -> Void
    /// Kept for back-compat with the Compass-driven flow. The inline
    /// generate sheet is the primary path now.
    var onGenerateNew: (() -> Void)? = nil

    @State private var pending: [Quiz] = []
    @State private var history: [QuizAttempt] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var presentedQuizId: String?
    @State private var presentedResultsAttempt: QuizAttempt?
    @State private var showGenerateSheet = false
    /// Topic suggestions for the generate sheet — top gap + recently quizzed topics.
    @State private var suggestedTopics: [String] = []
    @State private var defaultTopic: String?

    private let service = QuizService()

    private struct IdentifiedString: Identifiable {
        let value: String
        var id: String { value }
    }

    /// Decode shape for /quizzes/ensure-daily — fields are best-effort, we
    /// don't actually do anything with them on the client (the pending list
    /// reloads after the call completes).
    private struct V2EnsureDailyResponse: Codable {
        let queued: Int?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading && pending.isEmpty && history.isEmpty {
                        ProgressView().tint(ColorTokens.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else {
                        intro
                        if !pending.isEmpty { pendingSection }
                        if !history.isEmpty { historySection }
                        if pending.isEmpty && history.isEmpty { emptyState }
                        generateNewButton
                        Spacer().frame(height: 40)
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Your Quizzes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
            .refreshable { await load() }
            .navigationDestination(item: $presentedResultsAttempt) { attempt in
                if let quizId = attempt.quizId?.id {
                    QuizResultsView(quizId: quizId, attempt: attempt)
                } else {
                    Text("Results unavailable")
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .task { await load() }
        .sheet(item: Binding(
            get: { presentedQuizId.map(IdentifiedString.init) },
            set: { presentedQuizId = $0?.value }
        )) { wrap in
            PlanTaskQuizLoaderSheet(quizId: wrap.value, onDismiss: { presentedQuizId = nil })
        }
        .sheet(isPresented: $showGenerateSheet) {
            V2QuizGenerateSheet(
                onClose: {
                    showGenerateSheet = false
                    Task { await load() }
                },
                suggestedTopics: suggestedTopics,
                defaultTopic: defaultTopic
            )
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your quiz library — pending, history, and a quick way to start a new one tuned to your gaps.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PENDING").v2Eyebrow()
            VStack(spacing: 8) {
                ForEach(pending) { q in
                    Button {
                        presentedQuizId = q.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.gold)
                                .frame(width: 32, height: 32)
                                .background(ColorTokens.gold.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(q.title.isEmpty ? q.topic.capitalized : q.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ColorTokens.textPrimary)
                                        .lineLimit(1)
                                    if let chip = q.type.sourceChip {
                                        sourceChip(chip)
                                    }
                                }
                                Text("\(q.totalQuestions) questions · \(q.topic.capitalized)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            Spacer()
                            Text("Take →")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                        }
                        .padding(12)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY").v2Eyebrow()
            VStack(spacing: 0) {
                ForEach(history.prefix(20), id: \.id) { a in
                    Button {
                        presentedResultsAttempt = a
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(historyTitle(a))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(ColorTokens.textPrimary)
                                        .lineLimit(1)
                                    if let chip = a.quizId?.type?.sourceChip {
                                        sourceChip(chip)
                                    }
                                    if a.quizId?.objectiveId == nil {
                                        sourceChip("For fun", muted: true)
                                    }
                                }
                                Text(historyMeta(a))
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            Spacer()
                            Text(scoreString(a))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(scoreColor(a))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .padding(.leading, 4)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var generateNewButton: some View {
        Button {
            showGenerateSheet = true
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Generate a new quiz")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(ColorTokens.gold)
            .foregroundStyle(ColorTokens.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🧠").font(.system(size: 28))
            Text("No quizzes yet")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Generate one to start practising — we'll tune it to your weakest topic.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    /// Tiny tag rendered next to the quiz title so the user can see WHY this
    /// quiz exists ("Daily", "Weekly review", "From your watching", etc.).
    private func sourceChip(_ text: String, muted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(muted ? ColorTokens.textTertiary : ColorTokens.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                Capsule().strokeBorder(
                    (muted ? ColorTokens.textTertiary : ColorTokens.gold).opacity(0.5),
                    lineWidth: 1
                )
            )
    }

    private func load() async {
        isLoading = true
        // Kick the "ensure today's daily quizzes exist" endpoint fire-and-forget
        // so a user who opened the app long after midnight doesn't see an empty
        // pending list. Idempotent — backend dedupes against the last 24h.
        Task.detached {
            // Fire-and-forget; we don't care about the response shape here,
            // and the pending list reload below will pick up anything queued.
            // Uses the v1 raw path because /quizzes/* is namespaced under v1.
            struct EmptyBody: Codable {}
            let _: V2EnsureDailyResponse? = try? await V2APIClient.shared.postV1(
                "/quizzes/ensure-daily", body: EmptyBody()
            )
        }
        async let pendingTask = (try? await service.fetchPendingQuizzes()) ?? []
        async let historyTask = (try? await service.fetchQuizHistory()) ?? []
        let (p, h) = await (pendingTask, historyTask)
        pending = p
        history = h
        isLoading = false

        // Derive topic suggestions for the generate sheet — top gap first,
        // then recently touched topics, then the user's declared interests,
        // all deduped and capped at 10.
        if let home = try? await V2APIClient.shared.get("/plan/today") as V2APIResponse<V2HomeData> {
            var seen = Set<String>()
            var topics: [String] = []
            if let gap = home.data.topGap?.topic, !gap.isEmpty {
                seen.insert(gap.lowercased())
                topics.append(gap)
                defaultTopic = gap
            }
            for t in (home.data.todaysTasks ?? []).compactMap({ $0.primaryTopic }) {
                let key = t.lowercased()
                if seen.insert(key).inserted { topics.append(t) }
                if topics.count >= 10 { break }
            }
            for a in h.prefix(8) {
                if let t = a.topicBreakdown?.first?.topic, !t.isEmpty {
                    let key = t.lowercased()
                    if seen.insert(key).inserted { topics.append(t) }
                }
                if topics.count >= 10 { break }
            }

            // Also surface the user's declared topicsOfInterest — they added
            // these at onboarding, so seeing them in the chip suggestions is
            // what they expect. Fetch the active primary objective from /objectives.
            if let objectives: [UserObjective] = try? await V2APIClient.shared.getV1("/objectives") {
                let active = objectives.first(where: { $0.isPrimary == true && $0.status == .active })
                    ?? objectives.first(where: { $0.status == .active })
                for topic in (active?.topicsOfInterest ?? []) {
                    let key = topic.lowercased()
                    if seen.insert(key).inserted { topics.append(topic) }
                    if topics.count >= 10 { break }
                }
            }

            suggestedTopics = topics
        }
    }

    private func historyTitle(_ a: QuizAttempt) -> String {
        if let topic = a.topicBreakdown?.first?.topic, !topic.isEmpty {
            return topic.capitalized
        }
        return "Quiz"
    }

    private func historyMeta(_ a: QuizAttempt) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        let date = a.completedAt.map { f.string(from: $0) } ?? "—"
        let total = a.score?.total ?? 0
        return "\(date) · \(total) questions"
    }

    private func scoreString(_ a: QuizAttempt) -> String {
        if let pct = a.score?.percentage {
            return "\(Int(pct.rounded()))%"
        }
        return "—"
    }

    private func scoreColor(_ a: QuizAttempt) -> Color {
        guard let pct = a.score?.percentage else { return ColorTokens.textTertiary }
        if pct < 50 { return ColorTokens.warning }
        if pct >= 70 { return ColorTokens.success }
        return ColorTokens.textPrimary
    }
}
