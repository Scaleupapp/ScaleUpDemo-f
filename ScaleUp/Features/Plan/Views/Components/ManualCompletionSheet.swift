import SwiftUI

/// Sheet shown when the user taps a `.manual` or `.externalLink` plan task.
/// Captures a 1...5 self-confidence rating and POSTs to
/// `/plan/tasks/{taskId}/complete` via `PlanService.markTaskComplete`.
struct ManualCompletionSheet: View {
    let task: APIPlanTask
    let onComplete: () -> Void

    @State private var selectedRating: Int = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let service = PlanService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Text("Mark complete")
                        .font(Typography.titleLarge)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(task.topic.displayName)
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("How confident do you feel about this topic now?")
                        .font(Typography.bodyBold)
                        .foregroundStyle(ColorTokens.textPrimary)
                    HStack(spacing: Spacing.sm) {
                        ForEach(1...5, id: \.self) { i in
                            ratingChip(i)
                        }
                    }
                    Text(ratingLabel(selectedRating))
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }

                PrimaryButton(
                    title: isSubmitting ? "Saving..." : "Confirm",
                    isLoading: isSubmitting,
                    isDisabled: selectedRating == 0 || isSubmitting
                ) {
                    Task { await submit() }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rating Chip

    private func ratingChip(_ value: Int) -> some View {
        let isSelected = value == selectedRating
        return Button(action: { selectedRating = value }) {
            Text("\(value)")
                .font(Typography.bodyBold)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? ColorTokens.gold : ColorTokens.gold.opacity(0.10))
                )
                .foregroundStyle(isSelected ? Color.white : ColorTokens.gold)
                .overlay(
                    Circle()
                        .stroke(ColorTokens.gold.opacity(0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "1 — Just learned"
        case 2: return "2 — Getting comfortable"
        case 3: return "3 — Solid grasp"
        case 4: return "4 — Confident"
        case 5: return "5 — Mastery"
        default: return "Pick a rating"
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard (1...5).contains(selectedRating) else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            _ = try await service.markTaskComplete(
                taskId: task.taskId,
                selfRating: selectedRating
            )
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
