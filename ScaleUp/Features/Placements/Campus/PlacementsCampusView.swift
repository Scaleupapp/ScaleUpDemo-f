import SwiftUI

/// Campus tab — company drives, TPO notices, and the placement calendar.
struct PlacementsCampusView: View {
    @Environment(AppState.self) private var appState

    @State private var drives: [PlacementDrive] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private let api = PlacementsCampusApi.shared

    private var institutionName: String {
        appState.userContext?.placement?.institution.name ?? "your college"
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Company drives").v2Eyebrow()

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
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ColorTokens.gold)
                                .frame(width: 34, height: 34)
                                .background(ColorTokens.gold.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No drives yet — your TPO will add recruiters here.")
                                    .font(V2Theme.body)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .v2Card()
                    } else {
                        ForEach(drives) { drive in
                            DriveRowCard(drive: drive)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - TPO Notices (placeholder — Phase 3)
                PlacementsPlaceholderCard(
                    icon: "megaphone.fill",
                    title: "TPO notices",
                    message: "Announcements from your placement office will appear here so you never miss a deadline."
                )
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
        do {
            drives = try await api.fetchCompanies()
        } catch {
            loadError = "Could not load drives. Pull to refresh."
        }
        isLoading = false
    }
}

// MARK: - Drive Row Card

private struct DriveRowCard: View {
    let drive: PlacementDrive
    @Environment(\.openURL) private var openURL

    var body: some View {
        let content = HStack(alignment: .top, spacing: 14) {
            Image(systemName: "building.2")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 34, height: 34)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                // Name + status pill
                HStack(alignment: .center, spacing: 8) {
                    Text(drive.name)
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer(minLength: 0)
                    DriveStatusPill(status: drive.status)
                }

                // Role / package subtitle
                if let role = drive.role, let pkg = drive.package, !role.isEmpty, !pkg.isEmpty {
                    Text("\(role) · \(pkg)")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                } else if let role = drive.role, !role.isEmpty {
                    Text(role)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                } else if let pkg = drive.package, !pkg.isEmpty {
                    Text(pkg)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                // Drive date
                if let dateStr = drive.driveDate, !dateStr.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(formattedDate(dateStr))
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                // Eligibility
                if let eligibility = drive.eligibility, !eligibility.isEmpty {
                    Text(eligibility)
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Apply link indicator
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
        }
        .v2Card()

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

    private func formattedDate(_ iso: String) -> String {
        // Try ISO8601 with fractional seconds first, then plain
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        if let date = withFrac.date(from: iso) ?? plain.date(from: iso) {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            return fmt.string(from: date)
        }
        // Fallback: return raw string
        return iso
    }
}

// MARK: - Drive Status Pill

private struct DriveStatusPill: View {
    let status: String

    private var pillColor: Color {
        switch status {
        case "open":    return ColorTokens.success
        case "closed":  return ColorTokens.error
        case "visited": return ColorTokens.textTertiary
        default:        return ColorTokens.gold   // "upcoming"
        }
    }

    private var label: String {
        status.prefix(1).uppercased() + status.dropFirst()
    }

    var body: some View {
        Text(label)
            .font(V2Theme.tiny)
            .foregroundStyle(pillColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(pillColor.opacity(0.15))
            .clipShape(Capsule())
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
