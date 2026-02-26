import UIKit

// MARK: - Extended Haptic Patterns

extension HapticManager {

    /// Quiz correct answer — success notification with a slight delay for dramatic effect.
    func playQuizCorrect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            success()
        }
    }

    /// Quiz wrong answer — error pattern for negative feedback.
    func playQuizWrong() {
        error()
    }

    /// Milestone reached — notification followed by a success for emphasis.
    func playMilestoneReached() {
        medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            success()
        }
    }

    /// Streak celebration — series of escalating impacts.
    func playStreakCelebration() {
        let delays: [TimeInterval] = [0, 0.1, 0.2, 0.3]
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let style: UIImpactFeedbackGenerator.FeedbackStyle =
                    index < 2 ? .light : (index == 2 ? .medium : .heavy)
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        }
    }

    /// Tab switch — light selection feedback.
    func playTabSwitch() {
        selection()
    }
}
