import Foundation

// MARK: - Formatters

enum Formatters {

    // MARK: - Shared Instances

    nonisolated(unsafe) static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Formats dates as "Jan 15, 2025"
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    /// Formats time as "2:30 PM"
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Formats durations as "1h 30m"
    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    // MARK: - Convenience Methods

    /// Parses an ISO 8601 string and returns a relative date (e.g., "2h ago").
    static func formatRelativeDate(_ isoString: String) -> String {
        guard let date = parseISO(isoString) else { return isoString }
        return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Formats minutes into a human-readable duration (e.g., "1h 30m").
    static func formatDuration(minutes: Int) -> String {
        let interval = TimeInterval(minutes * 60)
        return durationFormatter.string(from: interval) ?? "\(minutes)m"
    }

    /// Formats a count into a compact representation (e.g., 1200 -> "1.2K").
    static func formatCount(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case 1_000..<1_000_000:
            let value = Double(count) / 1_000.0
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))K"
                : String(format: "%.1fK", value)
        default:
            let value = Double(count) / 1_000_000.0
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value))M"
                : String(format: "%.1fM", value)
        }
    }

    /// Parses an ISO 8601 string and returns a time-ago string (e.g., "2h ago").
    static func formatTimeAgo(_ isoString: String) -> String {
        guard let date = parseISO(isoString) else { return isoString }

        let seconds = Int(Date().timeIntervalSince(date))

        switch seconds {
        case ..<60:
            return "just now"
        case 60..<3_600:
            let minutes = seconds / 60
            return "\(minutes)m ago"
        case 3_600..<86_400:
            let hours = seconds / 3_600
            return "\(hours)h ago"
        case 86_400..<604_800:
            let days = seconds / 86_400
            return "\(days)d ago"
        default:
            return shortDateFormatter.string(from: date)
        }
    }

    // MARK: - Private

    private static func parseISO(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}
