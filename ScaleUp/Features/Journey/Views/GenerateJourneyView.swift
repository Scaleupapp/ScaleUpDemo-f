import SwiftUI

struct GenerateJourneyView: View {
    @Bindable var viewModel: MyPlanViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.gold.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(ColorTokens.gold.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "map.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.gold)
            }

            // Text
            VStack(spacing: Spacing.sm) {
                Text("Create Your Learning Roadmap")
                    .font(Typography.titleLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("We'll build a personalized week-by-week plan based on your objective, skill level, and learning pace.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Features list
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureRow(icon: "calendar.badge.clock", text: "Daily content assignments")
                featureRow(icon: "brain.head.profile", text: "Weekly knowledge quizzes")
                featureRow(icon: "arrow.triangle.branch", text: "Adaptive plan adjustments")
                featureRow(icon: "flag.checkered", text: "Milestone tracking")
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
            )
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Progress section (visible during generation)
            if viewModel.isGenerating {
                VStack(spacing: Spacing.sm) {
                    // Status text
                    Text(viewModel.generationStatusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.generationStatusText)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ColorTokens.surface)
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(ColorTokens.gold)
                                .frame(width: geo.size.width * viewModel.generationProgress, height: 10)
                                .animation(.easeInOut(duration: 0.4), value: viewModel.generationProgress)
                        }
                    }
                    .frame(height: 10)

                    // Percentage + time estimate
                    HStack {
                        Text("\(Int(viewModel.generationProgress * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ColorTokens.gold)
                        Spacer()
                        Text("This usually takes 60–90 seconds")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
            }

            // CTA
            Button {
                Task {
                    if let objId = viewModel.objectiveId {
                        await viewModel.generateJourney(objectiveId: objId)
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.isGenerating ? "Generating Plan..." : "Generate My Plan")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.objectiveId != nil ? ColorTokens.gold : ColorTokens.gold.opacity(0.4))
                )
            }
            .disabled(viewModel.isGenerating || viewModel.objectiveId == nil)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 28, height: 28)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
