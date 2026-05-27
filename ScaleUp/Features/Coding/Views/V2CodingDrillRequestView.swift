import SwiftUI

/// Shown when the user taps the "💻 Start a coding drill" chip from Compass.
/// Mirrors the V2QuizHomeView pattern: brief intro, picker, Start button,
/// loading overlay + error alert, then opens DrillModalView via sheet(item:).
struct V2CodingDrillRequestView: View {
    let onClose: () -> Void

    @State private var selectedSubtype: DrillSubtype? = nil
    @State private var selectedDifficulty: DrillDifficulty? = nil
    @State private var isRequesting = false
    @State private var requestedSession: DrillSession? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    pickerSection(label: "Drill type") {
                        HStack(spacing: 8) {
                            subtypeChip(nil, label: "Auto", icon: "sparkles")
                            subtypeChip(.prompt, label: "Prompt", icon: "text.bubble")
                            subtypeChip(.verify, label: "Bug Hunt", icon: "magnifyingglass")
                            subtypeChip(.decompose, label: "Decompose", icon: "list.number")
                        }
                    }

                    pickerSection(label: "Difficulty") {
                        HStack(spacing: 8) {
                            difficultyChip(nil, label: "Auto")
                            difficultyChip(.easy, label: "Easy")
                            difficultyChip(.medium, label: "Medium")
                            difficultyChip(.hard, label: "Hard")
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .navigationTitle("Coding drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }
        }
        .sheet(item: $requestedSession) { session in
            DrillModalView(preloadedSession: session)
                .onDisappear { onClose() }  // close Compass sheet too when drill closes
        }
        .alert("Couldn't start drill", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if isRequesting {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Finding a drill for you…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Subviews

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Coding practice")
                    .font(.title3.weight(.semibold))
            }
            Text("Bite-sized practice on the meta-skills companies actually test for — prompting, bug hunting, decomposition.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func pickerSection<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.subheadline.weight(.semibold))
            content()
        }
    }

    private func subtypeChip(_ value: DrillSubtype?, label: String, icon: String) -> some View {
        let isSelected = selectedSubtype == value
        return Button { selectedSubtype = value } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func difficultyChip(_ value: DrillDifficulty?, label: String) -> some View {
        let isSelected = selectedDifficulty == value
        return Button { selectedDifficulty = value } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            Task { await performRequest() }
        } label: {
            Text("Start drill")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
    }

    // MARK: - Logic

    private func performRequest() async {
        isRequesting = true
        defer { isRequesting = false }

        do {
            let body = DrillRequestBody(
                drillSubtype: selectedSubtype,
                difficulty: selectedDifficulty,
                topicHint: nil
            )
            let resp = try await DrillService.shared.requestDrill(body: body)
            let session = DrillSession(
                preloadedDrill: resp.toTodayResponse(),
                preloadedAttemptId: resp.attemptId
            )
            requestedSession = session
            AnalyticsService.shared.track(.codingExtraDrillRequested(source: "compass"))
        } catch {
            errorMessage = humanError(error)
        }
    }

    private func humanError(_ error: Error) -> String {
        if let svc = error as? DrillServiceError {
            switch svc {
            case .calibrationRequired:
                return "Take the 6-minute calibration first so we can pitch drills at your level."
            case .dailyQuotaUsed(let nextAt):
                if let date = nextAt {
                    let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
                    return "You've already done today's drill — next one unlocks \(f.localizedString(for: date, relativeTo: Date()))."
                }
                return "You've already done today's drill — come back tomorrow."
            case .noDrillAvailable:
                return "We're out of fresh drills for this combination — try another type or difficulty."
            case .invalidResponse:
                return "Got an unexpected response from the server. Try again in a moment."
            }
        }
        if case V2APIError.httpError(let status, let data) = error {
            if status == 404, let body = try? JSONDecoder().decode([String: String].self, from: data) {
                switch body["error"] {
                case "no_coding_track_for_objective":
                    return "Coding practice isn't available for your current objective."
                case "no_drill_available":
                    return "We're out of fresh drills for this combination — try another type or difficulty."
                case "calibration_required":
                    return "Take the 6-minute calibration first so we can pitch drills at your level."
                case "daily_quota_used":
                    return "You've already done today's drill — come back tomorrow."
                default: break
                }
            }
            return "Server returned \(status). Try again in a moment."
        }
        return error.localizedDescription
    }
}

#Preview {
    V2CodingDrillRequestView(onClose: {})
        .preferredColorScheme(.dark)
}
