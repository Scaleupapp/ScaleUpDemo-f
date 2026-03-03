import XCTest
@testable import ScaleUp

final class ScaleUpTests: XCTestCase {
    func testColorTokensExist() {
        // Basic sanity check that design tokens are accessible
        XCTAssertNotNil(ColorTokens.gold)
        XCTAssertNotNil(ColorTokens.background)
    }
}
