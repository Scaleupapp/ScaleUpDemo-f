import SwiftUI

struct DrillModalView: View {
    @State private var session = DrillSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
        }
        .task {
            if case .loading = session.state {
                await session.loadToday()
            }
        }
        .onChange(of: session.state) { _, newState in
            guard let drill = session.todayDrill else { return }
            switch newState {
            case .input:
                DrillAnalytics.trackStarted(drill: drill)
            case .result(let grade):
                DrillAnalytics.trackResultViewed(drill: drill, score: grade.overallScore)
            default:
                break
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .loading:
            loadingView
        case .brief:
            if let drill = session.todayDrill {
                DrillBriefView(drill: drill) {
                    Task { await session.start() }
                }
            }
        case .input:
            inputView
        case .submitting:
            DrillSubmittingView()
        case .result(let grade):
            DrillResultView(grade: grade) {
                dismiss()
            }
        case .error(let msg):
            placeholderView(systemImage: "exclamationmark.triangle", title: "Something went wrong", subtitle: msg)
        case .calibrationRequired:
            placeholderView(systemImage: "sparkles", title: "Calibrate first", subtitle: "Take the 6-min calibration to start daily drills. (Calibration view lands in UI-B7.)")
        case .noDrillAvailable:
            placeholderView(systemImage: "tray", title: "No drill available", subtitle: "We don't have a drill for your role-track and difficulty yet. Check back soon.")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading today's drill…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var inputView: some View {
        switch session.todayDrill?.drillSubtype {
        case .prompt:
            PromptDrillInputView(session: session)
        case .verify:
            VerifyDrillInputView(session: session)
        case .decompose:
            DecomposeDrillInputView(session: session)
        case .refactor, .none:
            // Refactor is filtered server-side in Phase A; .none shouldn't happen
            placeholderView(
                systemImage: "questionmark.circle",
                title: "Unsupported drill type",
                subtitle: "This shouldn't happen — refactor drills are filtered server-side."
            )
        }
    }

    private func placeholderView(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var navTitle: String {
        switch session.state {
        case .brief:      return "Today's Drill"
        case .input:      return drillTypeTitle
        case .submitting: return "Grading"
        case .result:     return "Drill Result"
        default:          return ""
        }
    }

    private var drillTypeTitle: String {
        session.todayDrill?.drillSubtype.displayName ?? "Drill"
    }
}

#Preview("Brief") {
    DrillModalView()
}
