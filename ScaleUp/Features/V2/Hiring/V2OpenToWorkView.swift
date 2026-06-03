import SwiftUI

/// "Open to work" — the candidate opt-in screen for Hire from ScaleUp.
///
/// Ports the mockup's opt-in phone frame into the app's native dark V2 theme:
///   • a "Show me to employers" toggle (on → opt-in, off → opt-out),
///   • the mandatory ✓/✕ trust explainer (verbatim copy),
///   • editable recruiter details (city, notice period, work preference) saved
///     via opt-in (idempotent upsert — there is no PATCH),
///   • a friendly NOT_ELIGIBLE / NO_SNAPSHOT / NO_OBJECTIVE state,
///   • a link into the connection inbox.
///
/// The view is reached from the self-gated You-tab row, so it only ever appears
/// when the feature is available; it still re-loads on appear to stay fresh.
struct V2OpenToWorkView: View {
    @State private var vm: V2HiringViewModel
    @Environment(AppState.self) private var appState

    // Editable recruiter fields (seeded from the loaded profile).
    @State private var city: String = ""
    @State private var noticePeriod: String = ""
    @State private var workPref: String = "any"
    @State private var didSeed = false

    /// Pass in a shared view model from the You tab so opt-in state and the inbox
    /// badge stay in sync after the user makes changes here.
    init(viewModel: V2HiringViewModel = V2HiringViewModel()) {
        _vm = State(initialValue: viewModel)
    }

    private let workPrefs: [(value: String, label: String)] = [
        ("onsite", "Onsite"),
        ("remote", "Remote"),
        ("hybrid", "Hybrid"),
        ("any", "Any")
    ]

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    toggleCard
                    explainerCard
                    if vm.ineligibleReason != nil {
                        ineligibleCard
                    }
                    if vm.optedIn {
                        recruiterDetailsSection
                    }
                    inboxLink
                    if let error = vm.error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    controlNote
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 18)
            }
        }
        .navigationTitle("Open to work")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // The You tab usually pre-loads; re-load to be safe + seed the form.
            if vm.available == nil { await vm.load() }
            seedFields()
        }
        .refreshable {
            await vm.load()
            seedFields(force: true)
        }
    }

    // MARK: - Toggle

    private var toggleCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Show me to employers")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(discoverableSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .tint(ColorTokens.success)
                .disabled(vm.loading)
        }
        .v2Card()
    }

    private var discoverableSubtitle: String {
        if vm.optedIn, let role = vm.roleLabel, !role.isEmpty {
            return "Discoverable as \(role)"
        }
        return "Let vetted employers discover your readiness"
    }

    /// On → opt-in (which may surface an ineligibility reason), off → opt-out.
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { vm.optedIn },
            set: { newValue in
                Haptics.selection()
                Task {
                    if newValue {
                        await vm.optIn(city: nil, noticePeriod: nil, workPref: nil)
                    } else {
                        await vm.optOut()
                    }
                    seedFields(force: true)
                }
            }
        )
    }

    // MARK: - Trust explainer (mandatory verbatim copy)

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            explainerRow(
                symbol: "checkmark",
                color: ColorTokens.success,
                leadIn: "They see",
                rest: " your readiness, skills & evidence — and why you rank."
            )
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
                .padding(.vertical, 2)
            explainerRow(
                symbol: "xmark",
                color: ColorTokens.textTertiary,
                leadIn: "They never see",
                rest: " your name, photo, phone or email until you approve a connection."
            )
        }
        .v2Card()
    }

    private func explainerRow(symbol: String, color: Color, leadIn: String, rest: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .padding(.top, 1)
            (Text(leadIn).font(.system(size: 13, weight: .semibold)).foregroundStyle(ColorTokens.textPrimary)
             + Text(rest).font(.system(size: 13)).foregroundStyle(ColorTokens.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Ineligible state

    private var ineligibleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.warning)
                Text("NOT READY YET")
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(ColorTokens.warning)
            }
            Text(vm.ineligibleReason ?? "Take an assessment on a career goal to join the talent pool.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorTokens.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(ColorTokens.warning.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Recruiter details (editable; saved via opt-in)

    private var recruiterDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECRUITER DETAILS")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(ColorTokens.gold)

            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("City")
                TextField("e.g. Bangalore", text: $city)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surfaceElevated))

                fieldLabel("Notice period")
                TextField("e.g. 30 days", text: $noticePeriod)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surfaceElevated))

                fieldLabel("Work preference")
                Picker("Work preference", selection: $workPref) {
                    ForEach(workPrefs, id: \.value) { pref in
                        Text(pref.label).tag(pref.value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(V2Theme.cardBorder, lineWidth: 1))

            Button {
                Haptics.light()
                Task {
                    await vm.optIn(city: city, noticePeriod: noticePeriod, workPref: workPref)
                    seedFields(force: true)
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.loading { ProgressView().tint(.black).scaleEffect(0.8) }
                    Text(vm.loading ? "Saving…" : "Save details")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.buttonPrimaryText)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(vm.loading)
        }
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ColorTokens.textSecondary)
    }

    // MARK: - Inbox link

    private var inboxLink: some View {
        NavigationLink {
            V2ConnectionInboxView(viewModel: vm)
                .environment(appState)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 32, height: 32)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interested employers")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(vm.pendingCount > 0
                         ? "\(vm.pendingCount) waiting for your response"
                         : "Approve or decline incoming interest")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                if vm.pendingCount > 0 {
                    Text("\(vm.pendingCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.buttonPrimaryText)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(ColorTokens.gold)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(14)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(V2Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer note

    private var controlNote: some View {
        Text("Turn off anytime — you vanish from search instantly.")
            .font(.system(size: 11))
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - Seeding

    /// Copy the server-side profile into the editable fields. Called after every
    /// load/save so the form reflects server truth; the initial `.task` only
    /// seeds once (guarded by `didSeed`) so it doesn't clobber in-progress typing
    /// on a re-appear, while explicit save/refresh paths always re-seed.
    private func seedFields(force: Bool = false) {
        guard force || !didSeed else { return }
        if let p = vm.profile {
            city = p.city ?? ""
            noticePeriod = p.noticePeriod ?? ""
            workPref = p.workPref ?? "any"
        }
        didSeed = true
    }
}

#Preview { NavigationStack { V2OpenToWorkView() }.preferredColorScheme(.dark) }
