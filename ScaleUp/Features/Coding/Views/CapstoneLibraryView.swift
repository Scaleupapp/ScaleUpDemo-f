import SwiftUI

/// Capstone library list — entry point for non-plan-scheduled starts.
/// Plan-driven entries skip this and go straight to Preflight via the
/// plan-task tap handler.
struct CapstoneLibraryView: View {
    @State private var entries: [CapstoneLibraryEntry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selected: CapstoneLibraryEntry?
    @State private var filterDifficulty: DrillDifficulty?
    @State private var filterRoleTrack: RoleTrack?
    @State private var searchText = ""
    @State private var showGenerator = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Capstones")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search all capstones")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showGenerator = true
                        } label: {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Difficulty", selection: $filterDifficulty) {
                                Text("Any difficulty").tag(Optional<DrillDifficulty>.none)
                                ForEach([DrillDifficulty.easy, .medium, .hard], id: \.self) { d in
                                    Text(d.rawValue.capitalized).tag(Optional(d))
                                }
                            }
                            Picker("Role track", selection: $filterRoleTrack) {
                                Text("Any track").tag(Optional<RoleTrack>.none)
                                ForEach([RoleTrack.swe, .ds, .ai_eng], id: \.self) { r in
                                    Text(roleTrackTitle(r)).tag(Optional(r))
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .task(id: filterKey) { await load() }
                .sheet(item: $selected) { entry in
                    CapstonePreflightView(bundle: entry, onClose: { selected = nil })
                }
                .sheet(isPresented: $showGenerator) {
                    CapstoneGeneratorSheet(
                        onClose: { showGenerator = false },
                        onReady: { entry in
                            showGenerator = false
                            // Hand straight off to Preflight for the freshly-built capstone.
                            selected = entry
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView("Loading capstones…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = error {
            ContentUnavailableView("Couldn't load capstones", systemImage: "wifi.slash", description: Text(err))
        } else if entries.isEmpty {
            ContentUnavailableView(
                "No capstones available",
                systemImage: "tray",
                description: Text("New capstones land here when they pass the validator.")
            )
        } else {
            List {
                ForEach(entries) { e in
                    Button {
                        selected = e
                    } label: {
                        row(e)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(_ e: CapstoneLibraryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Title (first line) only — the full brief belongs on Preflight,
                // not mashed into a list row.
                Text(e.brief.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? e.brief)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Spacer()
                if e.alreadyCompleted {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            }
            HStack(spacing: 6) {
                badge(e.difficulty.rawValue.capitalized)
                badge("\(e.timeBudgetMinutes) min")
                badge(roleTrackTitle(e.roleTrack))
                badge(e.language)
                Spacer()
            }
            if let parallel = e.interviewParallel {
                Text(parallel).font(.caption).foregroundStyle(.tint).lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.gray.opacity(0.15)))
    }

    private func roleTrackTitle(_ r: RoleTrack) -> String {
        switch r {
        case .swe:    return "SWE"
        case .ds:     return "DS"
        case .ai_eng: return "AI/ML"
        }
    }

    private var filterKey: String {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(filterDifficulty?.rawValue ?? "any")-\(filterRoleTrack?.rawValue ?? "any")-\(q)"
    }

    private func load() async {
        // Debounce: .task(id: filterKey) cancels the previous run on each
        // keystroke, so a short sleep here coalesces typing into one request.
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        loading = true
        error = nil
        do {
            let list = try await CapstoneService.shared.listLibrary(
                difficulty: filterDifficulty, roleTrack: filterRoleTrack, search: searchText
            )
            if Task.isCancelled { return }
            entries = list
        } catch {
            self.error = "Pull to refresh."
        }
        loading = false
    }
}
