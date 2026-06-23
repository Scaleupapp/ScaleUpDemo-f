import SwiftUI

/// Campus tab — company drives, TPO notices, and the placement calendar.
///
/// Shell for this slice: the live drive/notice feeds land in a later pass once
/// the assessment + scheduling layer (Phase 2a) is wired.
struct PlacementsCampusView: View {
    @Environment(AppState.self) private var appState

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

                PlacementsPlaceholderCard(
                    icon: "calendar.badge.clock",
                    title: "Company drives",
                    message: "Upcoming recruiter drives and the placement schedule from \(institutionName) will show up here."
                )
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
    }
}

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
