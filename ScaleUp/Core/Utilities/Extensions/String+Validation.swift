import Foundation

extension String {
    var isValidEmail: Bool {
        let regex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return self.wholeMatch(of: regex) != nil
    }

    var isValidPassword: Bool {
        count >= 8 && count <= 128
    }

    var isValidPhone: Bool {
        let digitsOnly = self.filter(\.isNumber)
        return digitsOnly.count == 10 || digitsOnly.count == 12 // with country code
    }

    var formattedPhone: String {
        let digitsOnly = self.filter(\.isNumber)
        if digitsOnly.count == 10 {
            return "+91\(digitsOnly)"
        }
        return digitsOnly.hasPrefix("91") ? "+\(digitsOnly)" : "+91\(digitsOnly)"
    }

    /// Returns the trimmed string, or `nil` if it's empty after trimming.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
