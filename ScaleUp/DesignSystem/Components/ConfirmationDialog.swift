import SwiftUI

// MARK: - DestructiveConfirmation

struct DestructiveConfirmation: ViewModifier {
    let title: String
    let message: String
    let actionTitle: String
    @Binding var isPresented: Bool
    let action: () -> Void

    func body(content: Self.Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
                Button(actionTitle, role: .destructive, action: action)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(message)
            }
    }
}

// MARK: - View Extension

extension View {
    func destructiveConfirmation(
        title: String,
        message: String,
        actionTitle: String,
        isPresented: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            DestructiveConfirmation(
                title: title,
                message: message,
                actionTitle: actionTitle,
                isPresented: isPresented,
                action: action
            )
        )
    }
}
