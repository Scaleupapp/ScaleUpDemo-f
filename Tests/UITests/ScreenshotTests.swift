import XCTest

/// Captures App Store screenshots by driving the real UI: logs in with the
/// demo account and walks the hero surfaces. Screenshots are attached to the
/// test result (.keepAlways) and exported from the .xcresult afterwards.
final class ScreenshotTests: XCTestCase {

    func testCaptureAppStoreScreens() throws {
        continueAfterFailure = true
        let app = XCUIApplication()

        // Auto-dismiss any system alerts (notifications permission, etc.)
        addUIInterruptionMonitor(withDescription: "system-alert") { alert in
            for label in ["Allow", "Allow While Using App", "Allow Once", "OK", "Continue"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        app.launch()

        func snap(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
        }
        func settle(_ s: UInt32 = 2) { sleep(s) }

        settle(4)
        snap("01-welcome")

        // → "Sign In with Email"
        let emailBtn = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign In with Email"))
            .firstMatch
        if emailBtn.waitForExistence(timeout: 6) { emailBtn.tap() }
        settle(2)

        // Fill credentials
        let email = app.textFields.firstMatch
        if email.waitForExistence(timeout: 6) {
            email.tap()
            email.typeText("admin@scaleup.io")
        }
        let pwd = app.secureTextFields.firstMatch
        if pwd.waitForExistence(timeout: 3) {
            pwd.tap()
            pwd.typeText("Admin@123456")
        }
        settle(1)
        snap("02-login")

        // Sign In
        let signIn = app.buttons["Sign In"].firstMatch
        if signIn.waitForExistence(timeout: 3) { signIn.tap() }

        // Home (allow network + plan load)
        settle(10)
        snap("03-home")
        settle(3)
        snap("04-home-b")

        // Walk the tab bar
        let tabbar = app.tabBars.firstMatch
        if tabbar.waitForExistence(timeout: 5) {
            let count = tabbar.buttons.count
            for i in 0..<count {
                let btn = tabbar.buttons.element(boundBy: i)
                if btn.exists {
                    btn.tap()
                    settle(4)
                    snap("05-tab-\(i)")
                }
            }
        } else {
            for name in ["Learn", "Compass", "You", "Home"] {
                let b = app.buttons[name].firstMatch
                if b.exists { b.tap(); settle(4); snap("05-\(name)") }
            }
        }
    }
}
