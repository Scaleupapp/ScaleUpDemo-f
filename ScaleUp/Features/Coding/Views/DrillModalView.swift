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
            // Real per-subtype input views land in UI-B3 / B4 / B5
            inputPlaceholder
        case .submitting:
            placeholderView(systemImage: "hourglass", title: "Grading your answer…", subtitle: "This is a stub for UI-B2; real submit lands in UI-B6.")
        case .result:
            placeholderView(systemImage: "checkmark.seal.fill", title: "Result placeholder", subtitle: "Real result view lands in UI-B6.")
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

    private var inputPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("\(session.todayDrill?.drillSubtype.displayName ?? "Drill") input")
                .font(.headline)
            Text("Real input view lands in UI-B3 / B4 / B5.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Stub: simulate submit") {
                Task { await session.submit(.prompt(text: "stub")) }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
