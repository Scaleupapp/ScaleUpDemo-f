import Foundation

enum Timeline: String, Codable, Hashable {
    case oneMonth = "1_month"
    case threeMonths = "3_months"
    case sixMonths = "6_months"
    case oneYear = "1_year"
    case noDeadline = "no_deadline"
}
