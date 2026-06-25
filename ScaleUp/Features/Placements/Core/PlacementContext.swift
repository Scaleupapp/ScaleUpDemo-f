import Foundation

/// Decoded shape from `GET /api/v2/me/context` (the persona resolver).
///
/// Additive and isolated: D2C users get `persona == "general"` and a nil
/// `placement` block, so nothing in the existing app changes. Only placement
/// (institution) users carry a non-nil `placement` context, which drives the
/// PlacementsRoot shell.
struct UserContext: Codable {
    let persona: String
    let placement: PlacementContext?

    var isPlacement: Bool { persona == "placement" }
}

struct PlacementContext: Codable {
    let institution: PlacementInstitution
    let cohort: PlacementCohort
    let placementSeason: PlacementSeason
    let objective: PlacementObjective
}

struct PlacementInstitution: Codable {
    let id: String
    let name: String
    let logoUrl: String?
    let brandColor: String?
}

struct PlacementCohort: Codable {
    let id: String
    let year: String
    let label: String

    /// Friendly label for the backend `year` enum (`final` / `pre_final`).
    var yearLabel: String {
        switch year {
        case "final":     return "Final year"
        case "pre_final": return "Pre-final year"
        default:          return year
        }
    }
}

struct PlacementSeason: Codable {
    /// ISO-8601 string (or nil). The v2 API client decodes with a plain
    /// `JSONDecoder` (no ISO date strategy), so we keep this as a String and
    /// parse it in the view via `PlacementDate`.
    let deadline: String?
}

struct PlacementObjective: Codable {
    let locked: Bool
}

/// Small ISO-8601 date helpers for the placement deadline (which arrives as a
/// raw string — see `PlacementSeason.deadline`).
enum PlacementDate {
    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: iso) { return d }
        let plain = ISO8601DateFormatter()
        return plain.date(from: iso)
    }

    /// Whole days from now until `iso` (negative if past). Nil if unparseable.
    static func daysUntil(_ iso: String?) -> Int? {
        guard let date = parse(iso) else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }

    /// "1 Dec 2026"-style medium date string. Nil if unparseable.
    static func medium(_ iso: String?) -> String? {
        guard let date = parse(iso) else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
