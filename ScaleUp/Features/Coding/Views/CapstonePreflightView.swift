import SwiftUI

/// Pre-flight checklist before the learner pairs to a laptop (spec §7.2 step 2).
/// Visually distinct from a regular task screen: the capstone is a 60-90 min
/// commitment, and the brief is the contract. Heavy emphasis on the brief, a
/// readable "what you're agreeing to" checklist, and an honor-code banner.
struct CapstonePreflightView: View {
    let bundle: CapstoneLibraryEntry
    let onClose: () -> Void

    @State private var checks: PreflightChecks = .init()
    @State private var starting = false
    @State private var startResponse: CapstoneStartResponse?
    @State private var error: String?

    struct PreflightChecks {
        var laptopReady = false
        var quietBlock = false
        var networkOk = false

        var allOk: Bool { laptopReady && quietBlock && networkOk }
    }

    /// Pull the title out of the brief's first line (we don't have a separate
    /// `title` field on bundles — the first line is always the human title).
    private var briefTitle: String {
        let first = bundle.brief
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? bundle.brief
        return first.trimmingCharacters(in: .whitespaces)
    }

    private var briefBody: String {
        let parts = bundle.brief
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count > 1 else { return "" }
        return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroCard
                    briefCard
                    if let parallel = bundle.interviewParallel, !parallel.isEmpty {
                        interviewParallelCard(parallel)
                    }
                    checklistCard
                    integrityBanner
                    Spacer(minLength: 24)
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom) {
                startButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }
            .navigationTitle("Pre-flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onClose() } label: { Image(systemName: "xmark") }
                }
            }
            .alert("Couldn't start", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .sheet(item: Binding(
                get: { startResponse },
                set: { startResponse = $0 }
            )) { resp in
                CapstonePairView(bundle: bundle, startResponse: resp, onClose: onClose)
            }
        }
    }

    // MARK: - Hero (title + meta tags)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill").font(.caption.weight(.bold))
                Text("Capstone")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.tint)

            Text(briefTitle)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            FlowChips {
                Chip(icon: difficultyIcon, text: bundle.difficulty.rawValue.capitalized, tone: difficultyTone)
                Chip(icon: "clock", text: "\(bundle.timeBudgetMinutes) min")
                Chip(icon: "chevron.left.forwardslash.chevron.right", text: bundle.language.capitalized)
                if let stack = bundle.stackVariant { Chip(icon: "shippingbox", text: stack) }
                Chip(icon: "person.fill", text: bundle.roleTrack.rawValue.uppercased())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var difficultyIcon: String {
        switch bundle.difficulty.rawValue {
        case "easy":   return "circle.fill"
        case "medium": return "circle.lefthalf.filled"
        case "hard":   return "circle.dotted"
        default:       return "circle"
        }
    }

    enum ChipTone { case neutral, ok, warn, info }
    private var difficultyTone: ChipTone {
        switch bundle.difficulty.rawValue {
        case "easy":   return .ok
        case "medium": return .info
        case "hard":   return .warn
        default:       return .neutral
        }
    }

    // MARK: - Brief (the spec) — full, no truncation

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What you'll build", systemImage: "doc.text.below.ecg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            if briefBody.isEmpty {
                Text(bundle.brief)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(briefBody)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Interview parallel

    private func interviewParallelCard(_ parallel: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "briefcase.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("INTERVIEW PARALLEL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.tint)
                Text(parallel)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Before you start")
                .font(.headline)
            checkRow(
                icon: "laptopcomputer",
                title: "Your laptop is open and plugged in",
                subtitle: "You'll work on the laptop; the phone is your timer.",
                isOn: $checks.laptopReady
            )
            Divider().padding(.leading, 36)
            checkRow(
                icon: "clock.badge.checkmark",
                title: "You have \(bundle.timeBudgetMinutes) minutes uninterrupted",
                subtitle: "Sessions can't pause indefinitely — short breaks only.",
                isOn: $checks.quietBlock
            )
            Divider().padding(.leading, 36)
            checkRow(
                icon: "wifi",
                title: "Stable Wi-Fi for Compass + test runs",
                subtitle: "Disconnections during grading may abort the session.",
                isOn: $checks.networkOk
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func checkRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemBackground))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
    }

    // MARK: - Integrity banner

    private var integrityBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Closed-book session")
                    .font(.subheadline.weight(.semibold))
                Text("This session is recorded. Use Compass (built-in AI pair) freely — outside AI tools defeat the purpose and will lower your integrity score.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            Task { await start() }
        } label: {
            HStack(spacing: 10) {
                if starting {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    Image(systemName: "laptopcomputer.and.iphone")
                }
                Text(starting ? "Starting…" : "Start on laptop")
                    .fontWeight(.semibold)
                if !starting {
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(checks.allOk && !starting ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: checks.allOk ? Color.accentColor.opacity(0.3) : .clear, radius: 12, y: 4)
        }
        .disabled(!checks.allOk || starting)
    }

    // MARK: - Start

    private func start() async {
        starting = true
        defer { starting = false }
        do {
            startResponse = try await CapstoneService.shared.start(bundleId: bundle.bundleId)
        } catch CapstoneServiceError.noCodingTrackForObjective {
            error = "Coding capstones aren't available for your current objective."
        } catch CapstoneServiceError.notACapstone {
            error = "This bundle isn't a capstone — only daily drills are available."
        } catch V2APIError.httpError(let status, let data) {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (body?["message"] as? String) ?? (body?["error"] as? String)
            if status == 429 {
                error = "You're tapping too fast — wait a few seconds and try again."
            } else if status >= 500 {
                error = "Server hiccup (\(status)). Try again in a moment."
            } else if let detail {
                error = detail
            } else {
                error = "Couldn't start (HTTP \(status))."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Inline chip + flow layout

private struct Chip: View {
    let icon: String
    let text: String
    var tone: CapstonePreflightView.ChipTone = .neutral

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(background))
        .foregroundStyle(foreground)
    }

    private var background: Color {
        switch tone {
        case .ok:      return Color.green.opacity(0.18)
        case .warn:    return Color.orange.opacity(0.18)
        case .info:    return Color.accentColor.opacity(0.18)
        case .neutral: return Color(.tertiarySystemBackground)
        }
    }
    private var foreground: Color {
        switch tone {
        case .ok:      return Color.green
        case .warn:    return Color.orange
        case .info:    return Color.accentColor
        case .neutral: return Color.primary
        }
    }
}

/// Minimal flow layout — wraps chips onto multiple lines without horizontal
/// scroll. Adapts to whatever width the parent provides.
private struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        CapstoneChipFlow(spacing: 6) { content }
    }
}

private struct CapstoneChipFlow: Layout {
    let spacing: CGFloat
    init(spacing: CGFloat) { self.spacing = spacing }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

// Identifiable conformance so .sheet(item:) accepts CapstoneStartResponse.
extension CapstoneStartResponse: Identifiable {
    public var id: String { sessionId }
}
