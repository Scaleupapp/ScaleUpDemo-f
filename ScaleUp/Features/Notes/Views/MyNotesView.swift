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

        return HStack(spacing: 8) {
            statPill(value: "\(notes.count)", label: "Total", icon: "doc.text", color: ColorTokens.textSecondary)
            statPill(value: "\(published)", label: "Live", icon: "checkmark.circle", color: ColorTokens.success)
            if pending > 0 {
                statPill(value: "\(pending)", label: "Review", icon: "clock", color: .orange)
            }
            statPill(value: "\(totalViews)", label: "Views", icon: "eye", color: ColorTokens.gold)
            statPill(value: "\(totalLikes)", label: "Likes", icon: "heart", color: .red)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Note Row

    private func noteRow(_ note: Content) -> some View {
        HStack(spacing: 14) {
            // Status indicator strip
            let (_, statusColor) = noteStatusInfo(note)
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3, height: 48)

            // Main info
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    statusBadge(note)

                    if let date = note.createdAt {
                        Text(date, style: .date)
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            // Performance numbers
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Text("\(note.viewCount ?? 0)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "eye")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                HStack(spacing: 3) {
                    Text("\(note.likeCount ?? 0)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Image(systemName: "heart")
                        .font(.system(size: 8))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
