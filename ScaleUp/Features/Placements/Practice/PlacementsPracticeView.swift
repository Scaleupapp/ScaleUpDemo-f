import SwiftUI

/// Practice hub for placement students.
///
/// Practice is entirely private — it never starts an institution AssessmentSession
/// and is never visible to the TPO.  Engine launches reuse the same deep-launch
/// mechanism the Compass FAB uses:
///   quiz  → V2TaskRouter.route = .quizByTopic(topic:, weekNumber: nil)
///   drill → V2TaskRouter.route = .codingDrill(subtype: nil)
///   interview → V2TaskRouter.route = .interview(scenarioId: nil)
///   capstone → presented as a sheet directly (no Route case exists for it)
struct PlacementsPracticeView: View {
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(\.dismiss) private var dismiss

    @State private var practice: PlacementPractice?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showCapstone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacyNote
                    if isLoading && practice == nil {
                        ProgressView().tint(ColorTokens.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let err = loadError {
                        errorView(err)
                    } else if let practice {
                        if practice.hasAssessment && !practice.recommendations.isEmpty {
                            recommendedSection(practice.recommendations)
                        }
                        practiceAnyTimeSection(practice.types)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
        // Capstone has no V2TaskRouter.Route — present V2CodingHubView directly
        // as a sheet, matching what Compass does in V2CompassView.
        .sheet(isPresented: $showCapstone) {
            NavigationStack {
                V2CodingHubView(onClose: { showCapstone = false }, initialSegment: .capstones)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("Practice is private — it won't affect your scores or be shown to your college.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ColorTokens.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Recommended section

    @ViewBuilder
    private func recommendedSection(_ recs: [PracticeRec]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECOMMENDED FOR YOU").v2Eyebrow()
            VStack(spacing: 8) {
                ForEach(recs) { rec in
                    recommendedCard(rec)
                }
            }
        }
    }

    private func recommendedCard(_ rec: PracticeRec) -> some View {
        Button {
            launch(key: "quiz", topic: rec.topic)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.competency)
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(rec.reason)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(rec.score)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(Double(rec.score)))
                    Text("Practice quiz →")
                        .font(V2Theme.tiny)
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .padding(14)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Practice any time section

    @ViewBuilder
    private func practiceAnyTimeSection(_ types: [PracticeType]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRACTICE ANY TIME").v2Eyebrow()
            VStack(spacing: 8) {
                ForEach(types) { pt in
                    practiceTypeCard(pt)
                }
            }
        }
    }

    private func practiceTypeCard(_ pt: PracticeType) -> some View {
        Button {
            launch(key: pt.key, topic: nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconFor(key: pt.key))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(pt.label)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(14)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error view

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.gold)
            Text(message)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .font(V2Theme.bodyMedium)
                .foregroundStyle(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Engine launch

    /// Dispatch the engine using the V2TaskRouter that PlacementsMainTabView injects.
    /// Capstone has no Route case so we present V2CodingHubView as a local sheet.
    private func launch(key: String, topic: String?) {
        switch key {
        case "quiz":
            let t = topic ?? ""
            if !t.isEmpty {
                taskRouter.route = .quizByTopic(topic: t, weekNumber: nil)
            } else {
                taskRouter.route = .quizByTopic(topic: "practice", weekNumber: nil)
            }
        case "drill":
            taskRouter.route = .codingDrill(subtype: nil)
        case "interview":
            taskRouter.route = .interview(scenarioId: nil)
        case "capstone":
            showCapstone = true
        default:
            break
        }
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            practice = try await PlacementsPracticeApi.shared.fetchPractice()
        } catch {
            loadError = "Couldn't load practice. Pull to refresh."
        }
        isLoading = false
    }

    private func iconFor(key: String) -> String {
        switch key {
        case "quiz":      return "bolt.fill"
        case "drill":     return "chevron.left.forwardslash.chevron.right"
        case "capstone":  return "laptopcomputer"
        case "interview": return "mic.fill"
        default:          return "play.fill"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 85...: return ColorTokens.success
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return ColorTokens.error
        }
    }
}
