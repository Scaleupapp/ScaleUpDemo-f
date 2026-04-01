import SwiftUI

struct MyFlashcardsView: View {
    @State private var flashcardSets: [FlashcardSet] = []
    @State private var isLoading = true
    @State private var navigateToSetId: String?

    private let notesService = NotesService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if flashcardSets.isEmpty {
                emptyState
            } else {
                flashcardList
            }
        }
        .navigationTitle("My Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigateToSetId) { id in
            FlashcardStudyView(flashcardSetId: id)
        }
        .task { await loadFlashcards() }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No flashcards yet")
                .font(Typography.titleMedium)
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Generate flashcards from any notes to start studying")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    private var flashcardList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(flashcardSets) { set in
                    Button {
                        navigateToSetId = set.id
                    } label: {
                        flashcardRow(set)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private func flashcardRow(_ set: FlashcardSet) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(set.title)
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    Text("\(set.totalCards) cards")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if set.masteryPercentage > 0 {
                        Text("·")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("\(set.masteryPercentage)% mastered")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.gold)
                    }

                    if let studied = set.timesStudied, studied > 0 {
                        Text("·")
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text("Studied \(studied)x")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadFlashcards() async {
        isLoading = true
        if let result = try? await notesService.fetchMyFlashcards() {
            flashcardSets = result.items
        }
        isLoading = false
    }
}
