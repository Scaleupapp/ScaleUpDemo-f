import SwiftUI

/// Interview Program screen (agentic layer #4, flag `interview_coach`).
/// Mirrors the approved mockup: create form when GET returns null, program
/// view when active (target header, week strip, per-dimension trends,
/// tonight's focus card, abandon). Entry point is a card on
/// V2InterviewHomeView.
///
/// `onStartInterview` routes into the EXISTING InterviewSetupView flow —
/// callers pass the same closure V2InterviewHomeView uses for its own
/// "Start a new interview" button (which V2CompassView wires to
/// `taskRouter.open(taskType: "interview", ...)`), so this screen doesn't
/// need its own InterviewViewModel or router access.
struct InterviewProgramView: View {
    let onClose: () -> Void
    let onStartInterview: () -> Void

    private enum LoadState {
        case loading
        /// 404 — `interview_coach` flag off, surfaced while the sheet was
        /// already open. Degrade quietly rather than showing an error screen.
        case unavailable
        /// Any OTHER error (401/500/network) — a real regression. Unlike
        /// `.unavailable`, this is visible and recoverable via Retry.
        case error
        case noProgram
        case active(InterviewProgram)
    }

    @State private var loadState: LoadState = .loading
    @State private var isSubmittingCreate = false
    @State private var createError: String?
    @State private var isAbandoning = false
    @State private var showAbandonConfirm = false

