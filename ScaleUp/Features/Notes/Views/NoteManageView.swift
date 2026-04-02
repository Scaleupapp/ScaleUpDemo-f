import SwiftUI
import PDFKit

struct NoteManageView: View {
    let note: Content
    var onUpdate: (() -> Void)?

    @State private var isEditing = false
    @State private var editTitle: String
    @State private var editDesc: String
    @State private var editDomain: String
    @State private var editDifficulty: String
    @State private var showDeleteConfirm = false
    @State private var isSaving = false
    @State private var showPDFViewer = false
    @State private var pdfDocument: PDFDocument?
    @State private var isLoadingPDF = false
    @Environment(\.dismiss) private var dismiss

    private let notesService = NotesService()

    init(note: Content, onUpdate: (() -> Void)? = nil) {
        self.note = note
        self.onUpdate = onUpdate
        _editTitle = State(initialValue: note.title)
        _editDesc = State(initialValue: note.description ?? "")
        _editDomain = State(initialValue: note.domain ?? "")
        _editDifficulty = State(initialValue: note.difficulty?.rawValue ?? "intermediate")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Status + actions header
                statusSection

                // Details (view or edit)
                if isEditing {
                    editSection
                } else {
                    detailsSection
                }

                // AI Analysis
                if note.status == .processing {
                    aiProcessingSection
                } else if note.aiData != nil {
                    aiSection
                }

                // Stats
                statsSection

                // Actions
                actionsSection

                Spacer().frame(height: Spacing.xxxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .background(ColorTokens.background)
        .navigationTitle(isEditing ? "Edit Note" : "Note Details")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPDFViewer) {
            if let pdfDocument {
                FullScreenPDFView(document: pdfDocument, title: note.title) {
                    showPDFViewer = false
                }
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteNote() } }
        } message: {
            Text("This will permanently delete this note and all its data.")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: Spacing.sm) {
            statusBadge
            Spacer()
            if let pages = note.pageCount {
                Label("\(pages) pages", systemImage: "doc.text")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            if let college = note.collegeName, !college.isEmpty {
                Label(college, systemImage: "building.columns")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (label, color) = noteStatus
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var noteStatus: (String, Color) {
        if note.status == .published { return ("Live", ColorTokens.success) }
        if note.status == .processing { return ("Processing", .blue) }
        if note.status == .rejected { return ("Rejected", .red) }
        if note.moderationStatus == "pending" { return ("Under Review", .orange) }
        if note.status == .ready { return ("Ready", ColorTokens.gold) }
        return ("Draft", ColorTokens.textTertiary)
    }

    // MARK: - Details (View Mode)

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(note.title)
                .font(Typography.titleLarge)
                .foregroundStyle(.white)

            if let desc = note.description, !desc.isEmpty {
                Text(desc)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            HStack(spacing: Spacing.sm) {
                if let domain = note.domain {
                    Text(domain.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(Capsule())
                }
                if let diff = note.difficulty {
                    Text(diff.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.gold)
                        .clipShape(Capsule())
                }
            }

            if let topics = note.topics, !topics.isEmpty {
                NoteFlowLayout(spacing: 6) {
                    ForEach(topics, id: \.self) { topic in
                        Text(topic.capitalized)
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTokens.surface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Edit Mode

    private var editSection: some View {
        VStack(spacing: Spacing.md) {
            ScaleUpTextField(label: "Title", icon: "textformat", text: $editTitle, autocapitalization: .words)
            ScaleUpTextField(label: "Description", icon: "text.alignleft", text: $editDesc, autocapitalization: .sentences)
            ScaleUpTextField(label: "Domain", icon: "folder.fill", text: $editDomain, autocapitalization: .words)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Difficulty")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                HStack(spacing: Spacing.sm) {
                    ForEach(["beginner", "intermediate", "advanced"], id: \.self) { level in
                        Button {
                            editDifficulty = level
                        } label: {
                            Text(level.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(editDifficulty == level ? .white : ColorTokens.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(editDifficulty == level ? ColorTokens.gold : ColorTokens.surface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: Spacing.md) {
                PrimaryButton(title: isSaving ? "Saving..." : "Save Changes", isLoading: isSaving) {
                    Task { await saveEdits() }
                }
                Button("Cancel") {
                    isEditing = false
                }
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - AI Processing

    private var aiProcessingSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(ColorTokens.gold)
                Text("AI Analysis")
                    .font(Typography.bodyBold)
                    .foregroundStyle(.white)
                Spacer()
                ProgressView()
                    .tint(ColorTokens.gold)
                    .scaleEffect(0.8)
            }

            VStack(spacing: Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.gold.opacity(0.7))
                    Text("Your notes are being analyzed by AI. This may take a minute or two.")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Text("We're extracting key concepts, generating a summary, and assessing content quality. This page will update automatically once complete.")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - AI Analysis

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(ColorTokens.gold)
                Text("AI Analysis")
                    .font(Typography.bodyBold)
                    .foregroundStyle(.white)
            }

            if let summary = note.aiData?.summary, !summary.isEmpty {
                Text(summary)
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            if let concepts = note.aiData?.keyConcepts, !concepts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Concepts")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                    ForEach(concepts.prefix(5), id: \.concept) { kc in
                        HStack(spacing: 6) {
                            Circle().fill(ColorTokens.gold).frame(width: 5, height: 5)
                            Text(kc.concept)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            if let desc = kc.description, !desc.isEmpty {
                                Text("— \(desc)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if let quality = note.aiData?.qualityScore {
                HStack(spacing: 6) {
                    Text("Quality Score:")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(quality)/100")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(quality >= 70 ? ColorTokens.success : quality >= 40 ? ColorTokens.gold : .red)
                }
            }
        }
        .padding(Spacing.lg)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: Spacing.md) {
            statBox(icon: "eye", value: "\(note.viewCount ?? 0)", label: "Views")
            statBox(icon: "heart", value: "\(note.likeCount ?? 0)", label: "Likes")
            statBox(icon: "bookmark", value: "\(note.saveCount ?? 0)", label: "Saves")
            statBox(icon: "bubble.left", value: "\(note.commentCount ?? 0)", label: "Comments")
        }
    }

    private func statBox(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            // View Document
            Button {
                Task { await openPDF() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isLoadingPDF {
                        ProgressView().tint(.orange)
                    } else {
                        Image(systemName: "doc.text.fill")
                    }
                    Text("View Document")
                }
                    .font(Typography.bodyBold)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Edit
            Button {
                isEditing.toggle()
            } label: {
                Label(isEditing ? "Cancel Edit" : "Edit Details", systemImage: "pencil")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Publish/Unpublish
            if note.status == .ready || note.status == .unpublished {
                Button {
                    Task { await publishNote() }
                } label: {
                    Label("Publish Note", systemImage: "paperplane.fill")
                        .font(Typography.bodyBold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ColorTokens.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if note.status == .published {
                Button {
                    Task { await unpublishNote() }
                } label: {
                    Label("Unpublish", systemImage: "eye.slash")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Delete
            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete Note", systemImage: "trash")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private let playerService = PlayerService()

    private func openPDF() async {
        if pdfDocument != nil { showPDFViewer = true; return }
        isLoadingPDF = true
        if let stream: StreamResponse = try? await playerService.fetchStreamURL(contentId: note.id),
           let urlStr = stream.resolvedURL, let url = URL(string: urlStr),
           let data = try? await URLSession.shared.data(from: url).0 {
            pdfDocument = PDFDocument(data: data)
            showPDFViewer = true
        }
        isLoadingPDF = false
    }

    // MARK: - API Actions

    private func saveEdits() async {
        isSaving = true
        do {
            let body = NoteEditBody(
                title: editTitle.trimmingCharacters(in: .whitespaces),
                description: editDesc,
                domain: editDomain.lowercased(),
                difficulty: editDifficulty
            )
            _ = try await APIClient.shared.requestRaw(NoteUpdateEndpoint(id: note.id), body: body)
            isEditing = false
            Haptics.success()
            onUpdate?()
        } catch {
            Haptics.error()
        }
        isSaving = false
    }

    private func publishNote() async {
        try? await notesService.publishNote(id: note.id)
        Haptics.success()
        onUpdate?()
        dismiss()
    }

    private func unpublishNote() async {
        try? await notesService.unpublishNote(id: note.id)
        Haptics.success()
        onUpdate?()
        dismiss()
    }

    private func deleteNote() async {
        try? await notesService.deleteNote(id: note.id)
        Haptics.success()
        onUpdate?()
        dismiss()
    }
}

// MARK: - Simple Flow Layout

private struct NoteFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        return CGSize(width: width, height: y + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}

// MARK: - Endpoint

private struct NoteEditBody: Encodable, Sendable {
    let title: String
    let description: String
    let domain: String
    let difficulty: String
}

private struct NoteUpdateEndpoint: Endpoint {
    let id: String
    var path: String { "/notes/\(id)" }
    var method: HTTPMethod { .put }
}
