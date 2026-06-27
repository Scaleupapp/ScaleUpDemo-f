import SwiftUI

/// Library tab — curated placement-prep content for the cohort.
///
/// Fetches shelves from GET /api/v2/me/placement/shelves and renders each
/// shelf as a card with its items. Falls back to a quiet empty state when the
/// cohort has no shelves yet.
struct PlacementsLibraryView: View {
    @Environment(\.openURL) private var openURL

    @State private var shelves: [PlacementShelf] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library").v2Eyebrow()
                    Text("Placement prep")
                        .font(V2Theme.h1)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                .padding(.top, 8)

                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 32)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.top, 16)
                } else if shelves.isEmpty {
                    PlacementEmptyState(
                        icon: "books.vertical.fill",
                        title: "No shelves yet",
                        message: "Your TPO adds prep material here."
                    )
                } else {
                    ForEach(shelves) { shelf in
                        ShelfCardView(shelf: shelf, openURL: openURL)
                    }
                }

                AskCompassHelper()
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
        .task {
            await loadShelves()
        }
    }

    private func loadShelves() async {
        isLoading = true
        errorMessage = nil
        do {
            shelves = try await PlacementsLibraryApi.shared.fetchShelves()
        } catch {
            errorMessage = "Could not load shelves. Please try again."
        }
        isLoading = false
    }
}

// MARK: - Shelf Card

private struct ShelfCardView: View {
    let shelf: PlacementShelf
    let openURL: OpenURLAction

    private var itemCountLabel: String {
        let n = shelf.items.count
        return n == 1 ? "1 item" : "\(n) items"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shelf.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer(minLength: 0)
                Text(itemCountLabel)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            if shelf.items.isEmpty {
                Text("No items in this shelf yet.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shelf.items.enumerated()), id: \.element.id) { idx, item in
                        if idx > 0 {
                            Rectangle()
                                .fill(ColorTokens.border)
                                .frame(height: 1)
                        }
                        ShelfItemRow(item: item, openURL: openURL)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
        .placementCard()
    }
}

// MARK: - Shelf Item Row

private struct ShelfItemRow: View {
    let item: PlacementShelfItem
    let openURL: OpenURLAction

    private var isFile: Bool { item.type == "file" }
    private var glyphName: String { isFile ? "doc.fill" : "link" }
    private var hasURL: Bool { item.url != nil }

    var body: some View {
        Button {
            if let rawURL = item.url, let url = URL(string: rawURL) {
                openURL(url)
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: glyphName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 30, height: 30)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                if hasURL {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasURL)
    }
}

// MARK: - Ask Compass helper (subtle, not a primary card)

private struct AskCompassHelper: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 26, height: 26)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ask Compass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Tap the Compass button any time for explanations, practice, and guidance.")
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
    }
}
