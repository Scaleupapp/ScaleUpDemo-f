import XCTest
@testable import ScaleUp

@MainActor
final class CalibrationPromptStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: CalibrationPromptStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "calib-test-\(UUID().uuidString)")!
        store = CalibrationPromptStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    func test_initiallyVisible() {
        XCTAssertTrue(store.shouldShow())
        XCTAssertEqual(store.promptCount, 0)
    }

    func test_recordShown_incrementsCount() {
        store.recordShown()
        XCTAssertEqual(store.promptCount, 1)
    }

    func test_dismiss_setsQuietPeriod() {
        store.recordDismissed()
        XCTAssertFalse(store.shouldShow())
        // simulate +15 days
        let later = CalibrationPromptStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_700_000_000 + 15 * 86_400) })
        XCTAssertTrue(later.shouldShow())
    }

    func test_threePromptsThenAutoStop() {
        for _ in 0..<3 { store.recordShown() }
        XCTAssertFalse(store.shouldShow())
    }
}
