import SwiftUI

/// Admin view for reviewing pending notes submissions.
struct PendingNotesReviewView: View {
    @State private var pendingNotes: [Content] = []
    @State private var isLoading = true
    @State private var selectedNote: Content?
    @State private var showRejectAlert = false
    @State private var rejectReason = ""

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if pendingNotes.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.success)
                    Text("All caught up!")
                        .font(Typography.titleMedium)
                        .foregroundStyle(.white)
                    Text("No notes pending review")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            } else {
                List {
                    ForEach(pendingNotes) { note in
                        pendingNoteRow(note)
                            .listRowBackground(ColorTokens.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
        .navigationTitle("Pending Notes (\(pendingNotes.count))")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reject Note", isPresented: $showRejectAlert) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) {
                if let note = selectedNote {
                    Task { await moderateNote(note, status: "rejected", note: rejectReason) }
                }
            }
        }
        .task { await loadPending() }
    }

    private func pendingNoteRow(_ note: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title + author
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if let creator = note.creatorId {
                        Text("by \(creator.displayName)")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                Spacer()
                if let pages = note.pageCount {
                    Text("\(pages) pages")
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            // Domain + AI quality
            HStack(spacing: Spacing.sm) {
                if let domain = note.domain {
                    Text(domain.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }
                if let quality = note.aiData?.qualityScore {
                    Text("Quality: \(quality)/100")
                        .font(.system(size: 10))
                        .foregroundStyle(quality >= 60 ? ColorTokens.success : .orange)
                }
            }

            // AI Summary
            if let summary = note.aiData?.summary, !summary.isEmpty {
                Text(summary)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(3)
            }

            // Actions
            HStack(spacing: Spacing.md) {
                Button {
                    Task { await moderateNote(note, status: "approved", note: nil) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ColorTokens.success)
                    .clipShape(Capsule())
                }

                Button {
                    selectedNote = note
                    rejectReason = ""
                    showRejectAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadPending() async {
        isLoading = true
        do {
            let result: [Content] = try await APIClient.shared.request(AdminEndpoints.pendingNotes)
            pendingNotes = result
        } catch {
            pendingNotes = []
        }
        isLoading = false
    }

    private func moderateNote(_ note: Content, status: String, note moderationNote: String?) async {
        do {
            let body = ModerationBody(moderationStatus: status, moderationNote: moderationNote)
            _ = try await APIClient.shared.requestRaw(AdminEndpoints.moderate(id: note.id), body: body)
            pendingNotes.removeAll { $0.id == note.id }
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - Admin Endpoints

private enum AdminEndpoints: Endpoint {
    case pendingNotes
    case moderate(id: String)

    var path: String {
        switch self {
        case .pendingNotes: return "/admin/notes/pending"
        case .moderate(let id): return "/admin/content/\(id)/moderate"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .pendingNotes: return .get
        case .moderate: return .put
        }
    }
}

private struct ModerationBody: Encodable, Sendable {
    let moderationStatus: String
    let moderationNote: String?
}
