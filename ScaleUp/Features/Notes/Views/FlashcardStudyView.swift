import SwiftUI

struct FlashcardStudyView: View {
    let flashcardSetId: String

    @State private var flashcardSet: FlashcardSet?
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var masteredCards: Set<String> = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private let notesService = NotesService()

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(ColorTokens.gold)
            } else if let set = flashcardSet, !set.cards.isEmpty {
                studyContent(set)
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("No flashcards available")
                        .font(Typography.bodySmall)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .navigationTitle("Study Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFlashcards() }
    }

    // MARK: - Study Content

    private func studyContent(_ set: FlashcardSet) -> some View {
        let card = set.cards[currentIndex]
        let total = set.cards.count

        return VStack(spacing: Spacing.xl) {
            // Progress
            HStack {
                Text("\(currentIndex + 1) / \(total)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
                Text("\(masteredCards.count) mastered")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, Spacing.lg)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceElevated)
                    Capsule()
                        .fill(ColorTokens.gold)
                        .frame(width: geo.size.width * Double(currentIndex + 1) / Double(total))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Card
            cardView(card)
                .padding(.horizontal, Spacing.lg)

            Spacer()

            // Actions
            if isFlipped {
                HStack(spacing: Spacing.xl) {
                    Button {
                        nextCard()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 24))
                            Text("Need Practice")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.lg)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        masteredCards.insert(card.id)
                        Haptics.success()
                        nextCard()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                            Text("Got It!")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.lg)
                        .background(ColorTokens.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, Spacing.lg)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFlipped = true
                    }
                } label: {
                    Text("Tap to Reveal")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ColorTokens.gold.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, Spacing.lg)
            }

            Spacer().frame(height: Spacing.lg)
        }
    }

    // MARK: - Card View

    private func cardView(_ card: FlashcardCard) -> some View {
        VStack(spacing: Spacing.lg) {
            // Difficulty badge
            if let difficulty = card.difficulty {
                Text(difficulty.capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor(difficulty))
                    .clipShape(Capsule())
            }

            // Front
            Text(card.front)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Back (shown when flipped)
            if isFlipped {
                Divider().background(ColorTokens.border)

                Text(card.back)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)

                if let hint = card.hint, !hint.isEmpty {
                    Text("Hint: \(hint)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .italic()
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 250)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isFlipped ? ColorTokens.gold.opacity(0.2) : ColorTokens.border, lineWidth: 1)
        )
        .onTapGesture {
            if !isFlipped {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFlipped = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func nextCard() {
        guard let set = flashcardSet else { return }
        if currentIndex < set.cards.count - 1 {
            withAnimation {
                currentIndex += 1
                isFlipped = false
            }
        } else {
            // Session complete
            Task {
                try? await notesService.recordStudy(id: flashcardSetId, masteredCount: masteredCards.count)
            }
            dismiss()
        }
    }

    private func loadFlashcards() async {
        isLoading = true
        flashcardSet = try? await notesService.fetchFlashcardSet(id: flashcardSetId)
        isLoading = false
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "easy": return .green
        case "hard": return .red
        default: return .orange
        }
    }
}
