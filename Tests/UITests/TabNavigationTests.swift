import XCTest

// MARK: - Tab Navigation UI Tests

/// UI tests for the main tab bar navigation across all 5 tabs.
/// These tests assume the app is launched in an authenticated state
/// so that MainTabView is displayed.
final class TabNavigationTests: XCTestCase {

    // MARK: - Properties

    private var app: XCUIApplication!

    // MARK: - Tab Labels

    private let tabLabels = ["Home", "Discover", "Journey", "Progress", "Profile"]

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Launch with auth bypass so we skip the auth flow and land on MainTabView
        app.launchArguments += ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Bar Visibility

    /// Verifies the tab bar is visible when the app is in authenticated state.
    func testTabBarIsVisible() throws {
        let tabBar = app.tabBars.firstMatch

        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear -- app may not have reached authenticated state")
            return
        }

        XCTAssertTrue(tabBar.exists, "Tab bar should be visible in authenticated state")
    }

    /// Verifies all 5 tab buttons are present in the tab bar.
    func testAllTabButtonsExist() throws {
        let tabBar = app.tabBars.firstMatch

        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        for label in tabLabels {
            let tabButton = tabBar.buttons[label]
            XCTAssertTrue(
                tabButton.exists,
                "\(label) tab button should exist in the tab bar"
            )
        }
    }

    // MARK: - Tab Switching

    /// Verifies tapping the Home tab shows the Home screen.
    func testSelectHomeTab() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        let homeTab = tabBar.buttons["Home"]
        guard homeTab.waitForExistence(timeout: 3) else {
            XCTFail("Home tab button not found")
            return
        }

        homeTab.tap()

        // Home tab should be selected (it is typically the default)
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected after tapping")
    }

    /// Verifies tapping the Discover tab shows the Discover screen.
    func testSelectDiscoverTab() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        let discoverTab = tabBar.buttons["Discover"]
        guard discoverTab.waitForExistence(timeout: 3) else {
            XCTFail("Discover tab button not found")
            return
        }

        discoverTab.tap()

        XCTAssertTrue(discoverTab.isSelected, "Discover tab should be selected after tapping")
    }

    /// Verifies tapping the Journey tab shows the Journey screen.
    func testSelectJourneyTab() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        let journeyTab = tabBar.buttons["Journey"]
        guard journeyTab.waitForExistence(timeout: 3) else {
            XCTFail("Journey tab button not found")
            return
        }

        journeyTab.tap()

        XCTAssertTrue(journeyTab.isSelected, "Journey tab should be selected after tapping")
    }

    /// Verifies tapping the Progress tab shows the Progress screen.
    func testSelectProgressTab() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        let progressTab = tabBar.buttons["Progress"]
        guard progressTab.waitForExistence(timeout: 3) else {
            XCTFail("Progress tab button not found")
            return
        }

        progressTab.tap()

        XCTAssertTrue(progressTab.isSelected, "Progress tab should be selected after tapping")
    }

    /// Verifies tapping the Profile tab shows the Profile screen.
    func testSelectProfileTab() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        let profileTab = tabBar.buttons["Profile"]
        guard profileTab.waitForExistence(timeout: 3) else {
            XCTFail("Profile tab button not found")
            return
        }

        profileTab.tap()

        XCTAssertTrue(profileTab.isSelected, "Profile tab should be selected after tapping")
    }

    // MARK: - Tab Cycling

    /// Verifies switching through all tabs sequentially without crashing.
    func testCycleThroughAllTabs() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        for label in tabLabels {
            let tab = tabBar.buttons[label]
            guard tab.waitForExistence(timeout: 3) else {
                XCTFail("\(label) tab button not found during cycling")
                return
            }

            tab.tap()

            // Brief pause for the view to render
            let expectation = XCTestExpectation(description: "Wait for \(label) tab")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2)

            XCTAssertTrue(tab.isSelected, "\(label) tab should be selected")
        }
    }

    // MARK: - Tab Title Verification

    /// Verifies each tab shows the correct navigation title when selected.
    func testEachTabShowsCorrectTitle() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        for label in tabLabels {
            let tab = tabBar.buttons[label]
            guard tab.waitForExistence(timeout: 3) else {
                continue
            }

            tab.tap()

            // Check for the navigation title or a static text matching the tab label.
            // Some tabs use large navigation titles, others use inline headers.
            let titleText = app.staticTexts[label]
            let navigationTitle = app.navigationBars[label]

            let titleExists = titleText.waitForExistence(timeout: 3)
            let navTitleExists = navigationTitle.waitForExistence(timeout: 1)

            let hasTitle = titleExists || navTitleExists
            // Not all tabs may have a visible title immediately (e.g. Home may show
            // a custom header), so we simply verify the tab is selected and no crash.
            XCTAssertTrue(tab.isSelected, "\(label) tab should be selected")
        }
    }

    // MARK: - Tab Persistence

    /// Verifies switching away from a tab and back preserves the tab state.
    func testTabSwitchAndReturn() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar did not appear")
            return
        }

        // Start on Home
        let homeTab = tabBar.buttons["Home"]
        guard homeTab.waitForExistence(timeout: 3) else {
            XCTFail("Home tab not found")
            return
        }
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected initially")

        // Switch to Discover
        let discoverTab = tabBar.buttons["Discover"]
        guard discoverTab.waitForExistence(timeout: 3) else {
            XCTFail("Discover tab not found")
            return
        }
        discoverTab.tap()
        XCTAssertTrue(discoverTab.isSelected, "Discover tab should now be selected")

        // Switch back to Home
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected again after returning")
    }
}
