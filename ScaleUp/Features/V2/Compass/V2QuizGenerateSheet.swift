import SwiftUI

/// Inline quiz generation flow — surfaced from V2 Quiz Home so the user can
/// configure and launch a quiz without leaving the screen (the previous flow
/// kicked them out to the Compass conversation).
///
/// Phases:
///   1. config — pick topic, question count, assessment type
///   2. building — call /quizzes/request, poll trigger status until ready
///   3. ready — push QuizSessionView for the generated quiz
struct V2QuizGenerateSheet: View {
    let onClose: () -> Void

    /// Suggestions surfaced as topic chips. Caller passes weakest-area + recent
    /// topics so the user has a sensible default to tap.
    let suggestedTopics: [String]
    let defaultTopic: String?

    @State private var topic: String = ""
    @State private var questionCount: Int = 10
    @State private var assessmentType: AssessmentType = .mixed
    /// Default on — most users want their practice to count toward their goal.
    /// Off = "for fun" quiz that won't update objective progress.
    @State private var countTowardObjective: Bool = true
    @State private var phase: Phase = .config
    @State private var statusText: String = "Pulling in what you've been learning…"
    @State private var quiz: Quiz?
    @State private var errorMessage: String?

    private let quizService = QuizService()

    private enum Phase {
        case config
        case building
        case ready
        case failed
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .config:    configBody
                case .building:  buildingBody
                case .ready:
                    if let quiz {
                        QuizSessionView(quiz: quiz)
                    } else {
                        buildingBody
                    }
                case .failed:    failedBody
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(phase == .ready ? "Done" : "Close") { onClose() }
                }
            }
        }
        .onAppear {
            if topic.isEmpty, let d = defaultTopic, !d.isEmpty {
                topic = d
            }
        }
    }

    private var navTitle: String {
        switch phase {
        case .config:   return "Generate a quiz"
        case .building: return "Building your quiz…"
        case .ready:    return "Your quiz"
        case .failed:   return "Couldn't build"
        }
    }

    // MARK: - Config body

    private var configBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                topicSection
                countSection
                assessmentSection
                objectiveToggleSection
                generateButton
                    .padding(.top, 8)
                Spacer().frame(height: 30)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOPIC").v2Eyebrow()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
                TextField("e.g. dynamic programming", text: $topic)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .submitLabel(.done)
                if !topic.isEmpty {
                    Button { topic = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))

            if !suggestedTopics.isEmpty {
                Text("From your recent activity")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedTopics, id: \.self) { suggestion in
                            Button {
                                topic = suggestion
                            } label: {
                                Text(prettyTopic(suggestion))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ColorTokens.gold)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(ColorTokens.gold.opacity(0.10)))
                                    .overlay(Capsule().strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var countSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUESTIONS").v2Eyebrow()
            HStack(spacing: 8) {
                ForEach([5, 10, 15], id: \.self) { n in
                    Button {
                        questionCount = n
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(n)")
                                .font(.system(size: 16, weight: .bold))
                            Text(estimateLabel(for: n))
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(questionCount == n ? ColorTokens.background : ColorTokens.textPrimary)
                        .background(questionCount == n ? ColorTokens.gold : ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(questionCount == n ? Color.clear : V2Theme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var assessmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STYLE").v2Eyebrow()
            VStack(spacing: 8) {
                ForEach(AssessmentType.allCases, id: \.rawValue) { t in
                    Button {
                        assessmentType = t
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: t.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(assessmentType == t ? ColorTokens.gold : ColorTokens.textSecondary)
                                .frame(width: 30, height: 30)
                                .background((assessmentType == t ? ColorTokens.gold : ColorTokens.textSecondary).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Text(t.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if assessmentType == t {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ColorTokens.gold)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(assessmentType == t ? ColorTokens.gold.opacity(0.4) : V2Theme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var objectiveToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COUNT TOWARD YOUR GOAL?").v2Eyebrow()
            Toggle(isOn: $countTowardObjective) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(countTowardObjective ? "Yes — track this against your objective" : "No — just for fun")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(countTowardObjective
                         ? "Score updates your readiness and competency mastery."
                         : "Won't affect your objective progress or readiness score.")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ColorTokens.gold))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Generate quiz →")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canGenerate ? ColorTokens.gold : ColorTokens.gold.opacity(0.35))
            .foregroundStyle(ColorTokens.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
    }

    private var canGenerate: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Building body

    private var buildingBody: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.4).tint(ColorTokens.gold)
            Text("Building your quiz on \(prettyTopic(topic))")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(statusText)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var failedBody: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38))
                .foregroundStyle(ColorTokens.warning)
            Text("Couldn't build this quiz")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(errorMessage ?? "Try again in a moment.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                phase = .config
                errorMessage = nil
            } label: {
                Text("Back")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.surface)
                    .foregroundStyle(ColorTokens.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Network

    private func generate() async {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTopic.isEmpty else { return }
        phase = .building
        statusText = "Pulling in your recent gaps + misconceptions…"

        do {
            let trigger = try await quizService.requestQuiz(
                topic: cleanTopic,
                questionCount: questionCount,
                assessmentType: assessmentType == .mixed ? nil : assessmentType.rawValue,
                noObjective: !countTowardObjective
            )
            var quizId = trigger.quizId

            if quizId == nil, let triggerId = trigger.triggerId {
                statusText = "Writing your questions — usually takes 30 seconds."
                for i in 0..<30 {
                    try? await Task.sleep(for: .seconds(2))
                    if i == 6 { statusText = "Hand-picking distractors from your past mistakes…" }
                    if i == 14 { statusText = "Tuning difficulty to your level…" }
                    let status = try await quizService.checkTriggerStatus(triggerId: triggerId)
                    if let qid = status.quizId {
                        quizId = qid
                        break
                    }
                    if status.status == "failed" {
                        errorMessage = "We couldn't build a quiz for this topic. Try a slightly different topic."
                        phase = .failed
                        return
                    }
                }
            }
            guard let qid = quizId else {
                errorMessage = "This is taking longer than expected. Try again in a moment."
                phase = .failed
                return
            }
            let fetched = try await quizService.fetchQuiz(id: qid)
            quiz = fetched
            phase = .ready
        } catch {
            errorMessage = "Couldn't reach the quiz service. Check your connection."
            phase = .failed
        }
    }

    // MARK: - Helpers

    private func estimateLabel(for count: Int) -> String {
        switch count {
        case 5:  return "~4 min"
        case 10: return "~8 min"
        case 15: return "~12 min"
        default: return ""
        }
    }

    private func prettyTopic(_ canonical: String) -> String {
        canonical
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
