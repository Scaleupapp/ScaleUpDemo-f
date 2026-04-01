import SwiftUI

struct ContributorCardView: View {
    let userId: String
    @State private var data: ContributorCardData?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(ColorTokens.gold)
                } else if let data {
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            profileHeader(data.user)
                            statsRow(data.stats)
                            if !data.recentNotes.isEmpty {
                                notesSection(data.recentNotes)
                            }
                        }
                        .padding(Spacing.lg)
                    }
                }
            }
            .navigationTitle("Contributor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Profile Header

    private func profileHeader(_ user: ContributorUser) -> some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            if let pic = user.profilePicture, let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        avatarPlaceholder(user)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
            } else {
                avatarPlaceholder(user)
            }

            // Name + role
            VStack(spacing: 2) {
                Text(user.displayName)
                    .font(Typography.titleMedium)
                    .foregroundStyle(.white)

                Text(user.role == "creator" ? "Creator" : user.role == "contributor" ? "Contributor" : "Learner")
                    .font(Typography.caption)
                    .foregroundStyle(user.role == "creator" ? ColorTokens.gold : .orange)
            }

            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Education
            if let education = user.education, !education.isEmpty {
                VStack(spacing: 4) {
                    ForEach(education, id: \.institution) { edu in
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text("\(edu.degree ?? "") · \(edu.institution ?? "")")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Work
            if let work = user.workExperience, !work.isEmpty {
                VStack(spacing: 4) {
                    ForEach(work, id: \.company) { w in
                        HStack(spacing: 6) {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text("\(w.role ?? "") at \(w.company ?? "")")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func avatarPlaceholder(_ user: ContributorUser) -> some View {
        Circle()
            .fill(ColorTokens.surfaceElevated)
            .frame(width: 70, height: 70)
            .overlay {
                Text(String(user.firstName.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
    }

    // MARK: - Stats

    private func statsRow(_ stats: ContributorStats) -> some View {
        HStack(spacing: Spacing.md) {
            statBox(value: "\(stats.totalNotes)", label: "Notes", icon: "doc.text.fill", color: .orange)
            statBox(value: "\(stats.totalViews)", label: "Views", icon: "eye", color: ColorTokens.gold)
        }
    }

    private func statBox(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 10)).foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Notes

    private func notesSection(_ notes: [ContributorNote]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Published Notes")
                .font(Typography.bodyBold)
                .foregroundStyle(.white)

            ForEach(notes, id: \.id) { note in
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: "doc.text").font(.system(size: 14)).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).font(Typography.caption).fontWeight(.semibold).foregroundStyle(.white).lineLimit(1)
                        HStack(spacing: Spacing.xs) {
                            if let domain = note.domain { Text(domain.capitalized).font(Typography.micro).foregroundStyle(ColorTokens.textTertiary) }
                            if let views = note.viewCount, views > 0 { Text("· \(views) views").font(Typography.micro).foregroundStyle(ColorTokens.textTertiary) }
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        do {
            data = try await APIClient.shared.request(ContributorCardEndpoint(userId: userId))
        } catch {}
        isLoading = false
    }
}

// MARK: - Models

struct ContributorCardData: Codable, Sendable {
    let user: ContributorUser
    let stats: ContributorStats
    let recentNotes: [ContributorNote]
}

struct ContributorUser: Codable, Sendable {
    let id: String
    let firstName: String
    let lastName: String?
    let username: String?
    let profilePicture: String?
    let bio: String?
    let role: String?
    let education: [ContributorEducation]?
    let workExperience: [ContributorWork]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, username, profilePicture, bio, role, education, workExperience
    }

    var displayName: String {
        if let last = lastName, !last.isEmpty { return "\(firstName) \(last)" }
        return firstName
    }
}

struct ContributorEducation: Codable, Sendable {
    let degree: String?
    let institution: String?
}

struct ContributorWork: Codable, Sendable {
    let role: String?
    let company: String?
}

struct ContributorStats: Codable, Sendable {
    let totalNotes: Int
    let totalViews: Int
}

struct ContributorNote: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let domain: String?
    let pageCount: Int?
    let viewCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, domain, pageCount, viewCount
    }
}

private struct ContributorCardEndpoint: Endpoint {
    let userId: String
    var path: String { "/users/\(userId)/contributor-card" }
    var method: HTTPMethod { .get }
}
