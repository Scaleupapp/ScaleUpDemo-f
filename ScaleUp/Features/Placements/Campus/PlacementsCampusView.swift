import SwiftUI

/// Campus tab — company drives, TPO notices, and the placement calendar.
struct PlacementsCampusView: View {
    @Environment(AppState.self) private var appState

    @State private var drives: [PlacementDrive] = []
    @State private var notices: [PlacementNotice] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var noticesError: String?

    private let api = PlacementsCampusApi.shared

    private var institutionName: String {
        appState.userContext?.placement?.institution.name ?? "your college"
    }

    private var unreadCount: Int {
        notices.filter { !$0.read }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Campus").v2Eyebrow()
                    Text("Drives & notices")
                        .font(V2Theme.h1)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                .padding(.top, 8)

                // MARK: - Company Drives
                VStack(alignment: .leading, spacing: 12) {
                    SectionEyebrow("Company drives")

                    if isLoading && drives.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView().tint(ColorTokens.gold)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if let loadError {
                        Text(loadError)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.vertical, 8)
                    } else if drives.isEmpty {
                        PlacementEmptyState(
                            icon: "calendar.badge.clock",
                            title: "",
                            message: "No drives yet — recruiters your TPO adds for this season show up here."
                        )
                    } else {
                        ForEach(drives) { drive in
                            DriveRowCard(drive: drive) { id, shouldBookmark in
                                await toggleBookmark(id: id, shouldBookmark: shouldBookmark)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - TPO Notices
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 6) {
                        SectionEyebrow("TPO notices")
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(V2Theme.tiny)
                                .foregroundStyle(ColorTokens.buttonPrimaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorTokens.gold)
                                .clipShape(Capsule())
                        }
                    }

                    if let noticesError {
                        Text(noticesError)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.vertical, 8)
                    } else if notices.isEmpty && !isLoading {
                        PlacementEmptyState(
                            icon: "megaphone.fill",
                            title: "",
                            message: "No notices yet — your placement office will post updates here."
                        )
                    } else {
                        ForEach(notices) { notice in
                            NoticeRowCard(notice: notice) { id in
                                await markRead(id: id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        noticesError = nil
        async let drivesResult = api.fetchCompanies()
        async let noticesResult = api.fetchNotices()
        do {
            drives = try await drivesResult
        } catch {
            loadError = "Could not load drives. Pull to refresh."
        }
        do {
            notices = try await noticesResult
        } catch {
            noticesError = "Could not load notices."
        }
        isLoading = false
    }

    private func markRead(id: String) async {
        guard let idx = notices.firstIndex(where: { $0.id == id }) else { return }
        guard !notices[idx].read else { return }
        // Optimistically flip local state
        let old = notices[idx]
        notices[idx] = PlacementNotice(
            id: old.id, title: old.title, body: old.body,
            pinned: old.pinned, link: old.link, attachment: old.attachment, read: true
        )
        do {
            try await api.markNoticeRead(id)
        } catch {
            // Revert on failure (best-effort; non-critical)
            if let revertIdx = notices.firstIndex(where: { $0.id == id }) {
                notices[revertIdx] = old
            }
        }
    }

    /// Optimistic bookmark toggle: flip local state immediately, revert on error.
    private func toggleBookmark(id: String, shouldBookmark: Bool) async {
        guard let idx = drives.firstIndex(where: { $0.id == id }) else { return }
        let old = drives[idx]
        drives[idx] = old.withBookmarked(shouldBookmark)
        do {
            if shouldBookmark {
                try await api.bookmarkDrive(id)
            } else {
                try await api.unbookmarkDrive(id)
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

// MARK: - Notice Row Card

private struct NoticeRowCard: View {
    let notice: PlacementNotice
    let onTap: (String) async -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            Task {
                await onTap(notice.id)
                // Open link or attachment after marking read
                if let linkStr = notice.link, !linkStr.isEmpty, let url = URL(string: linkStr) {
                    openURL(url)
                } else if let attURL = notice.attachment?.url, !attURL.isEmpty, let url = URL(string: attURL) {
                    openURL(url)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 0) {
                // Subtle gold left accent for pinned notices.
                if notice.pinned {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(ColorTokens.gold.opacity(0.7))
                        .frame(width: 3)
                        .padding(.trailing, 13)
                }

                HStack(alignment: .top, spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ColorTokens.gold)
                            .frame(width: 38, height: 38)
                            .background(ColorTokens.gold.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        if !notice.read {
                            Circle()
                                .fill(ColorTokens.gold)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(notice.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if notice.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ColorTokens.gold)
                            }
                        }

                        Text(notice.body)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let linkStr = notice.link, !linkStr.isEmpty {
                            metaLink(icon: "link", text: "Open link")
                        } else if let att = notice.attachment, let fileName = att.fileName, !fileName.isEmpty {
                            metaLink(icon: "paperclip", text: fileName)
                        }
                    }
                }
            }
            .placementCard()
        }
        .buttonStyle(.plain)
    }

    private func metaLink(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(V2Theme.small)
                .lineLimit(1)
        }
        .foregroundStyle(ColorTokens.gold)
    }
}

// MARK: - Drive Row Card

private struct DriveRowCard: View {
    let drive: PlacementDrive
    /// (id, shouldBookmark) — parent performs the optimistic toggle.
    let onBookmark: (String, Bool) async -> Void

    @Environment(\.openURL) private var openURL

    private var isBookmarked: Bool { drive.bookmarked ?? false }

    private var countdownDays: Int? {
        guard let days = PlacementDate.daysUntil(drive.driveDate), days > 0 else { return nil }
        return days
    }

    var body: some View {
        let content = HStack(alignment: .top, spacing: 14) {
            MonogramChip(text: drive.name)

            VStack(alignment: .leading, spacing: 6) {
                // Name + status pill
                HStack(alignment: .center, spacing: 8) {
                    Text(drive.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    StatusPill(status: drive.status)
                }

                // Hero line: role · package (package gold/bold)
                heroLine

                // Meta row: calendar + date, then eligibility
                if let dateStr = drive.driveDate, !dateStr.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(formattedDate(dateStr))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(ColorTokens.textSecondary)
                        if let days = countdownDays {
                            countdownChip(days: days)
                        }
                    }
                }

                if let eligibility = drive.eligibility, !eligibility.isEmpty {
                    Text(eligibility)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if drive.applyLink != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .medium))
                        Text("Apply")
                            .font(V2Theme.small)
                    }
                    .foregroundStyle(ColorTokens.gold)
                }
            }

            // Bookmark star
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

        if let linkStr = drive.applyLink, let url = URL(string: linkStr) {
            Button {
                openURL(url)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var heroLine: some View {
        let role = (drive.role ?? "").isEmpty ? nil : drive.role
        let pkg = (drive.package ?? "").isEmpty ? nil : drive.package
        if role != nil || pkg != nil {
            HStack(spacing: 0) {
                if let role {
                    Text(role)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                if role != nil, pkg != nil {
                    Text("  ·  ")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if let pkg {
                    Text(pkg)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func countdownChip(days: Int) -> some View {
        Text(days == 1 ? "in 1 day" : "in \(days) days")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(ColorTokens.gold.opacity(0.15))
            .clipShape(Capsule())
    }

    private func formattedDate(_ iso: String) -> String {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        if let date = withFrac.date(from: iso) ?? plain.date(from: iso) {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            return fmt.string(from: date)
        }
        return iso
    }
}

// MARK: - Shared Placeholder Card

/// Shared "coming soon" card for the placement shells.
struct PlacementsPlaceholderCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 34, height: 34)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(message)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .v2Card()
    }
}
