import UIKit

// MARK: - Orientation Helper

/// Controls device orientation locking for fullscreen video playback.
/// Works with AppDelegate's `supportedInterfaceOrientationsFor` to restrict rotations.
enum OrientationHelper {

    /// The currently allowed orientation mask. Defaults to portrait.
    nonisolated(unsafe) static var orientationLock: UIInterfaceOrientationMask = .portrait

    /// Lock to landscape (left + right).
    @MainActor
    static func lockLandscape() {
        orientationLock = .landscape
        rotateDevice()
    }

    /// Lock to portrait only.
    @MainActor
    static func lockPortrait() {
        orientationLock = .portrait
        rotateDevice()
    }

    /// Reset to default (portrait).
    @MainActor
    static func resetToDefault() {
        orientationLock = .portrait
        rotateDevice()
    }

    // MARK: - Private

    @MainActor
    private static func rotateDevice() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))

        // Tell UIKit to re-evaluate supported orientations
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
