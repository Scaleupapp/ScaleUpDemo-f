import SwiftUI

struct ApplicationStatusView: View {
    let application: CreatorApplication

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    statusHeader
                    applicationDetails
                    endorsementsSection
                    if application.status == .rejected {
                        rejectionInfo
                    }
                }
                .padding(Spacing.md)
            }
        }
        .navigationTitle("Application Status")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: application.status.icon)
                .font(.system(size: 48))
                .foregroundStyle(application.status.color)

            Text(application.status.displayName)
                .font(Typography.titleLarge)
                .foregroundStyle(application.status.color)

            Text(statusMessage)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(application.status.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var statusMessage: String {
        if let detail = application.statusDetail, !detail.isEmpty {
            return detail
        }
        switch application.status {
        case .pending:
            return "Your application is being reviewed by creators in your domain."
        case .endorsed:
            let count = application.endorsements?.count ?? 0
            return "You have \(count) endorsement\(count == 1 ? "" : "s"). Need more for approval."
        case .approved:
            return "Congratulations! You've been approved as a Rising creator."
        case .rejected:
            return "Your application was not approved at this time."
        }
    }

    // MARK: - Application Details

    private var applicationDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Application Details")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            detailRow(label: "Domain", value: application.domain.capitalized)

            if let specs = application.specializations, !specs.isEmpty {
                detailRow(label: "Specializations", value: specs.joined(separator: ", "))
            }

            if let exp = application.experience, !exp.isEmpty {
                detailRow(label: "Experience", value: exp)
            }

            if let mot = application.motivation, !mot.isEmpty {
                detailRow(label: "Motivation", value: mot)
            }

            if let date = application.createdAt {
                let formatter = DateFormatter()
                let _ = formatter.dateStyle = .medium
                detailRow(label: "Submitted", value: formatter.string(from: date))
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Endorsements

    private var endorsementsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Endorsements")
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)

            if let endorsements = application.endorsements, !endorsements.isEmpty {
                ForEach(endorsements) { endorsement in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(ColorTokens.info)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(endorsement.endorserName ?? "Creator")
                                .font(Typography.bodySmall)
                                .foregroundStyle(ColorTokens.textPrimary)
                            if let note = endorsement.note, !note.isEmpty {
                                Text(note)
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ColorTokens.success)
                    }
                    .padding(Spacing.sm)
                    .background(ColorTokens.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }
            } else {
                Text("No endorsements yet")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Rejection Info

    private var rejectionInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.error)
                Text("Rejection Details")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            if let note = application.rejectionNote, !note.isEmpty {
                Text(note)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            if let reapplyDate = application.reapplyAfter {
                let formatter = DateFormatter()
                let _ = formatter.dateStyle = .medium
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("You can reapply after \(formatter.string(from: reapplyDate))")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(ColorTokens.error.opacity(0.3), lineWidth: 1)
        )
    }
}
