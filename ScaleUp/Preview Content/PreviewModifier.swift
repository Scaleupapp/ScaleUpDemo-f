import SwiftUI

// MARK: - Preview Wrapper

/// A container view that injects preview-compatible environment objects
/// and applies the app's default dark color scheme.
///
/// Usage in previews:
/// ```swift
/// #Preview {
///     PreviewWrapper {
///         LoginView(onForgotPassword: {})
///     }
/// }
/// ```
struct PreviewWrapper<Content: View>: View {

    // MARK: - Properties

    let authenticated: Bool
    let content: Content

    // MARK: - Initialization

    /// Creates a preview wrapper with the given content.
    ///
    /// - Parameters:
    ///   - authenticated: Whether to use an authenticated `AppState`. Defaults to `true`.
    ///   - content: The view to wrap with preview environment.
    init(
        authenticated: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.authenticated = authenticated
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        content
            .environment(DependencyContainer.preview)
            .environment(authenticated ? AppState.preview : AppState.previewUnauthenticated)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Preview Setup Modifier

/// A `ViewModifier` that injects the standard preview environment
/// into any view: `DependencyContainer`, `AppState`, and dark mode.
struct PreviewSetupModifier: ViewModifier {

    // MARK: - Properties

    let appState: AppState

    // MARK: - Initialization

    /// Creates the modifier with the specified app state.
    ///
    /// - Parameter appState: The `AppState` to inject. Defaults to `AppState.preview`.
    init(appState: AppState = .preview) {
        self.appState = appState
    }

    // MARK: - Body

    func body(content: Self.Content) -> some View {
        content
            .environment(DependencyContainer.preview)
            .environment(appState)
            .preferredColorScheme(.dark)
    }
}

// MARK: - View Extension

extension View {

    /// Applies the standard ScaleUp preview environment to this view.
    ///
    /// Injects a preview `DependencyContainer`, a preview `AppState`,
    /// and sets the preferred color scheme to `.dark`.
    ///
    /// - Parameter appState: The `AppState` to use. Defaults to an authenticated state.
    /// - Returns: The view wrapped with the preview environment.
    ///
    /// Usage:
    /// ```swift
    /// #Preview {
    ///     HomeView()
    ///         .previewSetup()
    /// }
    /// ```
    func previewSetup(appState: AppState = .preview) -> some View {
        modifier(PreviewSetupModifier(appState: appState))
    }

    /// Applies the preview environment in an unauthenticated state.
    ///
    /// Useful for previewing auth-flow screens like `WelcomeView` or `LoginView`.
    ///
    /// Usage:
    /// ```swift
    /// #Preview {
    ///     WelcomeView(onLogin: {}, onRegister: {}, onPhoneOTP: {})
    ///         .previewUnauthenticated()
    /// }
    /// ```
    func previewUnauthenticated() -> some View {
        modifier(PreviewSetupModifier(appState: .previewUnauthenticated))
    }
}

// MARK: - Device Preview Modifier

/// A `ViewModifier` that renders the wrapped view across multiple device sizes
/// for quick visual QA in Xcode Previews.
struct DevicePreviewModifier: ViewModifier {

    // MARK: - Devices

    private let devices: [(name: String, device: PreviewDevice)] = [
        ("iPhone 15 Pro", PreviewDevice(rawValue: "iPhone 15 Pro")),
        ("iPhone SE (3rd generation)", PreviewDevice(rawValue: "iPhone SE (3rd generation)")),
        ("iPhone 15 Pro Max", PreviewDevice(rawValue: "iPhone 15 Pro Max"))
    ]

    // MARK: - Body

    func body(content: Self.Content) -> some View {
        ForEach(devices, id: \.name) { device in
            content
                .previewDevice(device.device)
                .previewDisplayName(device.name)
        }
    }
}

extension View {

    /// Renders this view across multiple device sizes in Xcode Previews.
    ///
    /// Usage:
    /// ```swift
    /// #Preview {
    ///     HomeView()
    ///         .previewSetup()
    ///         .previewMultipleDevices()
    /// }
    /// ```
    func previewMultipleDevices() -> some View {
        modifier(DevicePreviewModifier())
    }
}
