import SwiftUI

struct DiagnosticResultsView: View {
    let viewModel: DiagnosticViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Celebratory header
            VStack(spacing: Spacing.sm) {
                // Sparkles icon in a gold halo
                ZStack {
                    Circle()
                        .fill(ColorTokens.gold.opacity(0.14))
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(ColorTokens.gold)
                }
                .padding(.bottom, Spacing.sm)

                Text("Here's where you stand")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll personalise your learning plan around these results.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.xxl)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)

            // Results list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    ForEach(viewModel.results?.perCompetency ?? []) { result in
                        AnimatedCompetencyResultCard(result: result)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }

            // Continue button
            VStack(spacing: 0) {
                Divider()
                    .background(ColorTokens.divider)

                PrimaryButton(title: "Continue to my plan") {
                    onContinue()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(ColorTokens.background)
        }
    }
}

// MARK: - Animated Competency Result Card

private struct AnimatedCompetencyResultCard: View {
    let result: DiagnosticCompetencyResult

    @State private var displayedScore: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Topic + band
            HStack {
                Text(result.competency)
                    .font(Typography.titleMedium)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Text(result.band.capitalized)
                    .font(Typography.captionBold)
                    .foregroundStyle(bandColor(result.band))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(bandColor(result.band).opacity(0.12))
                    .clipShape(Capsule())
            }

            // Animated score bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surfaceElevated)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.goldGradient)
                            .frame(width: geo.size.width * (displayedScore / 100.0), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(result.score) / 100")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Calibration callout — info card style
            if abs(result.calibrationDelta ?? 0) >= 2 {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(ColorTokens.info)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Calibration note")
                            .font(Typography.captionBold)
                            .foregroundStyle(ColorTokens.info)

                        Text("Your self-rating and assessed score differ — we'll fine-tune your plan as you go.")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Spacing.md)
                .background(ColorTokens.info.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(ColorTokens.info.opacity(0.20), lineWidth: 1)
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                displayedScore = Double(result.score)
            }
        }
    }

    // MARK: - Helpers

    private func bandColor(_ band: String) -> Color {
        switch band.lowercased() {
        case "expert":     return ColorTokens.gold
        case "proficient": return ColorTokens.success
        case "familiar":   return ColorTokens.info
        case "novice":     return ColorTokens.textTertiary
        default:           return ColorTokens.textSecondary
        }
    }
}