    // Create-form fields
    @State private var targetRole = ""
    @State private var targetCompany = ""
    @State private var hasDriveDate = false
    @State private var driveDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var weeks = 4

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .loading:
                    ProgressView().tint(ColorTokens.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable:
                    unavailableState
                case .error:
                    errorState
                case .noProgram:
                    createForm
                case .active(let program):
                    programView(program)
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Interview program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Load

    private func load() async {
        loadState = .loading
        do {
            if let program = try await InterviewProgramService.fetch() {
                loadState = .active(program)
            } else {
                loadState = .noProgram
            }
        } catch V2APIError.httpError(404, _) {
            loadState = .unavailable
        } catch {
            trackAgenticAPIError(error, endpoint: "/interview-program")
            loadState = .error
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Text("This isn't available right now.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
            Button("Close", action: onClose)
                .font(V2Theme.small.weight(.semibold))
                .foregroundStyle(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        ErrorStateView(
            message: "Couldn't load your interview program. Check your connection and try again.",
            retryLabel: "Try Again",
            onRetry: { Task { await load() } }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create form

    private var createForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start an interview program")
                        .font(V2Theme.h2)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("A multi-week coach that tracks your mock-interview dimensions and tells you what to work on tonight.")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                labeledField("Target role", required: true) {
                    TextField("e.g. SDE-1", text: $targetRole)
                        .textFieldStyle(.plain)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .tint(ColorTokens.gold)
                }
                labeledField("Target company", required: false) {
                    TextField("Optional", text: $targetCompany)
                        .textFieldStyle(.plain)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .tint(ColorTokens.gold)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $hasDriveDate.animation()) {
                        Text("Drive date").font(V2Theme.small.weight(.semibold)).foregroundStyle(ColorTokens.textPrimary)
                    }
                    .tint(ColorTokens.gold)
                    if hasDriveDate {
                        DatePicker("", selection: $driveDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(ColorTokens.gold)
                    }
                }
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Program length").font(V2Theme.small.weight(.semibold)).foregroundStyle(ColorTokens.textPrimary)
                    Stepper("\(weeks) week\(weeks == 1 ? "" : "s")", value: $weeks, in: 1...12)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .tint(ColorTokens.gold)
                }
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                if let createError {
                    Text(createError).font(V2Theme.small).foregroundStyle(ColorTokens.error)
                }

                PrimaryButton(
                    title: "Start program",
                    isLoading: isSubmittingCreate,
                    isDisabled: targetRole.trimmingCharacters(in: .whitespaces).isEmpty || isSubmittingCreate
                ) {
                    Task { await submitCreate() }
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(_ label: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label).font(V2Theme.tiny).foregroundStyle(ColorTokens.textTertiary)
                if required { Text("*").font(V2Theme.tiny).foregroundStyle(ColorTokens.gold) }
            }
            content()
                .padding(Spacing.md)
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    private func submitCreate() async {
        createError = nil
        isSubmittingCreate = true
        defer { isSubmittingCreate = false }
        do {
            let program = try await InterviewProgramService.create(
                targetRole: targetRole.trimmingCharacters(in: .whitespaces),
                targetCompany: targetCompany.trimmingCharacters(in: .whitespaces).isEmpty ? nil : targetCompany,
                driveDate: hasDriveDate ? driveDate : nil,
                weeks: weeks
            )
            loadState = .active(program)
        } catch V2APIError.httpError(let status, _) where status == 409 {
            // Someone already has an active program (race) — reload to show it.
            await load()
        } catch {
            createError = "Couldn't start your program — try again."
        }
    }

    // MARK: - Program view

    private func programView(_ program: InterviewProgram) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                targetHeader(program)
                weekStripView(program.weekStrip)
                if !program.trends.isEmpty { trendsSection(program.trends) }
                focusCard(program)
                if !program.suggestion.isEmpty {
                    Text(program.suggestion)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Text("\(program.sessionsCompleted) session\(program.sessionsCompleted == 1 ? "" : "s") logged")
                    .font(V2Theme.tiny)
                    .foregroundStyle(ColorTokens.textTertiary)

                abandonButton

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
        .refreshable { await load() }
        .confirmationDialog(
            "Abandon this program?",
            isPresented: $showAbandonConfirm,
            titleVisibility: .visible
        ) {
            Button("Abandon", role: .destructive) { Task { await abandon() } }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("You'll lose your week strip and dimension trends. You can start a new program any time.")
        }
    }

    private func targetHeader(_ program: InterviewProgram) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR TARGET").v2Eyebrow()
            Text(program.target.role ?? "Interview program")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            HStack(spacing: 8) {
                if let company = program.target.company, !company.isEmpty {
                    Text(company).font(V2Theme.small).foregroundStyle(ColorTokens.textSecondary)
                }
                if let dateStr = InterviewProgramFormat.date(program.target.driveDate) {
                    Text("\u{00B7} Drive date \(dateStr)").font(V2Theme.small).foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    private func weekStripView(_ strip: InterviewProgramWeekStrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week \(strip.current) of \(strip.total)")
                .font(V2Theme.small.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            HStack(spacing: 4) {
                ForEach(1...max(strip.total, 1), id: \.self) { week in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(week <= strip.current ? ColorTokens.gold : ColorTokens.surfaceElevated)
                        .frame(height: 6)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func trendsSection(_ trends: [InterviewProgramDimensionTrend]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIMENSION TRENDS").v2Eyebrow()
            VStack(spacing: 10) {
                ForEach(trends) { trend in trendRow(trend) }
            }
        }
    }

    private func trendRow(_ trend: InterviewProgramDimensionTrend) -> some View {
        let latest = trend.scores.last ?? 0
        let clamped = max(0, min(latest, 100))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(InterviewProgramFormat.dimensionLabel(trend.dimension))
                    .font(V2Theme.small.weight(.medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text("\(Int(latest.rounded()))")
                    .font(V2Theme.small.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                if let delta = trend.delta, delta != 0 {
                    Text(delta > 0 ? "\u{2191}\(Int(delta.rounded()))" : "\u{2193}\(Int(abs(delta).rounded()))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(delta > 0 ? ColorTokens.success : ColorTokens.error)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(ColorTokens.surfaceElevated)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTokens.gold)
                        .frame(width: geo.size.width * CGFloat(clamped / 100))
                }
            }
            .frame(height: 6)
        }
    }

    private func focusCard(_ program: InterviewProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(focusTitle(program.focus))
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.gold)
            Text(program.focus.reason)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
            Button(action: onStartInterview) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1))
    }

    private func focusTitle(_ focus: InterviewProgramFocus) -> String {
        if let dim = focus.dimension, !dim.isEmpty {
            return "Tonight \u{00B7} \(InterviewProgramFormat.dimensionLabel(dim))"
        }
        return "Tonight"
    }

    private var abandonButton: some View {
        Button {
            showAbandonConfirm = true
        } label: {
            Text("Abandon program")
                .font(V2Theme.small.weight(.semibold))
                .foregroundStyle(ColorTokens.error)
        }
        .buttonStyle(.plain)
        .disabled(isAbandoning)
    }

    private func abandon() async {
        isAbandoning = true
        defer { isAbandoning = false }
        _ = try? await InterviewProgramService.abandon()
        // Idempotent either way — after abandon there's no active program.
        loadState = .noProgram
    }
}
