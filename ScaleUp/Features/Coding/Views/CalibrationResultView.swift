import SwiftUI

struct CalibrationResultView: View {
    let result: CalibrationResultResponse
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                baselineAxesSection
                difficultyCard
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            doneButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your baseline")
                .font(.largeTitle.weight(.semibold))
            Text("Based on your 3 calibration drills, here's where you start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var baselineAxesSection: some View {
        if let axes = result.baselineAxes {
            VStack(alignment: .leading, spacing: 14) {
                Text("Where you are")
                    .font(.headline)

                VStack(spacing: 14) {
                    // BaselineAxes values are 0..100; RubricBar expects 0..10
                    RubricBar(dimension: "prompting", score: axes.prompting / 10.0, feedback: nil)
                    RubricBar(dimension: "verification", score: axes.verification / 10.0, feedback: nil)
                    RubricBar(dimension: "decomposition", score: axes.decomposition / 10.0, feedback: nil)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var difficultyCard: some View {
        if let recommended = result.recommendedDifficulty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Suggested starting difficulty", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))

                HStack {
                    Text(recommended.rawValue.capitalized)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()
                }

                Text("You can change this anytime in Settings. Your daily drills will start at this level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Start your daily drills")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    CalibrationResultView(
        result: CalibrationResultResponse(
            calibrationId: "preview-id",
            status: "graded",
            drills: nil,
            baselineAxes: BaselineAxes(
                prompting: 62.0,
                verification: 45.0,
                decomposition: 78.0,
                refactoring: 0.0
            ),
            recommendedDifficulty: .easy
        )
    ) {
        // dismiss
    }
}
