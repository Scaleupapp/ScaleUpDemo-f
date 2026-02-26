import XCTest
@testable import ScaleUp

// MARK: - Formatters Tests

/// Tests for `Formatters` utility methods covering duration formatting,
/// count formatting, relative date formatting, and time-ago formatting.
final class FormattersTests: XCTestCase {

    // MARK: - formatDuration

    func testFormatDuration_zeroMinutes() {
        let result = Formatters.formatDuration(minutes: 0)
        // 0 minutes may return "0m" or similar depending on formatter
        XCTAssertFalse(result.isEmpty, "Should return a non-empty string for 0 minutes")
    }

    func testFormatDuration_thirtyMinutes() {
        let result = Formatters.formatDuration(minutes: 30)
        XCTAssertTrue(result.contains("30"), "Should contain '30' for 30 minutes, got: \(result)")
        XCTAssertTrue(result.contains("m") || result.contains("min"),
                      "Should contain minute unit, got: \(result)")
    }

    func testFormatDuration_sixtyMinutes() {
        let result = Formatters.formatDuration(minutes: 60)
        XCTAssertTrue(result.contains("1"), "Should contain '1' for 1 hour, got: \(result)")
        XCTAssertTrue(result.contains("h") || result.contains("hr"),
                      "Should contain hour unit, got: \(result)")
    }

    func testFormatDuration_ninetyMinutes() {
        let result = Formatters.formatDuration(minutes: 90)
        XCTAssertTrue(result.contains("1"), "Should contain '1' hour, got: \(result)")
        XCTAssertTrue(result.contains("30"), "Should contain '30' minutes, got: \(result)")
    }

    func testFormatDuration_hundredFiftyMinutes() {
        let result = Formatters.formatDuration(minutes: 150)
        XCTAssertTrue(result.contains("2"), "Should contain '2' hours, got: \(result)")
        XCTAssertTrue(result.contains("30"), "Should contain '30' minutes, got: \(result)")
    }

    func testFormatDuration_largeValue() {
        let result = Formatters.formatDuration(minutes: 720)
        XCTAssertTrue(result.contains("12"), "Should contain '12' hours, got: \(result)")
    }

    // MARK: - formatCount

    func testFormatCount_zero() {
        XCTAssertEqual(Formatters.formatCount(0), "0")
    }

    func testFormatCount_smallNumber() {
        XCTAssertEqual(Formatters.formatCount(42), "42")
    }

    func testFormatCount_nineNineNine() {
        XCTAssertEqual(Formatters.formatCount(999), "999")
    }

    func testFormatCount_oneThousand() {
        XCTAssertEqual(Formatters.formatCount(1000), "1K")
    }

    func testFormatCount_twelveHundred() {
        XCTAssertEqual(Formatters.formatCount(1200), "1.2K")
    }

    func testFormatCount_fifteenHundred() {
        XCTAssertEqual(Formatters.formatCount(1500), "1.5K")
    }

    func testFormatCount_tenThousand() {
        XCTAssertEqual(Formatters.formatCount(10000), "10K")
    }

    func testFormatCount_oneMillion() {
        XCTAssertEqual(Formatters.formatCount(1_000_000), "1M")
    }

    func testFormatCount_threePointFiveMillion() {
        XCTAssertEqual(Formatters.formatCount(3_500_000), "3.5M")
    }

    func testFormatCount_oneHundredMillion() {
        XCTAssertEqual(Formatters.formatCount(100_000_000), "100M")
    }

    func testFormatCount_exactThousandMultiple() {
        // 5000 -> "5K" (no decimal)
        XCTAssertEqual(Formatters.formatCount(5000), "5K")
    }

    func testFormatCount_exactMillionMultiple() {
        // 2000000 -> "2M" (no decimal)
        XCTAssertEqual(Formatters.formatCount(2_000_000), "2M")
    }

    // MARK: - formatRelativeDate

    func testFormatRelativeDate_validISOString_returnsNonEmpty() {
        // Use a recent date so the relative formatter has something meaningful
        let isoString = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let result = Formatters.formatRelativeDate(isoString)
        XCTAssertFalse(result.isEmpty, "Should return a non-empty relative date string")
    }

    func testFormatRelativeDate_invalidString_returnsOriginal() {
        let result = Formatters.formatRelativeDate("not-a-date")
        XCTAssertEqual(result, "not-a-date",
                       "Invalid ISO string should return the original string")
    }

    func testFormatRelativeDate_fractionalSeconds() {
        // Test with fractional seconds (the format the app uses)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-7200))
        let result = Formatters.formatRelativeDate(isoString)
        XCTAssertFalse(result.isEmpty)
        // Should not return the raw ISO string back (meaning parsing succeeded)
        XCTAssertNotEqual(result, isoString)
    }

    func testFormatRelativeDate_withoutFractionalSeconds() {
        // Test with standard ISO 8601 (without fractional seconds)
        let isoString = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
        let result = Formatters.formatRelativeDate(isoString)
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, isoString)
    }

    // MARK: - formatTimeAgo

    func testFormatTimeAgo_justNow() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-10))
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "just now")
    }

    func testFormatTimeAgo_minutesAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-300)) // 5 min
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "5m ago")
    }

    func testFormatTimeAgo_hoursAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-7200)) // 2 hours
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "2h ago")
    }

    func testFormatTimeAgo_daysAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-259200)) // 3 days
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "3d ago")
    }

    func testFormatTimeAgo_moreThanAWeek_returnsFormattedDate() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-864000)) // 10 days
        let result = Formatters.formatTimeAgo(isoString)
        // Should return a formatted date string like "Jan 15, 2025" not "Xd ago"
        XCTAssertFalse(result.hasSuffix("ago"),
                       "More than a week should return formatted date, got: \(result)")
    }

    func testFormatTimeAgo_invalidString_returnsOriginal() {
        let result = Formatters.formatTimeAgo("invalid")
        XCTAssertEqual(result, "invalid")
    }

    func testFormatTimeAgo_oneMinuteAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-60))
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "1m ago")
    }

    func testFormatTimeAgo_oneHourAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-3600))
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "1h ago")
    }

    func testFormatTimeAgo_oneDayAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-86400))
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "1d ago")
    }

    func testFormatTimeAgo_sixDaysAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: Date().addingTimeInterval(-518400)) // 6 days
        let result = Formatters.formatTimeAgo(isoString)
        XCTAssertEqual(result, "6d ago")
    }

    // MARK: - Shared Formatter Instances

    func testISO8601Formatter_parsesWithFractionalSeconds() {
        let dateString = "2025-01-15T10:30:00.123Z"
        let date = Formatters.iso8601Formatter.date(from: dateString)
        XCTAssertNotNil(date, "Should parse ISO 8601 with fractional seconds")
    }

    func testShortDateFormatter_outputsExpectedFormat() {
        // Create a known date
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let result = Formatters.shortDateFormatter.string(from: date)
        XCTAssertEqual(result, "Jan 15, 2025")
    }
}
