import SwiftUI

/// V2 Quiz Home — destination for the "Quiz me" Compass chip.
///
/// Shows the user's quiz library: pending quizzes (generated but not taken),
/// a history list with scores, and an entry point to generate a new one via
/// Compass. Replaces the previous transient one-shot config card.
struct V2QuizHomeView: View {
    let onClose: () -> Void
    let onGenerateNew: () -> Void

    @State private var pending: [Quiz] = []
    @State private var history: [QuizAttempt] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var presentedQuizId: String?

    private let service = QuizService()

    private struct IdentifiedString: Identifiable {
        let value: String
        var id: String { value }
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
        }
        .task { await load() }
        .sheet(item: Binding(
            get: { presentedQuizId.map(IdentifiedString.init) },
            set: { presentedQuizId = $0?.value }
        )) { wrap in
            PlanTaskQuizLoaderSheet(quizId: wrap.value, onDismiss: { presentedQuizId = nil })
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.title.isEmpty ? q.topic.capitalized : q.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineLimit(1)
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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(historyTitle(a))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                            Text(historyMeta(a))
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        Spacer()
                        Text(scoreString(a))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(scoreColor(a))
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                    }
                }
            }
        }
    }

    private var generateNewButton: some View {
        Button {
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onGenerateNew()
            }
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
            Text("Generate one to start practising — Compass tunes it to your weakest topic.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        async let pendingTask = (try? await service.fetchPendingQuizzes()) ?? []
        async let historyTask = (try? await service.fetchQuizHistory()) ?? []
        let (p, h) = await (pendingTask, historyTask)
        pending = p
        history = h
        isLoading = false
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
