import Foundation

// MARK: - Pending Employer

/// A company that signed up for the "Hire from ScaleUp" talent marketplace
/// and is awaiting admin approval to gain "contact" access.
struct PendingEmployer: Codable, Sendable, Identifiable {
    var id: String = ""
    var email: String = ""
    var companyName: String = ""
    var name: String = ""
    var title: String? = nil
    var linkedIn: String? = nil
    var createdAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, companyName, name, title, linkedIn, createdAt
    }
}
