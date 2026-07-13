import SwiftUI

/// Unified Coding home. Replaces the old split between "Coding drills & practice"
/// (You tab) and "Coding capstones" (Compass) — both were really one coding
/// product, and each showed its own mastery view, which confused learners.
///
/// One hub, three segments:
///   • Practice   — today's drill + practice-another + recent drill attempts
///   • Capstones  — your auto-track + start + generate + recent capstones
///   • Progress   — the single source of truth for per-skill mastery + stats
///
/// The segment bodies reuse the existing views via their `mode` / `embedded`
/// flags, so there is no duplicated rendering logic.
struct V2CodingHubView: View {
    /// Called by the Close button when shown as a sheet. Ignored when pushed
    /// (the navigation back button handles dismissal and Close is hidden).
    var onClose: () -> Void = {}
    /// Sheet presentation shows a Close button; pushed presentation does not.
    var showsCloseButton: Bool = true

    enum Segment: String, CaseIterable, Identifiable {
        case practice = "Practice"
        case capstones = "Capstones"
        case progress = "Progress"
        var id: String { rawValue }
    }

    @State private var segment: Segment

    /// Agentic layer #8 (flag `proof_builder`) — probed independently of
    /// the segment content so a 404 (flag off) only hides this one card.
    private enum ProofProbe {
        case loading
        case unavailable
        case none
        case active(ProofJourney)
    }
    @State private var proofProbe: ProofProbe = .loading
    @State private var showProofSheet = false

    init(onClose: @escaping () -> Void = {}, showsCloseButton: Bool = true, initialSegment: Segment = .practice) {
        self.onClose = onClose
        self.showsCloseButton = showsCloseButton
        self._segment = State(initialValue: initialSegment)
    }

    // No internal NavigationStack — the presenter (You-tab push or Compass
    // sheet) provides it, so we never nest stacks.
    var body: some View {
        VStack(spacing: 0) {
            proofEntryCard
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 10)

            Picker("Section", selection: $segment) {
                ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 10)
            .padding(.bottom, 4)

            blurb
                .padding(.horizontal, V2Theme.pad)
                .padding(.bottom, 6)

            Divider().overlay(ColorTokens.textTertiary.opacity(0.25))

            // Only the selected segment is instantiated, so only it loads.
            switch segment {
            case .practice:
                V2CodingMasteryView(mode: .practiceOnly)
            case .capstones:
                V2CodingHomeView(onClose: onClose, embedded: true)
            case .progress:
                V2CodingMasteryView(mode: .progressOnly)
            }
        }
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("Coding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
        }
        .task { await loadProofProbe() }
        .sheet(isPresented: $showProofSheet) {
            ProofJourneyView(onClose: { showProofSheet = false })
        }
    }

    /// "Prove it" / "Your proof" — agentic layer #8 entry point. Hidden
    /// entirely while loading or when the backend 404s (flag off).
    @ViewBuilder
    private var proofEntryCard: some View {
        switch proofProbe {
        case .loading, .unavailable:
            EmptyView()
        case .none:
            Button {
                showProofSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turn a JD into a proof")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Paste a job description → graded capstone → shareable proof page")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        case .active(let journey):
            Button {
                showProofSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.gold)
                        .frame(width: 32, height: 32)
                        .background(ColorTokens.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your proof")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(journey.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    Spacer()
                    Text("Open \u{2192}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(12)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func loadProofProbe() async {
        do {
            if let journey = try await ProofJourneyService.fetch() {
                proofProbe = .active(journey)
            } else {
                proofProbe = .none
            }
        } catch {
            proofProbe = .unavailable
        }
    }

    /// One line under the picker so the distinction is always explicit.
    private var blurb: some View {
        Text(blurbText)
            .font(V2Theme.tiny)
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blurbText: String {
        switch segment {
        case .practice:  return "Short daily reps that sharpen the skills capstones test."
        case .capstones: return "Real, graded projects you build on your laptop (60–90 min)."
        case .progress:  return "Your mastery across prompting, verification, decomposition & refactoring."
        }
    }
}

#Preview {
    V2CodingHubView(onClose: {})
        .preferredColorScheme(.dark)
}
