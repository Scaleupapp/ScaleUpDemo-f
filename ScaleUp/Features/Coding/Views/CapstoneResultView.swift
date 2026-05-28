import SwiftUI

/// Capstone result screen (spec §8.2): 6-dim rubric, strengths, gaps,
/// interview parallel, integrity confidence. Polls /result until graded
/// when entering in non-graded state.
struct CapstoneResultView: View {
    let sessionId: String
    let onClose: () -> Void

    @State private var state: ViewState = .loading
    @State private var pollTask: Task<Void, Never>?
    @State private var showReplay = false
    @State private var showVoiceReflection = false

    enum ViewState {
        case loading
        case pending(CapstoneSessionStatus)
        case graded(CapstoneResult)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            content
                .padding(20)
                .navigationTitle("Capstone result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { onClose() }
                    }
                }
                .onAppear { startPolling() }
                .onDisappear { pollTask?.cancel() }
                .sheet(isPresented: $showReplay) {
                    CapstoneReplayView(sessionId: sessionId)
                }
                .sheet(isPresented: $showVoiceReflection) {
                    CapstoneVoiceReflectionView(sessionId: sessionId) {
                        showVoiceReflection = false
                        startPolling() // re-fetch in case re-score lands
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pending(let s):
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2)
                Text(s.displayLabel).font(.headline)
                Text("We'll push a notification when it's ready. Usually 3–10 minutes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .graded(let result):
            graded(result)
        case .error(let msg):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                Text("Couldn't load result").font(.headline)
                Text(msg).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func graded(_ result: CapstoneResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreCard(result)
                rubricSection(result.dimensionScores)
                strengthsGapsSection(result)
                integritySection(result)
                if let parallel = result.interviewParallel, !parallel.isEmpty {
                    interviewParallel(parallel)
                }
                actionButtons(result)
                Spacer(minLength: 60)
            }
        }
    }

    private func scoreCard(_ result: CapstoneResult) -> some View {
        VStack(spacing: 4) {
            Text("Overall")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(result.overallScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                Text("/ 100").font(.title3).foregroundStyle(.secondary)
            }
            verdict(for: result.overallScore)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func verdict(for s: Int) -> some View {
        let (text, color): (String, Color) = {
            switch s {
            case 85...:   return ("Excellent work", .green)
            case 70..<85: return ("Solid attempt", .blue)
            case 50..<70: return ("Getting there", .orange)
            default:      return ("Room to grow", .red)
            }
        }()
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(color)
    }

    private func rubricSection(_ dims: CapstoneDimensionScores) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How you did").font(.headline)
            VStack(spacing: 14) {
                RubricBar(dimension: "correctness", score: dims.correctness, feedback: nil)
                RubricBar(dimension: "code quality", score: dims.codeQuality, feedback: nil)
                RubricBar(dimension: "ai pair effectiveness", score: dims.aiPairEffectiveness, feedback: nil)
                RubricBar(dimension: "verification discipline", score: dims.verificationDiscipline, feedback: nil)
                RubricBar(dimension: "decomposition", score: dims.decomposition, feedback: nil)
                RubricBar(dimension: "reflection quality", score: dims.reflectionQuality, feedback: nil)
            }
        }
        .padding(16).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func strengthsGapsSection(_ result: CapstoneResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.strengths.isEmpty {
                Text("Strengths").font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.strengths, id: \.self) { s in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(s).font(.subheadline)
                        }
                    }
                }
            }
            if !result.gaps.isEmpty {
                Text("Gaps").font(.subheadline.weight(.semibold)).padding(.top, 6)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.gaps, id: \.self) { g in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.orange)
                            Text(g).font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(16).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func integritySection(_ result: CapstoneResult) -> some View {
        let (label, color): (String, Color) = {
            switch result.integrityConfidence {
            case "high":   return ("High integrity confidence", .green)
            case "medium": return ("Medium integrity confidence", .orange)
            default:       return ("Low integrity confidence", .red)
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium))
                if result.anchorDriftDetected == true {
                    Text("Flagged for human review — your score may update.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func interviewParallel(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "briefcase.fill").foregroundStyle(.tint).padding(.top, 2)
            Text(text).font(.subheadline)
        }
        .padding(14).background(Color.accentColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func actionButtons(_ result: CapstoneResult) -> some View {
        VStack(spacing: 10) {
            Button {
                showVoiceReflection = true
            } label: {
                Label("Record 60-sec reflection", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                showReplay = true
            } label: {
                Label("Watch replay", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func startPolling() {
        pollTask?.cancel()
        state = .loading
        pollTask = Task {
            for _ in 0..<240 { // ~20 min worst case
                if Task.isCancelled { return }
                do {
                    let r = try await CapstoneService.shared.pollResult(sessionId: sessionId)
                    switch r {
                    case .graded(let g):
                        await MainActor.run { state = .graded(g) }
                        return
                    case .pending(let s):
                        await MainActor.run { state = .pending(s) }
                    }
                } catch {
                    await MainActor.run { state = .error("Couldn't load. Pull to refresh later.") }
                    return
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}
