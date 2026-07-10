import XCTest

/// Drives the full UGC-moderation walkthrough for the App Review screen
/// recording (App Store Guideline 1.2): shows the Terms/EULA on the Welcome
/// screen, signs in, opens a study note authored by another user, reports it,
/// blocks its author, and shows the Blocked Accounts management screen.
///
/// Paced with deliberate pauses so the captured video is easy to follow. Run
/// while `xcrun simctl io <udid> recordVideo` is capturing the same simulator.
final class ModerationRecordingTest: XCTestCase {

    // "Software" — a study note authored by another user (Shivam Kushwaha),
    // domain "software" so it matches the demo account's objective and renders
    // in the Learn tab / search.
    private let noteContentId = "69ce40d0aec0622b71d098d0"
    private let searchTerm = "Software"

    func testModerationWalkthrough() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        // Present the note's ⋯ options as an action sheet (reliable to automate),
        // and deterministically auto-open the target note on launch.
        app.launchEnvironment["UITEST_MODERATION_SHEET"] = "1"
        app.launchEnvironment["UITEST_OPEN_CONTENT"] = noteContentId

        addUIInterruptionMonitor(withDescription: "system-alert") { alert in
            for label in ["Allow", "Allow While Using App", "Allow Once", "OK", "Continue", "Don’t Allow", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        app.launch()

        func pause(_ s: UInt32) { sleep(s) }
        func snap(_ name: String) {
            let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            att.name = name
            att.lifetime = .keepAlways
            add(att)
        }

        // ── 1. Welcome — Terms of Service & Privacy Policy shown before login ──
        pause(5)
        snap("01-welcome-terms")

        // ── 2. Sign in with the review demo account ──
        let emailBtn = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign In with Email"))
            .firstMatch
        if emailBtn.waitForExistence(timeout: 8) {
            emailBtn.tap()
            pause(2)

            let email = app.textFields.firstMatch
            if email.waitForExistence(timeout: 6) {
                email.tap(); pause(1)
                email.typeText("admin@scaleup.io")
            }
            let pwd = app.secureTextFields.firstMatch
            if pwd.waitForExistence(timeout: 4) {
                pwd.tap(); pause(1)
                pwd.typeText("Admin@123456")
            }
            pause(1)
            snap("02-credentials")

            let signIn = app.buttons["Sign In"].firstMatch
            if signIn.waitForExistence(timeout: 3) { signIn.tap() }
        }

        // ── 3. Wait for the home/main tab to load ──
        let tabbar = app.tabBars.firstMatch
        _ = tabbar.waitForExistence(timeout: 25)
        pause(4)
        snap("03-home")

        // ── 4/5. The note (a study note by another user) auto-opens on launch
        // via UITEST_OPEN_CONTENT — wait for it. This avoids the flaky,
        // network-timing-dependent Learn recommendations/search.
        let more = app.buttons["notesMoreMenu"].firstMatch
        _ = more.waitForExistence(timeout: 25)
        pause(3)
        snap("05-note-open")

        // ── 6. Report the note ──
        _ = moderate(app, item: "Report Note", confirm: "Inappropriate",
                     menuSnap: { snap("06a-menu") }, preSnap: { snap("06-report-reasons") })
        pause(4)                       // toast: "Reported. Thanks…"
        snap("07-reported")

        // ── 7. Block the note's author (Shivam Kushwaha) ──
        pause(1)
        _ = moderate(app, item: "Block Author", confirm: "Block",
                     menuSnap: {}, preSnap: { snap("08-block-confirm") })
        pause(4)                       // toast: "Blocked. You won't see…"
        snap("09-blocked")

        // ── 8. Show the Blocked Accounts management screen ──
        // Dismiss the note SHEET via its "Close" button (avoid the nav-bar
        // Compass glyph, which would open the tutor).
        let closeBtn = app.buttons["Close"].firstMatch
        if closeBtn.waitForExistence(timeout: 5) { closeBtn.tap() }
        pause(2)
        // If a Compass tutor sheet is somehow open, close it too.
        if app.staticTexts["Compass · Tutor"].firstMatch.exists {
            let c2 = app.buttons["Close"].firstMatch
            if c2.exists { c2.tap(); pause(1) }
        }

        // You tab (index 3): Home, Learn, Compass, You.
        let youTab = app.tabBars.firstMatch.buttons.element(boundBy: 3)
        if youTab.waitForExistence(timeout: 6) { youTab.tap() }
        pause(4)
        snap("10-you")

        // The top-right gear is nested inside the profile button, so use the
        // dedicated "Settings" row lower on the You screen (scroll to reveal it).
        let settingsRow = app.buttons["settingsRow"].firstMatch
        for _ in 0..<5 {
            if settingsRow.exists && settingsRow.isHittable { break }
            app.swipeUp(); pause(1)
        }
        if settingsRow.waitForExistence(timeout: 4) { settingsRow.tap() }
        pause(3)
        snap("11-settings")

        var blockedRow = app.buttons["blockedAccountsRow"].firstMatch
        if !blockedRow.waitForExistence(timeout: 4) {
            app.swipeUp(); pause(1)
            blockedRow = app.buttons["blockedAccountsRow"].firstMatch
        }
        if blockedRow.exists {
            blockedRow.tap()
        } else {
            let byLabel = app.staticTexts["Blocked Accounts"].firstMatch
            if byLabel.waitForExistence(timeout: 3) { byLabel.tap() }
        }
        pause(4)
        snap("12-blocked-accounts-list")
    }

    // MARK: - Navigation helpers

    private func gotoLearn(_ app: XCUIApplication, _ tabbar: XCUIElement) {
        let searchField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] %@", "Search your learning")
        ).firstMatch

