import XCTest

// MARK: - UI Test Helpers

/// Convenience extensions on XCUIApplication for common UI test operations.
extension XCUIApplication {

    // MARK: - Launch Configurations

    /// Launches the app in an authenticated state, bypassing the auth flow.
    ///
    /// Uses launch arguments that the app can check to skip real authentication
    /// and inject a mock authenticated session.
    func launchWithAuth() {
        launchArguments += [
            "--uitesting",
            "--skip-auth",
            "--mock-user"
        ]
        launch()
    }

    /// Launches the app with a clean state, clearing any persisted data.
    ///
    /// Useful for testing the unauthenticated / first-launch experience.
    func launchClean() {
        launchArguments += [
            "--uitesting",
            "--reset-state"
        ]
        launch()
    }

    // MARK: - Element Waiting

    /// Waits for a given element to exist within the specified timeout.
    ///
    /// - Parameters:
    ///   - element: The `XCUIElement` to wait for.
    ///   - timeout: Maximum time to wait in seconds. Defaults to 5.
    /// - Returns: `true` if the element appeared within the timeout, `false` otherwise.
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    // MARK: - Text Entry

    /// Taps a text field identified by its accessibility identifier and types the given text.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the text field.
    ///   - text: The string to type into the field.
    func typeInTextField(identifier: String, text: String) {
        let textField = textFields[identifier]

        if textField.waitForExistence(timeout: 5) {
            textField.tap()
            textField.typeText(text)
            return
        }

        // Fallback: try secure text fields (for password inputs)
        let secureField = secureTextFields[identifier]
        if secureField.waitForExistence(timeout: 3) {
            secureField.tap()
            secureField.typeText(text)
        }
    }

    // MARK: - Tab Navigation

    /// Selects a tab by its label in the tab bar.
    ///
    /// - Parameter label: The label text of the tab button (e.g., "Home", "Discover").
    func selectTab(_ label: String) {
        let tabButton = tabBars.buttons[label]
        if tabButton.waitForExistence(timeout: 5) {
            tabButton.tap()
        }
    }

    // MARK: - Alerts

    /// Dismisses any system alert by tapping the button with the given label.
    ///
    /// - Parameter buttonLabel: The label of the alert button to tap. Defaults to "Allow".
    func dismissAlert(buttonLabel: String = "Allow") {
        let alert = alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let button = alert.buttons[buttonLabel]
            if button.exists {
                button.tap()
            }
        }
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {

    /// Clears any existing text in a text field, then types the new value.
    ///
    /// - Parameter text: The string to enter after clearing.
    func clearAndType(_ text: String) {
        guard waitForExistence(timeout: 5) else { return }

        tap()

        // Select all existing text and delete it
        if let existingValue = value as? String, !existingValue.isEmpty {
            let selectAll = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
            typeText(selectAll)
        }

        typeText(text)
    }

    /// Waits for the element to exist and then verifies it is hittable.
    ///
    /// - Parameter timeout: Maximum time to wait. Defaults to 5 seconds.
    /// - Returns: `true` if the element exists and is hittable.
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        guard waitForExistence(timeout: timeout) else { return false }
        return isHittable
    }
}

// MARK: - XCTestCase Helpers

extension XCTestCase {

    /// Creates a configured `XCUIApplication` instance for UI testing.
    ///
    /// - Parameter authenticated: Whether to launch in authenticated mode.
    /// - Returns: A configured but not yet launched `XCUIApplication`.
    func makeApp(authenticated: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"]

        if authenticated {
            app.launchArguments += ["--skip-auth", "--mock-user"]
        }

        return app
    }
}
