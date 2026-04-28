import SwiftUI

struct DiagnosticResultsView: View {
    let viewModel: DiagnosticViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.bottom, Spacing.sm)

                Text("Here's where you stand")
                    .font(Typography.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll use this to personalise your learning plan.")
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
                        competencyResultCard(result)
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

    // MARK: - Competency Result Card

    private func competencyResultCard(_ result: DiagnosticCompetencyResult) -> some View {
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

            // Score bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.surfaceElevated)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.goldGradient)
                            .frame(width: geo.size.width * (Double(result.score) / 100.0), height: 8)
                            .animation(.easeOut(duration: 0.6), value: result.score)
                    }
                }
                .frame(height: 8)

                Text("\(result.score) / 100")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Calibration delta callout
            if abs(result.calibrationDelta ?? 0) >= 2 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.info)

                    Text("We noticed you rated yourself differently than you assessed — we'll fine-tune as you go.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .background(ColorTokens.info.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
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
