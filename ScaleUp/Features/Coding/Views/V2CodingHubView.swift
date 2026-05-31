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

    init(onClose: @escaping () -> Void = {}, showsCloseButton: Bool = true, initialSegment: Segment = .practice) {
        self.onClose = onClose
        self.showsCloseButton = showsCloseButton
        self._segment = State(initialValue: initialSegment)
    }

    // No internal NavigationStack — the presenter (You-tab push or Compass
    // sheet) provides it, so we never nest stacks.
    var body: some View {
        VStack(spacing: 0) {
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
