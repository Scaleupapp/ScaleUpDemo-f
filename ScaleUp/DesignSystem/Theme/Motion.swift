import SwiftUI

enum Motion {

    // MARK: - Durations

    static let quick: Double = 0.15
    static let standard: Double = 0.3
    static let smooth: Double = 0.5
    static let celebration: Double = 1.2

    // MARK: - Spring Animations

    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    static let springSmooth = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)

    // MARK: - Easing

    static let easeOut = Animation.easeOut(duration: standard)
    static let easeIn = Animation.easeIn(duration: standard)
    static let smoothEaseOut = Animation.easeOut(duration: smooth)

    // MARK: - Staggered Delays

    static func stagger(index: Int, base: Double = 0.05) -> Animation {
        .easeOut(duration: smooth).delay(Double(index) * base)
    }
}
