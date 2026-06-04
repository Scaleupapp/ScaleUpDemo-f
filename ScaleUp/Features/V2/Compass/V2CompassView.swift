import SwiftUI
import PhotosUI
import VisionKit

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
    @Environment(V2NavState.self) private var nav
    @FocusState private var inputFocused: Bool

    // MARK: - Competition banner state

    @State private var unplayedChallenge: UnplayedChallenge?
    @State private var requestedDrillSession: DrillSession? = nil
    @State private var isRequestingDrill = false
    @State private var drillRequestError: String? = nil

    private struct UnplayedChallenge: Codable, Equatable {
        let _id: String
        let topic: String?
        let questionCount: Int?
    }

    private struct CompeteRelevantEnvelope: Codable {
        let success: Bool
        let data: CompeteRelevantData?
    }
    private struct CompeteRelevantData: Codable {
        let status: String
        let objectiveTopic: String?
        let todayChallenge: UnplayedChallenge?
    }

    /// Optional — the tab the user was on when Compass was launched via FAB.
    /// Used for mode-detection ("I can see you're on Home").
    var launchContext: V2Tab = .compass

    /// When set, Compass opens in TUTOR mode scoped to this content.
    var tutorContext: CompassTutorContext?

    /// When set, Compass opens in COACH mode (the general-purpose retrospective).
    /// If `scope` is non-nil, the opener fires immediately; if nil, the user
    /// is prompted to pick a scope via the scope chip strip below.
    var coachContext: CompassCoachContext?

    /// Legacy review context — kept so old TaskRouter routes still compile.
    /// Forwarded into the VM which now treats it as coach scope=week.
    var reviewContext: CompassReviewContext?

    // ── Photo capture state ──
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var stagedImage: UIImage?
    @State private var showCaptureMenu = false
    @State private var showingPhotoPicker = false

    // ── Topic picker (Coach scope=topic) ──
    @State private var topicPickerInput: String = ""
    @State private var topPickedSuggestion: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().background(V2Theme.cardBorder)
                competitionBanner

                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(vm.messages) { msg in
                                MessageView(
                                    message: msg,
                                    onSuggestedAction: { action in
                                        Task { await handleSuggestedAction(action) }
                                    },
                                    onStartTutoring: { topic in
                                        Task { await vm.startTutoring(topic: topic) }
                                    },
                                    onStartInlineCheck: { topic, count, before in
                                        vm.startInlineCheck(topic: topic, questionCount: count, beforeScore: before)
                                    }
                                )
                                .id(msg.id)
                            }

                            if vm.isWaitingForReply {
                                TypingIndicatorBubble()
                                    .id("typing")
                                    .transition(.opacity)
                            }

                            if let quiz = vm.inlineQuiz {
                                CompassInlineQuizCard(model: quiz, onFinished: { Task { await vm.finishInlineCheck() } })
                                    .padding(.horizontal)
                                    .id("inlineQuiz")
                            }

                            // Coach mode scope picker — shown only on the
                            // opening turn, before a scope is chosen. Once a
                            // chip is tapped, the opener fires and these chips
                            // are hidden (coachContext.scope becomes non-nil).
                            if vm.coachContext != nil && vm.coachContext?.scope == nil {
                                coachScopePicker
                                    .padding(.top, 6)
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
                    .onChange(of: vm.isWaitingForReply) { _, waiting in
                        if waiting {
                            withAnimation {
                                scroll.scrollTo("typing", anchor: .bottom)
                            }
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
            if let cc = coachContext { vm.coachContext = cc }
            if let rc = reviewContext { vm.reviewContext = rc }
            vm.startConversation(context: launchContext)
            Task { await loadCompetitionStatus() }
        }
        // Compass quick actions → dedicated home destinations. Plan routes
        // straight to the Home tab; Notes / Quiz / Interview each present a
        // focused screen (where the user can see history + start new).
        // Explain stays in the chat.
        .sheet(item: $vm.presentedHome, onDismiss: { vm.presentedHome = nil }) { route in
            switch route {
            case .quiz:
                V2QuizHomeView(
                    onClose: { vm.presentedHome = nil },
                    onGenerateNew: { vm.startQuizConfigFromHome() }
                )
                .environment(appState)
                .environment(taskRouter)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .interview:
                V2InterviewHomeView(
                    onClose: { vm.presentedHome = nil },
                    onStartNew: {
                        taskRouter.open(taskType: "interview", payload: nil, title: "Practice interview")
                    }
                )
                .environment(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .notes:
                V2NoteFlowView(onClose: { vm.presentedHome = nil })
                    .environment(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .plan:
                V2PlanHomeView(
                    onClose: { vm.presentedHome = nil },
                    onViewFullHome: {
                        nav.selectedTab = .home
                        nav.compassSheetOpen = false
                    }
                )
                .environment(appState)
                .environment(taskRouter)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .compete:
                V2CompetitionHomeView(onClose: { vm.presentedHome = nil })
                    .environment(appState)
                    .environment(taskRouter)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .codingDrill:
                V2CodingDrillRequestView(onClose: { vm.presentedHome = nil })
                    .environment(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .codingCapstone:
                NavigationStack {
                    V2CodingHubView(onClose: { vm.presentedHome = nil }, initialSegment: .capstones)
                }
                .environment(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        // Compass action-card drill flow — uses sheet(item:) to avoid the
        // sheet-from-sheet race (no second sheet while presentedHome is still dismissing)
        .sheet(item: $requestedDrillSession) { session in
            DrillModalView(preloadedSession: session)
        }
        .alert("Couldn't start drill", isPresented: Binding(
            get: { drillRequestError != nil },
            set: { if !$0 { drillRequestError = nil } }
        )) {
            Button("OK", role: .cancel) { drillRequestError = nil }
        } message: {
            Text(drillRequestError ?? "")
        }
        .overlay {
            if isRequestingDrill {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Finding a drill for you…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
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

    // MARK: - Compass suggested-action handler

    private func handleSuggestedAction(_ action: CompassSuggestedAction) async {
        isRequestingDrill = true
        defer { isRequestingDrill = false }
        let body = DrillRequestBody(
            drillSubtype: action.drillSubtype.flatMap { DrillSubtype(rawValue: $0) },
            difficulty: action.difficulty.flatMap { DrillDifficulty(rawValue: $0) },
            topicHint: action.topicHint
        )
        do {
            let resp = try await DrillService.shared.requestDrill(body: body)
            let session = DrillSession(
                preloadedDrill: resp.toTodayResponse(),
                preloadedAttemptId: resp.attemptId
            )
            requestedDrillSession = session
            AnalyticsService.shared.track(.codingExtraDrillRequested(source: "compass"))
        } catch {
            drillRequestError = compassDrillError(error)
            print("[Compass requestDrill] failed: \(error)")
        }
    }

    private func compassDrillError(_ error: Error) -> String {
        if case V2APIError.httpError(let status, let data) = error {
            if status == 404, let body = try? JSONDecoder().decode([String: String].self, from: data) {
                switch body["error"] {
                case "no_coding_track_for_objective":
                    return "Coding practice isn't available for your current objective."
                case "no_drill_available":
                    return "We're out of fresh drills for this combination — try another type or difficulty."
                default: break
                }
            }
            return "Server returned \(status). Try again in a moment."
        }
        return error.localizedDescription
    }

    // MARK: - Competition banner

    private func loadCompetitionStatus() async {
        do {
            let env: CompeteRelevantEnvelope = try await V2APIClient.shared.getV1("/competition/relevant")
            if env.data?.status == "available", let ch = env.data?.todayChallenge {
                unplayedChallenge = ch
            } else {
                unplayedChallenge = nil
            }
        } catch {
            unplayedChallenge = nil
        }
    }

    private var competitionBanner: some View {
        Group {
            if let ch = unplayedChallenge {
                Button {
                    vm.presentedHome = .compete
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ColorTokens.gold.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.gold)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TODAY'S CHALLENGE WAITING")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(ColorTokens.gold)
                            Text(prettyTopicName(ch.topic))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Open")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(ColorTokens.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTokens.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(ColorTokens.gold.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func prettyTopicName(_ slug: String?) -> String {
        guard let s = slug, !s.isEmpty else { return "Daily Challenge" }
        return s
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // MARK: - Header

    private var headerTitle: String {
        if vm.coachContext != nil  { return "Coach" }
        if vm.reviewContext != nil { return "Coach" }
        if vm.tutorContext != nil  { return "Compass · Tutor" }
        return "Compass"
    }

    private var headerSubtitle: String {
        if let c = vm.coachContext {
            if let scope = c.scope {
                if scope == .topic, let topic = c.topic, !topic.isEmpty {
                    return "scope: \(topic)"
                }
                return scope.headerSubtitle
            }
            return "pick what to reflect on"
        }
        if let r = vm.reviewContext { return "scope: This Week (week \(r.weekNumber))" }
        if let t = vm.tutorContext  { return "on \u{201C}\(t.title)\u{201D}" }
        return "knows your full context"
    }

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
                Text(headerTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(ColorTokens.success).frame(width: 6, height: 6)
                    Text(headerSubtitle)
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

    // MARK: - Coach scope picker (opener-only)

    /// Renders scope chips on the first Coach turn. Tapping a chip sets the
    /// scope on coachContext and fires the LLM opener. For .topic we also
    /// surface a small free-text field so the user can name a topic.
    private var coachScopePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlexibleChips(items: CoachScope.allCases.map { $0.chipLabel }) { chipLabel in
                guard let scope = CoachScope.allCases.first(where: { $0.chipLabel == chipLabel }) else { return }
                if scope == .topic {
                    // Defer firing until the user types a topic — show the
                    // input field by setting an empty topic on the context.
                    vm.coachContext?.topic = ""
                    vm.coachContext?.scope = nil // keep the picker rendered until topic is submitted
                    topicPickerInput = ""
                    topPickedSuggestion = "topic-mode-armed"
                } else {
                    vm.openCoach(scope: scope, topic: nil)
                }
            }

            if topPickedSuggestion == "topic-mode-armed" {
                HStack(spacing: 8) {
                    TextField("Type a topic (e.g. dynamic programming)", text: $topicPickerInput)
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(ColorTokens.surface)
                                .overlay(Capsule().strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                        )
                        .submitLabel(.go)
                        .onSubmit { submitTopic() }

                    Button(action: submitTopic) {
                        Text("Start")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ColorTokens.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(ColorTokens.gold))
                    }
                    .disabled(topicPickerInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(topicPickerInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
            }
        }
    }

    private func submitTopic() {
        let trimmed = topicPickerInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        topPickedSuggestion = nil
        vm.openCoach(scope: .topic, topic: trimmed)
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

    private var stagedPhotoPreview: some View {
        Group {
            if let img = stagedImage {
                HStack {
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            stagedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .background(Circle().fill(ColorTokens.background))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 4)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            stagedPhotoPreview
            HStack(spacing: 10) {
                Button { vm.presentedHome = .notes } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 28, height: 28)
                }

                Button { showCaptureMenu = true } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .confirmationDialog("Add a photo", isPresented: $showCaptureMenu, titleVisibility: .visible) {
                    Button("Scan") { showingScanner = true }
                    Button("Choose photo") { showingPhotoPicker = true }
                }

                TextField("Or type what you need...", text: $vm.inputText)
                    .focused($inputFocused)
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .submitLabel(.send)
                    .onSubmit { vm.send() }

                Button {
                    if let img = stagedImage {
                        let prompt = vm.inputText
                        stagedImage = nil
                        vm.inputText = ""
                        Task { await vm.sendVision(image: img, prompt: prompt) }
                    } else {
                        vm.send()
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.background)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(ColorTokens.gold))
                }
                .disabled(vm.inputText.isEmpty && stagedImage == nil)
                .opacity((vm.inputText.isEmpty && stagedImage == nil) ? 0.45 : 1)
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
        .sheet(isPresented: $showingScanner) {
            // DocumentScannerView is declared at file scope in Features/Notes/Views/CreateNotesView.swift
            DocumentScannerView { images in stagedImage = images.first }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    stagedImage = img
                }
                photoItem = nil
            }
        }
    }
}

// MARK: - Compass quick actions

/// The capability set Compass exposes, surfaced as an always-visible strip.
/// `chip` text is what gets fed to CompassViewModel.handleSuggestion — keep
/// the keywords ("Quiz", "interview", "note") so inferMode routes correctly.
struct CompassQuickAction {
    let label: String
    let icon: String
    let chip: String

    static let all: [CompassQuickAction] = [
        .init(label: "Quiz me", icon: "bolt.fill", chip: "Quiz me"),
        .init(label: "Compete today", icon: "trophy.fill", chip: "Compete today"),
        .init(label: "Practice interview", icon: "mic.fill", chip: "Practice interview"),
        .init(label: "Coding capstone", icon: "chevron.left.forwardslash.chevron.right", chip: "Show me my coding capstone"),
        .init(label: "Make a note", icon: "doc.text.fill", chip: "Make a note"),
        .init(label: "Plan my days", icon: "calendar", chip: "Plan my next 2 days"),
        .init(label: "Explain something", icon: "questionmark.circle.fill", chip: "Explain something"),
    ]
}

// MARK: - Compass sheet (FAB-triggered)

struct V2CompassSheetView: View {
    var currentScreen: V2Tab = .home
    /// When set, the sheet opens Compass in tutor mode for this content.
    var tutorContext: CompassTutorContext?
    /// When set, the sheet opens Compass in Coach mode with the given scope
    /// (or, when scope is nil, prompts the user to pick one).
    var coachContext: CompassCoachContext?
    /// Legacy — kept so old taskRouter routes still compile.
    var reviewContext: CompassReviewContext?
    var body: some View {
        V2CompassView(
            launchContext: currentScreen,
            tutorContext: tutorContext,
            coachContext: coachContext,
            reviewContext: reviewContext
        )
    }
}

// MARK: - Message rendering

private struct MessageView: View {
    let message: CompassMessage
    let onSuggestedAction: (CompassSuggestedAction) -> Void
    let onStartTutoring: (String) -> Void
    let onStartInlineCheck: (String, Int, Double?) -> Void

    init(
        message: CompassMessage,
        onSuggestedAction: @escaping (CompassSuggestedAction) -> Void = { _ in },
        onStartTutoring: @escaping (String) -> Void = { _ in },
        onStartInlineCheck: @escaping (String, Int, Double?) -> Void = { _, _, _ in }
    ) {
        self.message = message
        self.onSuggestedAction = onSuggestedAction
        self.onStartTutoring = onStartTutoring
        self.onStartInlineCheck = onStartInlineCheck
    }

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 6) {
                    if let data = message.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !message.text.isEmpty {
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
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
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

                    if let action = message.suggestedAction {
                        switch action.type {
                        case "request_drill":    suggestedActionCard(action)
                        case "start_tutoring":   tutoringOfferCard(action)
                        case "start_check_quiz": checkQuizCTACard(action)
                        default:                 EmptyView()
                        }
                    }
                    ForEach(message.cards) { card in
                        CompassCardView(card: card)
                    }
                }
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func suggestedActionCard(_ action: CompassSuggestedAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("Take a coding drill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.gold)
            }

            Text(actionDescription(action))
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textPrimary)

            Button {
                onSuggestedAction(action)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.caption)
                    Text("Start drill").fontWeight(.semibold)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ColorTokens.gold.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tutoringOfferCard(_ action: CompassSuggestedAction) -> some View {
        let topic = action.topic ?? "this topic"
        let scoreText = action.score.map { " — \(Int($0.rounded()))%" } ?? ""
        tutoringCardShell(icon: "target", title: "Improve: \(topic.capitalized)\(scoreText)", cta: "Start") {
            onStartTutoring(topic)
        }
    }

    @ViewBuilder
    private func checkQuizCTACard(_ action: CompassSuggestedAction) -> some View {
        tutoringCardShell(icon: "checkmark.circle", title: "Ready for a quick check?", cta: "Start check") {
            onStartInlineCheck(action.topic ?? "", action.questionCount ?? 4, action.beforeScore)
        }
    }

    private func tutoringCardShell(icon: String, title: String, cta: String, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.gold)
            }
            Button {
                onTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.caption)
                    Text(cta).fontWeight(.semibold)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ColorTokens.gold)
                .foregroundStyle(ColorTokens.background)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ColorTokens.gold.opacity(0.2), lineWidth: 1)
        )
    }

    private func actionDescription(_ action: CompassSuggestedAction) -> String {
        var parts: [String] = []
        if let subtype = action.drillSubtype {
            let label: String
            switch subtype {
            case "prompt":    label = "Prompt"
            case "verify":    label = "Bug Hunt"
            case "decompose": label = "Decompose"
            default:          label = subtype.capitalized
            }
            parts.append(label)
        }
        if let diff = action.difficulty {
            parts.append(diff.capitalized)
        }
        if let hint = action.topicHint, !hint.isEmpty {
            parts.append(hint)
        }
        if parts.isEmpty {
            return "Based on your weakest area"
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Typing indicator (three pulsing dots while awaiting reply)

private struct TypingIndicatorBubble: View {
    @State private var phase = 0
    private let dotCount = 3

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<dotCount, id: \.self) { i in
                    Circle()
                        .fill(ColorTokens.textTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.15 : 1.0)
                }
            }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            // .task auto-cancels when the view disappears, so the loop dies
            // cleanly when the assistant reply arrives and we drop the bubble.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % dotCount
                }
            }
        }
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
                    }
                    // "change ▾" was misleading — the field wasn't tappable.
                    // To change anything, the user types it in the input bar
                    // (e.g. "make it 10 questions" or "harder") and Compass
                    // re-issues the config. A proper picker UI is a follow-up.
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
