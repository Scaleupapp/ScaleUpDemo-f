import SwiftUI

/// Proof Builder screen (agentic layer #8, flag `proof_builder`). Journey
/// view from GET /proof-journey: JD chip, 5-step checklist, status-driven
/// CTAs, nextProofSuggestion card. Create form (paste JD, ≥100 chars) when
/// no journey exists yet. Entry point is a card on V2CodingHubView.
struct ProofJourneyView: View {
    let onClose: () -> Void

    private enum LoadState {
        case loading
        /// 404 / network error surfaced while the sheet was already open —
        /// degrade quietly rather than showing a scary error screen.
        case unavailable
        case noJourney
        case journey(ProofJourney)
    }

    @State private var loadState: LoadState = .loading
    @State private var pollTask: Task<Void, Never>?

    // Create-form
    @State private var jdText = ""
    @State private var isSubmittingCreate = false
    @State private var createError: String?

    // Publish
    @State private var isPublishing = false
    @State private var publishError: String?

    // Building CTA
    @State private var showCapstoneFlow = false

    private static let minJDLength = 100

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .loading:
                    ProgressView().tint(ColorTokens.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable:
                    unavailableState
                case .noJourney:
                    createForm
                case .journey(let journey):
                    journeyView(journey)
                }
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Proof builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
            }
        }
        .task { await load() }
        .onDisappear { pollTask?.cancel() }
        .sheet(isPresented: $showCapstoneFlow) {
            CapstoneLibraryView()
        }
    }

    // MARK: - Load

    private func load(silent: Bool = false) async {
        if !silent { loadState = .loading }
        do {
            if let journey = try await ProofJourneyService.fetch() {
                loadState = .journey(journey)
                if ProofJourneyFormat.waitingStatuses.contains(journey.status) {
                    schedulePoll()
                }
            } else {
                loadState = .noJourney
            }
        } catch {
            if !silent { loadState = .unavailable }
        }
    }

    private func schedulePoll() {
        pollTask?.cancel()
        pollTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await load(silent: true)
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Text("This isn't available right now.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
            Button("Close", action: onClose)
                .font(V2Theme.small.weight(.semibold))
                .foregroundStyle(ColorTokens.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create form

    private var createForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Turn a JD into a proof")
                        .font(V2Theme.h2)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("Paste a job description. We'll extract the skills it wants, build a graded capstone, and publish a shareable proof page.")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .topLeading) {
                        if jdText.isEmpty {
                            Text("Paste the job description here…")
                                .font(V2Theme.small)
                                .foregroundStyle(ColorTokens.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $jdText)
                            .font(V2Theme.small)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 220)
                    }
                    .padding(Spacing.sm)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                    HStack {
                        Spacer()
                        Text("\(jdText.count) / \(Self.minJDLength) minimum")
                            .font(V2Theme.tiny)
                            .foregroundStyle(jdText.count >= Self.minJDLength ? ColorTokens.success : ColorTokens.textTertiary)
                    }
                }

                if let createError {
                    Text(createError).font(V2Theme.small).foregroundStyle(ColorTokens.error)
                }

                PrimaryButton(
                    title: "Start proof journey",
                    isLoading: isSubmittingCreate,
                    isDisabled: jdText.count < Self.minJDLength || isSubmittingCreate
                ) {
                    Task { await submitCreate() }
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
    }

    private func submitCreate() async {
        createError = nil
        isSubmittingCreate = true
        defer { isSubmittingCreate = false }
        do {
            let journey = try await ProofJourneyService.create(jdText: jdText)
            loadState = .journey(journey)
            if ProofJourneyFormat.waitingStatuses.contains(journey.status) { schedulePoll() }
        } catch {
            createError = "Couldn't start that journey — try again."
        }
    }

    // MARK: - Journey view

    private func journeyView(_ journey: ProofJourney) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                jdChip(journey.jdSummary)
                checklist(journey.steps)
                statusCTA(journey)
                if let publishError {
                    Text(publishError).font(V2Theme.small).foregroundStyle(ColorTokens.error)
                }
                if let suggestion = journey.nextProofSuggestion {
                    nextSuggestionCard(suggestion)
                }
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.top, 16)
        }
        .refreshable { await load() }
    }

    private func jdChip(_ summary: ProofJourneyJdSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill").font(.caption).foregroundStyle(ColorTokens.gold)
                Text(jdChipTitle(summary))
                    .font(V2Theme.h3)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }
            if !summary.skills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(summary.skills, id: \.self) { skill in
                            Text(skill)
                                .font(V2Theme.tiny)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(ColorTokens.gold.opacity(0.14)))
                                .foregroundStyle(ColorTokens.gold)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func jdChipTitle(_ summary: ProofJourneyJdSummary) -> String {
        switch (summary.role, summary.company) {
        case (let role?, let company?) where !role.isEmpty && !company.isEmpty:
            return "\(role) \u{00B7} \(company)"
        case (let role?, _) where !role.isEmpty:
            return role
        case (_, let company?) where !company.isEmpty:
            return company
        default:
            return "Job description"
        }
    }

    private func checklist(_ steps: [ProofJourneyStep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROOF PIPELINE").v2Eyebrow()
            VStack(spacing: 0) {
                ForEach(steps) { step in stepRow(step) }
            }
        }
    }

    private func stepRow(_ step: ProofJourneyStep) -> some View {
        HStack(spacing: 10) {
            stepIcon(step.status)
            Text(step.label)
                .font(V2Theme.small.weight(step.status == "now" ? .semibold : .regular))
                .foregroundStyle(step.status == "todo" ? ColorTokens.textTertiary : ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
        }
    }

    @ViewBuilder
    private func stepIcon(_ status: String) -> some View {
        switch status {
        case "done":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(ColorTokens.success)
        case "now":
            ProgressView().tint(ColorTokens.gold).frame(width: 16, height: 16)
        case "failed":
            Image(systemName: "xmark.circle.fill").foregroundStyle(ColorTokens.error)
        default:
            Image(systemName: "circle").foregroundStyle(ColorTokens.textTertiary)
        }
    }

    @ViewBuilder
    private func statusCTA(_ journey: ProofJourney) -> some View {
        switch journey.status {
        case "extracting", "capstone_pending":
            waitingRow("Extracting skills from your JD\u{2026}")
        case "grading":
            waitingRow("Grading your capstone\u{2026}")
        case "building":
            Button {
                showCapstoneFlow = true
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("Continue building")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        case "publishable":
            PrimaryButton(title: "Publish proof page", icon: "link", isLoading: isPublishing, isDisabled: isPublishing) {
                Task { await publish() }
            }
        case "published":
            if let token = journey.proofToken {
                publishedLink(token)
            }
        case "failed":
            Text("Something went wrong on this journey. Paste the JD again to try a fresh one.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.error)
        default:
            EmptyView()
        }
    }

    private func waitingRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().tint(ColorTokens.gold)
            Text(text).font(V2Theme.small).foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func publishedLink(_ token: String) -> some View {
        let text = ProofJourneyFormat.shareLinkText(token: token)
        let url = ProofJourneyFormat.shareURL(token: token)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(ColorTokens.success)
                Text("Proof published").font(V2Theme.small.weight(.semibold)).foregroundStyle(ColorTokens.textPrimary)
            }
            Text(text)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.gold)
                .lineLimit(1)
            if let url {
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share proof page")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(ColorTokens.surfaceElevated)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.medium).strokeBorder(ColorTokens.success.opacity(0.25), lineWidth: 1))
    }

    private func publish() async {
        publishError = nil
        isPublishing = true
        defer { isPublishing = false }
        do {
            let journey = try await ProofJourneyService.publish()
            loadState = .journey(journey)
        } catch V2APIError.httpError(let status, _) where status == 409 {
            publishError = "This proof isn't graded yet — check back shortly."
        } catch {
            publishError = "Couldn't publish — try again."
        }
    }

    private func nextSuggestionCard(_ suggestion: ProofJourneyNextSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT PROOF").v2Eyebrow()
            Text(suggestion.skill)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(suggestion.reason)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}
