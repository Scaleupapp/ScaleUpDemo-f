import SwiftUI

/// V2 Compass Tab — conversation-led, with inline configurator routing to detail pages.
///
/// Flow shown in mockup screen 09:
///   1. Compass: "Hi Nirpeksh — what do you want to do?"
///   2. User picks chip (e.g., "Quiz me") OR types
///   3. Compass replies + shows inline configurator card with topic/format/difficulty/count
///   4. User taps Start → routes to the detail page (quiz session, interview, etc.)
struct V2CompassView: View {
    @State private var vm = CompassViewModel()
    @Environment(V2TaskRouter.self) private var taskRouter
    /// Forwarded into the note-flow sheet — V2NoteFlowView pushes into the v1
    /// NotesDetailView, which requires AppState. Sheets don't reliably
    /// inherit @Observable env, so we re-inject explicitly.
    @Environment(AppState.self) private var appState
    @FocusState private var inputFocused: Bool

    /// Optional — the tab the user was on when Compass was launched via FAB.
    /// Used for mode-detection ("I can see you're on Home").
    var launchContext: V2Tab = .compass

    /// When set, Compass opens in TUTOR mode scoped to this content.
    var tutorContext: CompassTutorContext?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().background(V2Theme.cardBorder)

                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(vm.messages) { msg in
                                MessageView(message: msg)
                                    .id(msg.id)
                            }

                            if vm.showSuggestions {
                                suggestionsView
                                    .padding(.top, 6)
                            }

                            if let config = vm.activeConfig {
                                ConfigCardView(config: config) {
                                    vm.startConfiguredAction(router: taskRouter)
                                }
                                .id("config")
                            }
                        }
                        .padding(.horizontal, V2Theme.pad)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation {
                            scroll.scrollTo(vm.messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                quickActionsBar
                inputBar
            }
            .background(ColorTokens.background.ignoresSafeArea())
        }
        .onAppear {
            if let tc = tutorContext { vm.tutorContext = tc }
            vm.startConversation(context: launchContext)
        }
        .sheet(isPresented: $vm.noteFlowRequested) {
            V2NoteFlowView(onClose: { vm.noteFlowRequested = false })
                .environment(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.resetConversation() }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(ColorTokens.gold)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [ColorTokens.goldLight, ColorTokens.goldDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
                    .rotationEffect(.degrees(-45))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.tutorContext != nil ? "Compass · Tutor" : "Compass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(ColorTokens.success).frame(width: 6, height: 6)
                    Text(vm.tutorContext.map { "on “\($0.title)”" } ?? "knows your full context")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Menu {
                Button {
                    Task { await vm.resetConversation() }
                } label: {
                    Label("New conversation", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(ColorTokens.surface))
            }
        }
        .padding(.horizontal, V2Theme.pad)
        .padding(.vertical, 12)
    }

    // MARK: - Suggestion chips

    private var suggestionsView: some View {
        FlexibleChips(items: vm.suggestions) { chip in
            vm.handleSuggestion(chip)
        }
    }

    // MARK: - Quick actions (always-visible capability strip)

    /// What Compass can do, surfaced persistently above the input so users
    /// never have to guess. Tapping one kicks off that flow.
    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CompassQuickAction.all, id: \.label) { action in
                    Button {
                        vm.handleSuggestion(action.chip)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(action.label)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(ColorTokens.gold)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(ColorTokens.gold.opacity(0.10))
                                .overlay(Capsule().strokeBorder(ColorTokens.gold.opacity(0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, V2Theme.pad)
        }
        .padding(.top, 8)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button { vm.noteFlowRequested = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 28, height: 28)
            }
            TextField("Or type what you need...", text: $vm.inputText)
                .focused($inputFocused)
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .submitLabel(.send)
                .onSubmit { vm.send() }

            Button { vm.send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTokens.background)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(ColorTokens.gold))
            }
            .disabled(vm.inputText.isEmpty)
            .opacity(vm.inputText.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(ColorTokens.surface)
                .overlay(Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
        )
        .padding(.horizontal, V2Theme.pad)
        .padding(.bottom, 18)
        .padding(.top, 8)
    }
}

// MARK: - Compass quick actions

/// The capability set Compass exposes, surfaced as an always-visible strip.
/// `chip` text is what gets fed to CompassViewModel.handleSuggestion — keep
/// the keywords ("Quiz", "interview", "note", "resume") so inferMode routes.
struct CompassQuickAction {
    let label: String
    let icon: String
    let chip: String

    static let all: [CompassQuickAction] = [
        .init(label: "Quiz me", icon: "bolt.fill", chip: "Quiz me"),
        .init(label: "Practice interview", icon: "mic.fill", chip: "Practice interview"),
        .init(label: "Make a note", icon: "doc.text.fill", chip: "Make a note"),
        .init(label: "Build my resume", icon: "person.text.rectangle.fill", chip: "Build my resume"),
        .init(label: "Plan my days", icon: "calendar", chip: "Plan my next 2 days"),
        .init(label: "Explain something", icon: "questionmark.circle.fill", chip: "Explain something"),
    ]
}

// MARK: - Compass sheet (FAB-triggered)

struct V2CompassSheetView: View {
    var currentScreen: V2Tab = .home
    /// When set, the sheet opens Compass in tutor mode for this content.
    var tutorContext: CompassTutorContext?
    var body: some View {
        V2CompassView(launchContext: currentScreen, tutorContext: tutorContext)
    }
}

// MARK: - Message rendering

private struct MessageView: View {
    let message: CompassMessage
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.goldLight)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorTokens.gold.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(ColorTokens.gold.opacity(0.25), lineWidth: 1)
                            )
                    )
            } else {
                Text(message.text)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                            )
                    )
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - Config card (inline configurator)

private struct ConfigCardView: View {
    let config: CompassConfig
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(config.fields.enumerated()), id: \.element.label) { idx, field in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(ColorTokens.textTertiary)
                        Text(field.value)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(field.highlight ? ColorTokens.success : ColorTokens.textPrimary)
                    }
                    Spacer()
                    if field.toggle {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.success)
                    } else {
                        Text("change ▾")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                if idx < config.fields.count - 1 {
                    Divider().background(V2Theme.cardBorder)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTokens.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
        )

        VStack(spacing: 0) {
            Text(config.estimateLabel)
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Button(action: onStart) {
                Text("\(config.startLabel) →")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ColorTokens.gold)
                    .foregroundStyle(ColorTokens.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Flexible chips wrap

private struct FlexibleChips: View {
    let items: [String]
    let onTap: (String) -> Void
    var body: some View {
        // Simple wrap layout via V2FlowLayout (custom)
        V2FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { chip in
                Button {
                    onTap(chip)
                } label: {
                    Text(chip)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(ColorTokens.surface)
                                .overlay(Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal wrap-layout. Replace with V2FlowLayout in iOS 16+ if Layout protocol available.
private struct V2FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    V2CompassView()
        .preferredColorScheme(.dark)
}