        for _ in 0..<3 {
            // Prefer the index (label-based lookup proved unreliable).
            let byIndex = tabbar.buttons.element(boundBy: 1)
            if byIndex.exists { byIndex.tap() }
            else { tabbar.buttons["Learn"].firstMatch.tap() }

            if searchField.waitForExistence(timeout: 5) { return }   // on Learn now
        }
    }

    /// Opens the target note. The Learn recommendations load asynchronously, so
    /// first wait for the tagged card to appear in the loaded rails and tap it;
    /// only if that never loads, fall back to the search bar (with retries).
    private func openNoteViaSearch(_ app: XCUIApplication) {
        let target = app.descendants(matching: .any)["open-\(noteContentId)"]

        // 1. Wait for Learn content to load (the tagged card exists once
        //    recommendations arrive), revealing lower rails as we wait.
        for _ in 0..<4 {
            if target.waitForExistence(timeout: 8) { break }
            app.swipeUp(); sleep(1)
        }

        // 2. Tap the tagged rail/hero card, scrolling it into view if needed.
        if target.exists {
            if target.isHittable { target.tap(); return }
            for _ in 0..<5 {
                app.swipeUp(); sleep(1)
                if target.isHittable { target.tap(); return }
            }
            target.tap(); return   // last resort: rely on XCUITest auto-scroll
        }

        // 3. Fallback: search bar with retries (recommendations may lag).
        let field = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] %@", "Search your learning")
        ).firstMatch
        let f = field.exists ? field : app.textFields.firstMatch
        if f.waitForExistence(timeout: 6) {
            for _ in 0..<3 {
                f.tap()
                f.typeText(searchTerm)
                sleep(3)
                if target.waitForExistence(timeout: 5), target.isHittable { target.tap(); return }
                let clear = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "clear")
                ).firstMatch
                if clear.exists { clear.tap() }
                sleep(3)
            }
        }
        if target.exists { target.tap() }
    }

    /// Opens the note's "⋯" menu and taps `item`, then confirms `confirm` in the
    /// resulting confirmationDialog. Retries the whole sequence until the dialog
    /// actually appears (the SwiftUI Menu can flake), so the action truly fires.
    /// Taps the note's "⋯" (which, under -uiTestModerationSheet, opens an action
    /// sheet), taps `item` ("Report Note" / "Block Author"), then confirms
    /// `confirm` in the follow-up confirmationDialog. Action sheets are reliably
    /// driven via `app.sheets` (unlike the flaky SwiftUI Menu).
    @discardableResult
    private func moderate(_ app: XCUIApplication, item: String, confirm: String,
                          menuSnap: () -> Void, preSnap: () -> Void) -> Bool {
        for _ in 0..<4 {
            let menu = app.buttons["notesMoreMenu"].firstMatch
            if menu.waitForExistence(timeout: 8) { menu.tap() }

            // First action sheet: "Report Note" / "Block Author" / "Cancel".
            let choice = app.sheets.buttons[item].firstMatch
            guard choice.waitForExistence(timeout: 5) else { sleep(1); continue }
            menuSnap()
            choice.tap()

            // Follow-up dialog (reasons for report; "Block <name>" for block),
            // presented ~0.4s later via asyncAfter.
            sleep(1)
            if app.sheets.firstMatch.waitForExistence(timeout: 5) {
                preSnap()
                tapSheetButton(app, contains: confirm)
                return true
            }
            sleep(1)
        }
        return false
    }

    /// Taps a button in a confirmationDialog by a label substring, avoiding Cancel.
    private func tapSheetButton(_ app: XCUIApplication, contains sub: String) {
        let inSheet = app.sheets.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", sub)
        ).firstMatch
        if inSheet.waitForExistence(timeout: 5) { inSheet.tap(); return }
        let anywhere = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@ AND label != %@", sub, "Cancel")
        ).firstMatch
        if anywhere.waitForExistence(timeout: 5) { anywhere.tap() }
    }
}
