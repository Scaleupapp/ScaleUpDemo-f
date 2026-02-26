import SwiftUI

enum Animations {
    /// 150ms — Micro-interactions, toggles
    static let quick: Animation = .easeOut(duration: 0.15)

    /// 300ms — Page transitions, modals
    static let standard: Animation = .easeOut(duration: 0.3)

    /// 500ms — Hero animations, onboarding
    static let smooth: Animation = .easeOut(duration: 0.5)

    /// Bouncy spring — Quiz results, confetti
    static let spring: Animation = .spring(duration: 0.5, bounce: 0.3)

    /// Enter animation curve
    static let easeOut: Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.3)

    /// Exit animation curve
    static let easeIn: Animation = .timingCurve(0.7, 0, 0.84, 0, duration: 0.3)
}
