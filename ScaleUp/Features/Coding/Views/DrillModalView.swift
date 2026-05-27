import SwiftUI

struct DrillModalView: View {
    @State private var session = DrillSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
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
                    ToolbarItem(placement: .principal) {
                        // Show live timer when in input state; otherwise show text title
                        if case .input = session.state,
                           let drill = session.todayDrill,
                           let startedAt = session.startedAt {
                            DrillTimerBadge(
                                startedAt: startedAt,
                                totalSeconds: drill.timeBudgetMinutes * 60
                            )
                        } else {
                            Text(navTitle)
                                .font(.headline)
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
        if let drill = session.todayDrill, let startedAt = session.startedAt {
            let ctx = DrillContext(from: drill)
            switch drill.drillSubtype {
            case .prompt:
                PromptDrillInputView(
                    context: ctx,
                    startedAt: startedAt,
                    submitLabel: "Submit for grading",
                    onSubmit: { sub in Task { await session.submit(sub) } }
                )
            case .verify:
                VerifyDrillInputView(
                    context: ctx,
                    startedAt: startedAt,
                    submitLabel: "Submit for grading",
                    onSubmit: { sub in Task { await session.submit(sub) } }
                )
            case .decompose:
                DecomposeDrillInputView(
                    context: ctx,
                    startedAt: startedAt,
                    submitLabel: "Submit for grading",
                    onSubmit: { sub in Task { await session.submit(sub) } }
                )
            case .refactor:
                placeholderView(
                    systemImage: "questionmark.circle",
                    title: "Unsupported drill type",
                    subtitle: "Refactor drills are filtered server-side in Phase A."
                )
            }
        } else {
            // Defensive: state is .input but session data isn't ready yet
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
