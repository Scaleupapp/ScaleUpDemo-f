import SwiftUI

/// Library tab — curated placement-prep content for the cohort.
///
/// Fetches shelves from GET /api/v2/me/placement/shelves and renders each
/// shelf as a titled section with its items. Falls back to an empty state
/// message when the cohort has no shelves yet.
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
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 32)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.top, 16)
                } else if shelves.isEmpty {
                    Text("No shelves yet — your TPO will add prep material here.")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.top, 16)
                } else {
                    ForEach(shelves) { shelf in
                        ShelfSectionView(shelf: shelf, openURL: openURL)
                    }
                }

                PlacementsPlaceholderCard(
                    icon: "sparkles",
                    title: "Ask Compass",
                    message: "Tap the Compass button any time for explanations, practice, and guidance."
                )
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

// MARK: - Shelf Section

private struct ShelfSectionView: View {
    let shelf: PlacementShelf
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shelf.title)
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)

            if shelf.items.isEmpty {
                Text("No items in this shelf yet.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(shelf.items) { item in
                    ShelfItemRow(item: item, openURL: openURL)
                }
            }
        }
        .padding(14)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shelf Item Row

private struct ShelfItemRow: View {
    let item: PlacementShelfItem
    let openURL: OpenURLAction

    private var glyphName: String {
        item.type == "file" ? "doc.fill" : "link"
    }

    var body: some View {
        Button {
            if let rawURL = item.url, let url = URL(string: rawURL) {
                openURL(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: glyphName)
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.url == nil)
    }
}
