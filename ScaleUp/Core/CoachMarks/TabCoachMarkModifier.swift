import SwiftUI

// MARK: - Tab Coach Mark ViewModifier

struct TabCoachMarkModifier<V: View>: View {
    @Environment(CoachMarkManager.self) private var coachMarkManager
    let wrappedView: V
    let markID: CoachMarkID
    let icon: String
    let title: String
    let message: String
    var autoDismissDelay: Double = 8.0

    var body: some View {
        wrappedView
            .safeAreaInset(edge: .bottom) {
                if coachMarkManager.activeCoachMark == markID {
                    CoachMarkOverlay(
                        icon: icon,
                        title: title,
                        message: message,
                        showSkipAll: true,
                        onDismiss: {
                            coachMarkManager.complete(markID)
                        },
                        onSkipAll: {
                            coachMarkManager.skipAllCoachMarks()
                        }
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .onAppear {
                if coachMarkManager.shouldShow(markID) {
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        coachMarkManager.show(markID)
                    }
                }
            }
            .task(id: coachMarkManager.activeCoachMark) {
                if coachMarkManager.activeCoachMark == markID {
                    try? await Task.sleep(for: .seconds(autoDismissDelay))
                    if coachMarkManager.activeCoachMark == markID {
                        coachMarkManager.complete(markID)
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func coachMark(
        _ markID: CoachMarkID,
        icon: String,
        title: String,
        message: String,
        autoDismissDelay: Double = 8.0
    ) -> some View {
        TabCoachMarkModifier(
            wrappedView: self,
            markID: markID,
            icon: icon,
            title: title,
            message: message,
            autoDismissDelay: autoDismissDelay
        )
    }
}
