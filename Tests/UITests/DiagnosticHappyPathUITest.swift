import XCTest

// UI test for the diagnostic happy path (Plan 5 Task 11).
//
// Setup gaps before this test will run green:
// 1. Register this file in the ScaleUpUITests target via Xcode
//    (File → Add Files to "ScaleUpUITests" — the target already exists).
// 2. The app needs to handle the launch environment keys below.
//    Add a test-mode branch in AppDelegate / @main entry point:
//      if ProcessInfo.processInfo.environment["UITEST_OBJECTIVE_TYPE"] != nil {
//          // seed objective + skip Steps 1-4, jump to Step 5
//      }
//    Without this, the test will land on Step 1 and fail to find the chips.

final class DiagnosticHappyPathUITest: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()

        // Seed state so the app starts at Step 5 (Objective) with a pre-built
        // upskilling objective. The app must read these to skip Steps 1-4.
        app.launchEnvironment["UITEST_OBJECTIVE_TYPE"] = "upskilling"
        app.launchEnvironment["UITEST_TARGET_SKILL"] = "product_manager"
        app.launchEnvironment["UITEST_SELF_RATINGS"] = "product_strategy:novice,data_analysis:novice"
        app.launchArguments += ["--uitest-mode", "--start-at-step5"]

        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Step 5 → Diagnostic entry

    func testDiagnosticHappyPath() throws {
        // Step 5: Objective screen — taxonomy chips should be visible.
        let chip = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Product Strategy'")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Taxonomy chip 'Product Strategy' should appear on Step 5")

        chip.tap()

        // At least one chip is now selected; Start Diagnostic CTA should be enabled.
        let startButton = app.buttons["Start Diagnostic"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "Start Diagnostic button should appear after chip selection")
        XCTAssertTrue(startButton.isEnabled, "Start Diagnostic button should be enabled after chip selection")
        startButton.tap()

        // Self-rating screen — competency rows visible.
        let selfRatingTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Rate yourself'")).firstMatch
        XCTAssertTrue(selfRatingTitle.waitForExistence(timeout: 5), "Self-rating screen should appear")

        // Select "Novice" for the first competency row.
        let noviceButton = app.buttons.matching(NSPredicate(format: "label == 'Novice'")).firstMatch
        XCTAssertTrue(noviceButton.waitForExistence(timeout: 3))
        noviceButton.tap()

        let submitRatings = app.buttons["Submit Ratings"]
        XCTAssertTrue(submitRatings.waitForExistence(timeout: 3))
        submitRatings.tap()

        // Loader / preparing screen.
        let loaderLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Preparing'")).firstMatch
        XCTAssertTrue(loaderLabel.waitForExistence(timeout: 8), "Loader should appear while pool is being built")

        // First diagnostic question.
        let questionText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '?'")).firstMatch
        XCTAssertTrue(questionText.waitForExistence(timeout: 15), "First question should appear")

        // Answer all questions by tapping the first option each time.
        var questionsAnswered = 0
        let maxQuestions = 20 // safety cap
        while questionsAnswered < maxQuestions {
            let optionA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A.'")).firstMatch
            if optionA.waitForExistence(timeout: 5) {
                optionA.tap()
                questionsAnswered += 1
                // Brief wait for next question or results transition.
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                break
            }
        }
        XCTAssertGreaterThan(questionsAnswered, 0, "Should have answered at least one question")

        // Insights generating screen.
        let generatingLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Generating' OR label CONTAINS[c] 'Analysing'")
        ).firstMatch
        XCTAssertTrue(generatingLabel.waitForExistence(timeout: 5), "Insights generating screen should appear")

        // Hero insight card.
        let heroCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'strength' OR label CONTAINS[c] 'Strong' OR label CONTAINS[c] 'foundation'")).firstMatch
        XCTAssertTrue(heroCard.waitForExistence(timeout: 20), "Hero insight card should appear after insights generation")

        // Results screen — at least one competency band visible.
        let resultsTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Results' OR label CONTAINS[c] 'Your Diagnostic'")).firstMatch
        XCTAssertTrue(resultsTitle.waitForExistence(timeout: 5), "Results screen title should appear")

        let bandLabel = app.staticTexts.matching(NSPredicate(format: "label == 'Familiar' OR label == 'Novice' OR label == 'Proficient'")).firstMatch
        XCTAssertTrue(bandLabel.waitForExistence(timeout: 5), "At least one band label should appear on results screen")

        // CTA to continue to plan.
        let ctaButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Continue' OR label CONTAINS[c] 'View Plan'")).firstMatch
        XCTAssertTrue(ctaButton.waitForExistence(timeout: 5), "Continue CTA should be visible on results screen")
    }
}
