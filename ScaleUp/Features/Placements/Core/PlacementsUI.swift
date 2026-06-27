import SwiftUI

// MARK: - Placement shared UI primitives
//
// Small, token-driven building blocks shared across the placement screens
// (Campus / Library / Home / Results). Placement-scoped on purpose — these are
// not part of the D2C (V2) component set and must not change D2C rendering.

/// A small tinted rounded-square chip showing an entity's first letter, used
/// instead of a generic building glyph.
struct MonogramChip: View {
    let text: String
    var size: CGFloat = 38
    var tint: Color = ColorTokens.gold

    private var letter: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : trimmed.prefix(1).uppercased()
    }

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.42, weight: .bold, design: .default))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Placement status pill with a consistent colour mapping everywhere:
/// open → green, upcoming → gold, closed → grey, visited → muted.
struct StatusPill: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "open":    return ColorTokens.success
        case "closed":  return ColorTokens.textTertiary
        case "visited": return ColorTokens.textSecondary
        default:        return ColorTokens.gold   // "upcoming"
        }
    }

    private var label: String {
        status.prefix(1).uppercased() + status.dropFirst().lowercased()
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

/// Uppercase, tracked, gold 11pt section eyebrow used to label groups.
struct SectionEyebrow: View {
    let label: String

    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(ColorTokens.gold)
    }
}

/// A centered, quiet empty state with one directive line of guidance.
struct PlacementEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 48, height: 48)
                .background(ColorTokens.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Text(message)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Placement card chrome

extension View {
    /// Placement card chrome: surface fill, ~14pt radius, 16pt inner padding,
    /// 1px hairline. Kept separate from `v2Card()` so the placement look can
    /// evolve without touching D2C cards.
    func placementCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ColorTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ColorTokens.border, lineWidth: 1)
            )
    }
}
