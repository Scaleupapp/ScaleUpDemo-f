import SwiftUI

// MARK: - Library tab enum

/// Identifies which "My Library" tab the user opened.
enum V2YouLibraryTab: String, Identifiable {
    case saved, liked, playlists, history
    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: return "Saved"
        case .liked: return "Liked"
        case .playlists: return "Playlists"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .saved: return "bookmark.fill"
        case .liked: return "heart.fill"
        case .playlists: return "list.star"
        case .history: return "clock.fill"
        }
    }
}

// MARK: - Library sheet

/// Sheet wrapper that renders the v1-style content lists for one library tab
/// (Saved / Liked / Playlists / History). Reuses ProfileViewModel for fetches.
struct V2YouLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let tab: V2YouLibraryTab

    @State private var vm = ProfileViewModel()
    @State private var didLoad = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        switch tab {
                        case .saved:
                            contentGrid(items: vm.savedContent, empty: "No saved content yet")
                        case .liked:
                            contentGrid(items: vm.likedContent, empty: "No liked content yet")
                        case .playlists:
                            playlistsList
                        case .history:
                            historyGrid
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.gold)
                }
            }
            .navigationDestination(for: Content.self) { ContentDestinationView(content: $0) }
            .task {
                if !didLoad {
                    didLoad = true
                    await loadCurrent()
                }
            }
            .refreshable { await loadCurrent() }
        }
    }

    private func loadCurrent() async {
        switch tab {
        case .saved:     await vm.loadSavedContent()
        case .liked:     await vm.loadLikedContent()
        case .playlists: await vm.loadPlaylists()
        case .history:   await vm.loadViewHistory()
        }
    }

    // MARK: Grids (ported from ProfileTabView, trimmed)

    @ViewBuilder
    private func contentGrid(items: [Content], empty: String) -> some View {
        if items.isEmpty {
            emptyMessage(icon: "tray", text: empty)
        } else {
            LazyVGrid(columns: gridColumns, spacing: Spacing.sm) {
                ForEach(items) { c in
                    NavigationLink(value: c) {
                        contentCell(c)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func contentCell(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                if let thumb = content.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                        default: ColorTokens.surfaceElevated
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                } else {
                    ColorTokens.surfaceElevated.frame(height: 100)
                }
                if !content.overlayBadge.isEmpty {
                    Text(content.overlayBadge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(6)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
                if let creator = content.creatorId {
                    Text(creator.displayName)
                        .font(Typography.micro)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    @ViewBuilder
    private var historyGrid: some View {
        if vm.viewHistory.isEmpty {
            emptyMessage(icon: "clock", text: "No watch history yet")
        } else {
            LazyVGrid(columns: gridColumns, spacing: Spacing.sm) {
                ForEach(vm.viewHistory) { progress in
                    if let content = progress.content {
                        NavigationLink(value: content) {
                            historyCell(progress)
                        }
                        .buttonStyle(.plain)
                    } else {
                        historyCell(progress)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func historyCell(_ progress: ContentProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                if let content = progress.content, let thumb = content.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                        default: ColorTokens.surfaceElevated
                        }
                    }
                    .frame(height: 100).clipped()
                } else {
                    ColorTokens.surfaceElevated.frame(height: 100)
                }
                Text("\(progress.percentageCompleted ?? 0)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(progress.isCompleted == true ? .black : .white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(progress.isCompleted == true ? ColorTokens.success : .black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(6)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(ColorTokens.surfaceElevated)
                    Rectangle()
                        .fill(progress.isCompleted == true ? ColorTokens.success : ColorTokens.gold)
                        .frame(width: geo.size.width * progress.progress)
                }
            }
            .frame(height: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.content?.title ?? "Content")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    @ViewBuilder
    private var playlistsList: some View {
        if vm.isLoadingPlaylists && vm.playlists.isEmpty {
            ProgressView().tint(ColorTokens.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if vm.playlists.isEmpty {
            emptyMessage(icon: "list.star", text: "No playlists yet")
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(vm.playlists) { p in
                    NavigationLink {
                        PlaylistDetailView(playlistId: p.id)
                            .environment(appState)
                    } label: {
                        playlistRow(p)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTokens.surfaceElevated)
                    .frame(width: 50, height: 50)
                Image(systemName: "music.note.list")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text("\(playlist.itemCount ?? 0) items")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                    if !playlist.formattedDuration.isEmpty {
                        Text("·").foregroundStyle(ColorTokens.textTertiary)
                        Text(playlist.formattedDuration)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private func emptyMessage(icon: String, text: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(text)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - My Objectives view

/// Lightweight objective management screen for the You tab.
/// Lists current objectives with switch / pause / resume; "Add" button opens AddObjectiveSheet.
struct V2YouObjectivesView: View {
    @Environment(AppState.self) private var appState
    @Environment(ObjectiveContext.self) private var objectiveContext

    @State private var vm = ProfileViewModel()
    @State private var didLoad = false
    @State private var showAdd = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if vm.objectives.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.objectives) { obj in
                            row(obj)
                        }
                    }
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .navigationTitle("My Objectives")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.light()
                    showAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddObjectiveSheet { newObj in
                vm.objectives.insert(newObj, at: 0)
            }
        }
        .task {
            if !didLoad {
                didLoad = true
                await vm.loadProfile()
            }
        }
        .refreshable { await vm.loadProfile() }
    }

    private var emptyState: some View {
        Button {
            Haptics.light()
            showAdd = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.gold.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set your first objective")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Track your learning goals and progress")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(14)
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    private func row(_ obj: UserObjective) -> some View {
        let isActive = obj.isPrimary == true
        return Button {
            if !isActive {
                Haptics.light()
                Task { await vm.activateObjective(obj.id, context: objectiveContext) }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: obj.typeIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? ColorTokens.gold : ColorTokens.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(isActive ? ColorTokens.gold.opacity(0.15) : ColorTokens.gold.opacity(0.05))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(obj.specificTitle)
                            .font(Typography.bodySmall)
                            .foregroundStyle(isActive ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            .lineLimit(1)
                        if isActive {
                            Text("ACTIVE")
                                .font(Typography.micro)
                                .foregroundStyle(ColorTokens.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ColorTokens.gold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(obj.typeDisplay) · \(obj.levelDisplay) · \(obj.timelineDisplay)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.gold)
                } else {
                    Text("Switch")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.sm)
            .background(isActive ? ColorTokens.gold.opacity(0.06) : ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(isActive ? ColorTokens.gold.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .contextMenu {
            if obj.status == .active && isActive {
                Button {
                    Task { await vm.pauseObjective(obj.id) }
                } label: { Label("Pause", systemImage: "pause.circle") }
            }
            if obj.status == .paused {
                Button {
                    Task { await vm.resumeObjective(obj.id) }
                } label: { Label("Resume", systemImage: "play.circle") }
            }
        }
    }
}

// MARK: - Placeholders (other agents will replace)

/// Placeholder for the full v2 plan detail screen. Agent C will replace this.
struct V2PlanDetailView: View {
    public init() {}
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading plan detail…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("My plan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Agent C: fetch full plan detail here.
        }
    }
}

/// Placeholder for v2 Compass history. Agent D will replace this.
struct V2CompassHistoryView: View {
    public init() {}
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your Compass activity…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("My Compass activity")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Agent D: fetch compass history here.
        }
    }
}

/// Placeholder for the deep "All my activities" feed. Agent D will replace this.
struct V2ActivitiesDetailView: View {
    public init() {}
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading all your activities…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .navigationTitle("All activities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Agent D: fetch activities feed here.
        }
    }
}
