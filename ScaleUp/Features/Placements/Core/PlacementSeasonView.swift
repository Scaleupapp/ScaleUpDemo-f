import SwiftUI

/// Step 2 of the placement first-login hook — orients the student in their
/// placement season: the season window (if the backend has one), how many
/// cohort-mates are preparing, and the next few company drives (reusing the
/// existing student drives API + bookmark). Primary "Continue" advances to the
/// 2-minute win; "Skip for now" finishes onboarding straight to Home.
struct PlacementSeasonView: View {
    @Environment(AppState.self) private var appState

    @State private var payload: PlacementOnboardingPayload?
    @State private var drives: [PlacementDrive] = []
    @State private var isLoadingDrives = true
    @State private var isFinishing = false

    private let campusApi = PlacementsCampusApi.shared

    /// Top upcoming drives — drop closed ones, sort earliest-date first, cap at 3.
    private var upcomingDrives: [PlacementDrive] {
        drives
            .filter { $0.status.lowercased() != "closed" && $0.status.lowercased() != "visited" }
            .sorted { lhs, rhs in
                switch (PlacementDate.parse(lhs.driveDate), PlacementDate.parse(rhs.driveDate)) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return false
                }
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            content
        }
        .task { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: Spacing.xl)

                Text("STEP 2 OF 3").v2Eyebrow()
                    .padding(.bottom, Spacing.sm)

                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                    Image(systemName: "calendar")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ColorTokens.background)
                }
                .padding(.bottom, Spacing.lg)

                Text(seasonTitle)
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Here's what's ahead this season. You'll build readiness with practice and the assessments your college schedules.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                seasonCard
                    .padding(.top, Spacing.xl)

                drivesSection
                    .padding(.top, Spacing.xl)

                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var seasonTitle: String {
        // Season name is currently always null server-side — render it only
        // when present, otherwise a clean generic title.
        if let name = payload?.seasonName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "Your placement season"
    }

    // MARK: - Season card (window + cohort size)

    @ViewBuilder
    private var seasonCard: some View {
        let window = seasonWindowText
        let count = payload?.cohortStudentCount
        if window != nil || count != nil {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let window {
                    infoRow(icon: "calendar.badge.clock", label: "Season window", value: window)
                    if count != nil { Divider().overlay(ColorTokens.divider) }
                }
                if let count {
                    infoRow(
                        icon: "person.3.fill",
                        label: "You're not alone",
                        value: "\(count) student\(count == 1 ? "" : "s") from your college are preparing here"
                    )
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(ColorTokens.gold.opacity(0.18), lineWidth: 1)
            )
        }
    }

    /// "1 Dec 2026 – 28 Feb 2027" when both bounds exist; a single bound is
    /// rendered on its own. nil when the backend has no season window.
    private var seasonWindowText: String? {
        let start = PlacementDate.medium(payload?.seasonStartsAt)
        let end = PlacementDate.medium(payload?.seasonEndsAt)
        switch (start, end) {
        case let (s?, e?): return "\(s) – \(e)"
        case let (s?, nil): return "From \(s)"
        case let (nil, e?): return "Through \(e)"
        case (nil, nil):    return nil
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(ColorTokens.gold.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                Text(value)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Drives

    @ViewBuilder
    private var drivesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionEyebrow("Upcoming drives")

            if isLoadingDrives && drives.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            } else if upcomingDrives.isEmpty {
                PlacementEmptyState(
                    icon: "calendar.badge.clock",
                    title: "",
                    message: "No drives yet — recruiters your college adds for this season will show up here and in Campus."
                )
            } else {
                ForEach(upcomingDrives) { drive in
                    SeasonDriveRow(drive: drive) { id, shouldBookmark in
                        await toggleBookmark(id: id, shouldBookmark: shouldBookmark)
                    }
                }
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Continue", icon: "arrow.right", isLoading: isFinishing) {
                Haptics.light()
                appState.proceedFromPlacementSeason()
            }
            Button {
                guard !isFinishing else { return }
                skip()
            } label: {
                Text("Skip for now")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
            .disabled(isFinishing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.md)
        .background(ColorTokens.background)
    }

    // MARK: - Actions

    private func skip() {
        isFinishing = true
        Task { await appState.finishPlacementOnboarding() }
    }

    private func load() async {
        async let payloadResult = PlacementOnboardingApi.shared.fetch()
        async let drivesResult = fetchDrives()
        payload = await payloadResult
        drives = await drivesResult
        isLoadingDrives = false
    }

    private func fetchDrives() async -> [PlacementDrive] {
        (try? await campusApi.fetchCompanies()) ?? []
    }

    /// Optimistic bookmark toggle — flip local state immediately, revert on error.
    private func toggleBookmark(id: String, shouldBookmark: Bool) async {
        guard let idx = drives.firstIndex(where: { $0.id == id }) else { return }
        let old = drives[idx]
        drives[idx] = old.withBookmarked(shouldBookmark)
        do {
            if shouldBookmark {
                try await campusApi.bookmarkDrive(id)
            } else {
                try await campusApi.unbookmarkDrive(id)
            }
        } catch {
            if let revertIdx = drives.firstIndex(where: { $0.id == id }) {
                drives[revertIdx] = old
            }
        }
    }
}

// MARK: - PlacementDrive bookmark helper

private extension PlacementDrive {
    func withBookmarked(_ value: Bool) -> PlacementDrive {
        PlacementDrive(
            id: id, name: name, role: role, package: package,
            driveDate: driveDate, eligibility: eligibility, status: status,
            applyLink: applyLink, notes: notes, bookmarked: value
        )
    }
}

// MARK: - Compact drive row (season screen)

/// A lean drive row for the onboarding season screen. Reuses the shared
/// `MonogramChip` / `StatusPill` / `placementCard()` primitives and the same
/// bookmark affordance as Campus, without the full apply/notes chrome.
private struct SeasonDriveRow: View {
    let drive: PlacementDrive
    let onBookmark: (String, Bool) async -> Void

    private var isBookmarked: Bool { drive.bookmarked ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MonogramChip(text: drive.name)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(drive.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    StatusPill(status: drive.status)
                }

                if let role = drive.role, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                if let date = PlacementDate.medium(drive.driveDate) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(date)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }

            Button {
                Task { await onBookmark(drive.id, !isBookmarked) }
            } label: {
                Image(systemName: isBookmarked ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isBookmarked ? ColorTokens.gold : ColorTokens.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .placementCard()
    }
}
