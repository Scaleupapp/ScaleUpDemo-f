import SwiftUI

struct MyNotesView: View {
    @State private var notes: [Content] = []
    @State private var isLoading = true
    @State private var showCreateNotes = false
    @State private var autoRefreshTask: Task<Void, Never>?

    private let notesService = NotesService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if notes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .navigationTitle("My Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateNotes = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .sheet(isPresented: $showCreateNotes) {
            CreateNotesView(onComplete: {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await loadNotes()
                }
            })
        }
        .onChange(of: showCreateNotes) { _, showing in
            if !showing { Task { await loadNotes() } }
        }
        .task { await loadNotes() }
        .onDisappear { autoRefreshTask?.cancel() }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No notes yet")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Upload your handwritten or typed notes to share with others")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            PrimaryButton(title: "Upload Notes", icon: "arrow.up.doc.fill") {
                showCreateNotes = true
            }
            .padding(.horizontal, Spacing.xxl)
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            // Stats summary
            statsHeader

            LazyVStack(spacing: Spacing.sm) {
                ForEach(notes) { note in
                    NavigationLink {
                        NoteManageView(note: note, onUpdate: { Task { await loadNotes() } })
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private var statsHeader: some View {
        let published = notes.filter { $0.status == .published }.count
        let pending = notes.filter { $0.moderationStatus == "pending" }.count
        let totalViews = notes.compactMap { $0.viewCount }.reduce(0, +)
        let totalLikes = notes.compactMap { $0.likeCount }.reduce(0, +)

        return HStack(spacing: Spacing.md) {
            statPill(value: "\(notes.count)", label: "Total", color: ColorTokens.textSecondary)
            statPill(value: "\(published)", label: "Live", color: ColorTokens.success)
            if pending > 0 {
                statPill(value: "\(pending)", label: "Review", color: .orange)
            }
            statPill(value: "\(totalViews)", label: "Views", color: ColorTokens.gold)
            statPill(value: "\(totalLikes)", label: "Likes", color: .red)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Note Row

    private func noteRow(_ note: Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: 0x1A2A3A), Color(hex: 0x0F1923)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title)
                        .font(Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: Spacing.sm) {
                        statusBadge(note)

                        if let domain = note.domain {
                            Text(domain.capitalized)
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        if let pages = note.pageCount, pages > 0 {
                            Text("\(pages) pg")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }
            }

            // Preview snippet
            if let ocrText = note.ocrText, !ocrText.isEmpty {
                Text(ocrText.prefix(120).replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .lineLimit(2)
            }

            // Stats row
            HStack(spacing: Spacing.md) {
                if let views = note.viewCount, views > 0 {
                    Label("\(views)", systemImage: "eye")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if let likes = note.likeCount, likes > 0 {
                    Label("\(likes)", systemImage: "heart")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if let saves = note.saveCount, saves > 0 {
                    Label("\(saves)", systemImage: "bookmark")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                if let date = note.createdAt {
                    Spacer()
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statusBadge(_ note: Content) -> some View {
        let (label, color) = noteStatusInfo(note)
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    private func noteStatusInfo(_ note: Content) -> (String, Color) {
        if note.status == .published { return ("Live", ColorTokens.success) }
        if note.status == .processing { return ("Processing", .blue) }
        if note.status == .rejected { return ("Rejected", .red) }
        if note.moderationStatus == "pending" { return ("Under Review", .orange) }
        if note.status == .ready { return ("Ready", ColorTokens.gold) }
        return ("Draft", ColorTokens.textTertiary)
    }

    // MARK: - Load

    private func loadNotes() async {
        isLoading = notes.isEmpty
        notes = (try? await notesService.fetchMyNotes()) ?? []
        isLoading = false

        // Auto-refresh if any notes are still processing
        let hasProcessing = notes.contains { $0.status == .processing }
        if hasProcessing {
            startAutoRefresh()
        } else {
            autoRefreshTask?.cancel()
        }
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                notes = (try? await notesService.fetchMyNotes()) ?? notes
                let stillProcessing = notes.contains { $0.status == .processing }
                if !stillProcessing { return }
            }
        }
    }
}
