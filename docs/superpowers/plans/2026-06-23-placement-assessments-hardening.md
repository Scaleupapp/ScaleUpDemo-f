# Placement Assessments iOS Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the ScaleUp Placements student take-flow so all three assessment types (MCQ, Capstone, Interview) work end-to-end with robust sync, error handling, mic gating, and async-grade polling.

**Architecture:** The Placements assessments feature lives entirely under `ScaleUp/Features/Placements/Assessments/` with two existing files (`PlacementsAssessmentsApi.swift`, `PlacementsAssessmentsView.swift`). New files are added in that same directory. We reuse `CapstonePairingCodePanel` (the standalone panel from Coding) rather than `CapstonePairView` (which requires a full `CapstoneLibraryEntry` bundle and calls `CapstoneService` — an entirely different domain). The interview take-view gets a new dedicated wrapper (`PlacementInterviewTakeView` already exists in `PlacementsAssessmentsView.swift`) that we harden in-place.

**Tech Stack:** Swift 6.0, SwiftUI, iOS 17+, `@Observable`, `AVFoundation`, `UIKit.UIApplication`, `V2APIClient` / `V2APIError`, `APIError.conflictWithCode`, `CapstonePairingCodePanel` (existing).

## Global Constraints

- SWIFT_STRICT_CONCURRENCY: complete — every async call must be on @MainActor or properly isolated.
- Branch: `feat/placement-assessments-hardening` — do NOT switch.
- Working directory: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f`.
- All new Placements files live under `ScaleUp/Features/Placements/Assessments/` — they are picked up automatically by `project.yml`'s `sources: [ScaleUp]` glob.
- Do NOT modify D2C V2 flow or shared `InterviewSessionView`/`CapstonePairView`/`CapstoneService` behaviour.
- No force-unwraps where a nil can crash (guard + friendly error).
- Build command: `xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40`. Use `xcrun simctl list devices available | grep iPhone` to pick an available simulator name.
- Verify: `BUILD SUCCEEDED` in the last 40 lines.
- Commit all modified + generated files with message: `feat(placements): student take-flow hardening — capstone pairing, mic gate, async-grade refresh, error mapping [iOS]`.
- Write a final report to `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/.assessment-ios-hardening-report.md`.

---

## File Map

| Path | Create/Modify | Responsibility |
|------|--------------|----------------|
| `ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsApi.swift` | Modify | Add capstone `meta` fields to `AssessmentMeta`; error-code extractor helper |
| `ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsView.swift` | Modify | Error-code mapping, in_progress guard, graded score/dates display, foreground refresh, submitted-not-graded poll trigger, capstone sheet → `PlacementCapstonePairView`, interview results UX fix |
| `ScaleUp/Features/Placements/Assessments/PlacementCapstonePairView.swift` | Create | Lightweight pairing screen using `CapstonePairingCodePanel`; polls `syncSession` until graded |
| `ScaleUp/Features/Placements/Assessments/PlacementInterviewTakeView.swift` | Create | Extract `PlacementInterviewTakeView` from `PlacementsAssessmentsView.swift` into its own file with mic-gate, results overlay (no auto-dismiss), and placement-context error actions |

---

## Task 1: Add capstone meta fields + error-code extraction helper

**Files:**
- Modify: `ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsApi.swift`

**Interfaces:**
- Produces: `AssessmentMeta.pairingCode: String?`, `AssessmentMeta.expiresAt: String?`, `AssessmentMeta.timeBudgetSeconds: Int?`; `V2APIError.extractCode(from:) -> String?`

- [ ] **Step 1: Read the current file**

Open `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsApi.swift` to confirm line 61 has `AssessmentMeta` with only `systemInstruction`.

- [ ] **Step 2: Expand `AssessmentMeta` and add error-code helper**

Replace the `AssessmentMeta` struct and add the helper **after** the `PlacementsAssessmentsApi` class closing brace:

```swift
struct AssessmentMeta: Codable {
    let systemInstruction: String?
    // Capstone fields
    let pairingCode: String?
    let expiresAt: String?
    let timeBudgetSeconds: Int?
}
```

Also add this extension after `extension AssessmentStartResult: Identifiable { ... }` (the last line of the file):

```swift
// MARK: - V2APIError helpers (Placement assessment use)

extension V2APIError {
    /// Extracts the machine `code` string from a 4xx response body shaped:
    ///   { "success": false, "code": "NOT_OPEN", "message": "..." }
    /// Returns nil when no `code` key is present.
    func extractCode() -> String? {
        guard case .httpError(_, let data) = self else { return nil }
        struct CodeBody: Decodable { let code: String? }
        return (try? JSONDecoder().decode(CodeBody.self, from: data))?.code
    }
}
```

- [ ] **Step 3: Build check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED` (or at most warnings — no errors).

- [ ] **Step 4: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsApi.swift ScaleUp.xcodeproj
git commit -m "feat(placements): expand AssessmentMeta with capstone fields + V2APIError.extractCode helper"
```

---

## Task 2: Build `PlacementCapstonePairView` — lightweight pairing screen

**Files:**
- Create: `ScaleUp/Features/Placements/Assessments/PlacementCapstonePairView.swift`

**Interfaces:**
- Consumes: `AssessmentStartResult` (from Task 1 — now has `meta.pairingCode`, `meta.expiresAt`, `meta.timeBudgetSeconds`); `PlacementsAssessmentsApi.shared.syncSession(_:) -> AssessmentSyncResult`; `CapstonePairingCodePanel(pairingCode:expiresAt:laptopURL:)`
- Produces: `PlacementCapstonePairView(start: AssessmentStartResult, onClose: () -> Void)` — a `View` that shows the pairing code and polls sync until graded.

**Why NOT reuse `CapstonePairView` directly:** `CapstonePairView` requires a `CapstoneLibraryEntry` bundle (which we don't have from the placement start response) and calls `CapstoneService.shared.getStatus(sessionId:)` — a different domain's endpoint. The placement assessment has its own sessionId (`assessmentSessionId`) and uses `syncSession` for status. We **do** reuse `CapstonePairingCodePanel` which is purely presentational and only needs `pairingCode: String`, `expiresAt: Date`, and `laptopURL: String`.

- [ ] **Step 1: Create the file**

Create `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/Features/Placements/Assessments/PlacementCapstonePairView.swift` with this content:

```swift
import SwiftUI

/// Placement-context capstone pairing screen.
///
/// Shown after POST /me/assessments/:id/start returns type == "capstone".
/// Reuses `CapstonePairingCodePanel` (purely presentational) and polls
/// `syncSession(assessmentSessionId)` every 20 s until status == "graded"
/// (capstone is graded async after the laptop session completes).
///
/// We do NOT reuse CapstonePairView because it requires a CapstoneLibraryEntry
/// bundle and calls CapstoneService (different domain + different sessionId).
struct PlacementCapstonePairView: View {
    let start: AssessmentStartResult
    let onClose: () -> Void

    @State private var syncStatus: String?       // last status from syncSession
    @State private var pollTask: Task<Void, Never>?
    @State private var showDone = false

    private let api = PlacementsAssessmentsApi.shared

    /// The web URL where students enter their code on a laptop.
    private var laptopURL: String {
        if let v = Bundle.main.object(forInfoDictionaryKey: "CAPSTONE_WEB_URL") as? String, !v.isEmpty {
            return v
        }
        return "scaleup-web-seven.vercel.app/capstone"
    }

    var body: some View {
        NavigationStack {
            Group {
                if showDone {
                    doneView
                } else if let pairingCode = start.meta?.pairingCode,
                          let expiresAtStr = start.meta?.expiresAt,
                          let expiresAt = ISO8601DateFormatter().date(from: expiresAtStr) {
                    pairingContent(pairingCode: pairingCode, expiresAt: expiresAt)
                } else {
                    missingCodeView
                }
            }
            .navigationTitle("Pair your laptop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", role: .cancel) {
                        pollTask?.cancel()
                        onClose()
                    }
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Pairing content

    private func pairingContent(pairingCode: String, expiresAt: Date) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                instructionHeader
                CapstonePairingCodePanel(
                    pairingCode: pairingCode,
                    expiresAt: expiresAt,
                    laptopURL: laptopURL
                )
                timeBudgetRow
                syncStatusRow
                Spacer(minLength: 24)
            }
            .padding(.top, 24)
        }
    }

    private var instructionHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.gold)
            Text("Open on your laptop")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Go to the URL below on your laptop and enter the pairing code to begin your capstone assessment.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var timeBudgetRow: some View {
        Group {
            if let budget = start.meta?.timeBudgetSeconds {
                let minutes = budget / 60
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("Time budget: \(minutes) minutes")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var syncStatusRow: some View {
        Group {
            if let status = syncStatus, status != "in_progress" {
                HStack(spacing: 6) {
                    Circle().fill(colorFor(status: status)).frame(width: 6, height: 6)
                    Text(labelFor(status: status))
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Waiting for laptop to connect…")
                        .font(V2Theme.small)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
    }

    // MARK: - Done view

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.success)
            Text("Capstone Graded")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Your capstone assessment has been submitted and graded. Close this sheet to see your result.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") {
                pollTask?.cancel()
                onClose()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
            Spacer()
        }
    }

    // MARK: - Missing code fallback

    private var missingCodeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.gold)
            Text("Open on your laptop")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("This capstone assessment must be completed on a laptop or desktop browser. Log in to scaleupapp.club to continue.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Close") {
                pollTask?.cancel()
                onClose()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
        }
        .padding(32)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            // Poll up to 5 min (15 × 20 s) for a graded status
            for _ in 0..<15 {
                guard !Task.isCancelled else { return }
                if let result = try? await api.syncSession(start.assessmentSessionId) {
                    await MainActor.run { syncStatus = result.status }
                    if result.status == "graded" {
                        await MainActor.run { showDone = true }
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)  // 20 s
            }
        }
    }

    // MARK: - Helpers

    private func labelFor(status: String) -> String {
        switch status {
        case "submitted":   return "Submitted — grading in progress…"
        case "graded":      return "Graded"
        case "expired":     return "Session expired"
        default:            return status.capitalized
        }
    }

    private func colorFor(status: String) -> Color {
        switch status {
        case "graded":  return ColorTokens.success
        case "expired": return ColorTokens.textTertiary
        default:        return ColorTokens.gold
        }
    }
}
```

- [ ] **Step 2: Build check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Placements/Assessments/PlacementCapstonePairView.swift ScaleUp.xcodeproj
git commit -m "feat(placements): add PlacementCapstonePairView — pairing code panel + 20s sync poll"
```

---

## Task 3: Extract and harden `PlacementInterviewTakeView` — mic gate + results UX

**Files:**
- Create: `ScaleUp/Features/Placements/Assessments/PlacementInterviewTakeView.swift`

**Interfaces:**
- Consumes: `AssessmentStartResult`, `InterviewViewModel`, `InterviewSessionView`, `AVAudioSession`, `AVCaptureDevice`
- Produces: `PlacementInterviewTakeView(start: AssessmentStartResult, onComplete: () -> Void)` — a `View` that gates microphone, attachSession only on grant, shows results overlay without auto-dismiss, and offers Retry/Close on error.

**Key design decisions:**
1. We do NOT call `vm.attachSession` in `.task` unconditionally — we first request mic permission, only call `attachSession` on `.authorized`.
2. We do NOT modify `InterviewSessionView` (shared D2C screen). Instead we overlay a custom Done/Retry layer on top of it when `vm.state == .results` or `vm.state == .error(...)`.
3. The mic-denied state shows a blocking VStack with instructions + Close — never reaches `attachSession`.
4. `InterviewSessionView`'s `.error` state renders "Try Again" which sets `vm.state = .setup` — that's fine for D2C. In the Placement context we override the error UX with our own overlay so students see Retry (re-calls `attachSession`) or Close (dismisses sheet).

- [ ] **Step 1: Create the file**

Create `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/Features/Placements/Assessments/PlacementInterviewTakeView.swift`:

```swift
import SwiftUI
import AVFoundation

/// Placement-context interview take screen.
///
/// Gates AVAudioSession mic permission before calling vm.attachSession.
/// On grant  → attachSession(sessionId:systemInstruction:) → InterviewSessionView.
/// On denial → static error screen with Settings link + Close.
///
/// RESULTS: does NOT auto-dismiss on .results — shows a Done overlay so the
/// student can read their score before closing.
///
/// ERROR: in the placement context the InterviewSessionView's built-in
/// ".error → Try Again → .setup" flow would open the D2C setup form which
/// is wrong here. We overlay a Placement-specific Retry / Close layer instead.
struct PlacementInterviewTakeView: View {
    let start: AssessmentStartResult
    let onComplete: () -> Void

    @State private var vm = InterviewViewModel()
    @State private var micState: MicState = .checking
    @State private var showResultsOverlay = false
    @State private var showPlacementError: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(V2NavState.self) private var v2Nav
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(AppState.self) private var appState

    private enum MicState {
        case checking
        case granted
        case denied
    }

    var body: some View {
        ZStack {
            switch micState {
            case .checking:
                checkingView

            case .denied:
                micDeniedView

            case .granted:
                interviewBody
            }
        }
        .task { await requestMicPermission() }
    }

    // MARK: - Checking mic

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ColorTokens.gold)
            Text("Checking microphone access…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Mic denied

    private var micDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.error)
            Text("Microphone access needed")
                .font(V2Theme.h2)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("ScaleUp needs microphone access to conduct the AI interview. Please enable it in Settings → Privacy → Microphone.")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ColorTokens.gold)
            Button("Close") { dismiss() }
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Interview body + overlays

    private var interviewBody: some View {
        ZStack {
            InterviewSessionView(viewModel: vm)
                .environment(v2Nav)
                .environment(taskRouter)
                .environment(appState)
                .onChange(of: vm.state) { _, newState in
                    if case .results = newState {
                        // Do NOT auto-dismiss — show overlay so student reads results.
                        showResultsOverlay = true
                        onComplete()
                    }
                    // Override .error in placement context: capture it and show our overlay.
                    if case .error(let msg) = newState {
                        showPlacementError = msg
                    }
                }

            // Results overlay — student taps Done to dismiss.
            if showResultsOverlay {
                placementResultsDoneButton
            }

            // Error overlay — Retry or Close.
            if let errMsg = showPlacementError {
                placementErrorOverlay(errMsg)
            }
        }
    }

    // MARK: - Results "Done" overlay

    private var placementResultsDoneButton: some View {
        VStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(ColorTokens.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ColorTokens.gold)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Error overlay (placement context — no .setup redirect)

    private func placementErrorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("Interview error")
                    .font(V2Theme.h2)
                    .foregroundStyle(.white)
                Text(message)
                    .font(V2Theme.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                HStack(spacing: 16) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())

                    Button("Retry") {
                        showPlacementError = nil
                        Task {
                            // Re-attach to the same backend session.
                            await vm.attachSession(
                                sessionId: start.engine.sessionId ?? "",
                                systemInstruction: start.meta?.systemInstruction ?? ""
                            )
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ColorTokens.gold.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Mic permission

    private func requestMicPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            micState = .granted
            await attachSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            micState = granted ? .granted : .denied
            if granted { await attachSession() }
        default:
            micState = .denied
        }
    }

    private func attachSession() async {
        guard let sessionId = start.engine.sessionId, !sessionId.isEmpty else {
            showPlacementError = "Interview session ID is missing. Please try again."
            return
        }
        await vm.attachSession(
            sessionId: sessionId,
            systemInstruction: start.meta?.systemInstruction ?? ""
        )
    }
}
```

- [ ] **Step 2: Build check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Fix any concurrency/isolation warnings as errors before continuing.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Placements/Assessments/PlacementInterviewTakeView.swift ScaleUp.xcodeproj
git commit -m "feat(placements): PlacementInterviewTakeView — mic gate + results overlay + placement error retry/close"
```

---

## Task 4: Harden `PlacementsAssessmentsView` — wire all fixes

**Files:**
- Modify: `ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsView.swift`

**Interfaces:**
- Consumes: `PlacementCapstonePairView(start:onClose:)` (Task 2), `PlacementInterviewTakeView(start:onComplete:)` (Task 3), `V2APIError.extractCode()` (Task 1), `PlacementsAssessmentsApi.syncSession`, `UIApplication.didBecomeActiveNotification`
- Produces: Updated `PlacementsAssessmentsView` with all 7 hardening items wired in.

This is the most substantial change. We replace the entire file. Read it first, then write the hardened version.

The changes vs. the current file are:

1. **Error-code mapping** in `handleTap`'s catch: cast to `V2APIError`, call `extractCode()`, map `NOT_OPEN`/`CLOSED`/`NOT_ENROLLED`/`403` to friendly strings; also map `APIError.forbidden`.
2. **in_progress guard**: in `handleTap`, if `row.session?.status == "in_progress"` and `row.session?.id != nil`, treat it as resume (re-present the existing `activeStart` surrogate) rather than calling `startAssessment` again.
3. **Capstone sheet** → `PlacementCapstonePairView` (replacing the static "open on laptop" VStack).
4. **Interview sheet** → `PlacementInterviewTakeView` (replacing the old `PlacementInterviewTakeView` defined inline — now it's in its own file).
5. **Graded score display** in `AssessmentRowCard`: if `row.session?.status == "graded"` and `row.session?.result?.score != nil`, show the score.
6. **Opens/Closes display** in `AssessmentRowCard`: show `opensAt` / `closesAt` if present.
7. **Foreground refresh**: subscribe to `UIApplication.didBecomeActiveNotification` → call `await load()`.
8. **Submitted-not-graded poll**: when `sync()` returns a non-graded status (`submitted`), start a background `Task` that polls `listAssessments()` (and/or `syncSession`) every 20 s up to 5 min; cancel on graded or view disappear.
9. **Auto-clear startError** at the top of `handleTap`.
10. **Remove the inline `PlacementInterviewTakeView`** struct (now in its own file).

- [ ] **Step 1: Write the hardened `PlacementsAssessmentsView.swift`**

Write the full file to `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsView.swift`:

```swift
import SwiftUI
import UIKit

// MARK: - Main Assessments Section

/// Section displayed on the Placements Home screen, listing all scheduled
/// assessments for the student and providing a tap-to-take action for each.
struct PlacementsAssessmentsView: View {
    @State private var rows: [PlacementAssessmentRow] = []
    @State private var isLoading = false
    @State private var loadError: String?

    /// Sheet state: which assessment the student just started.
    @State private var activeStart: AssessmentStartResult?
    @State private var startError: String?
    @State private var startingId: String?   // which card shows a spinner

    /// Background grade-poll task for submitted-but-not-graded sessions.
    @State private var gradePollTask: Task<Void, Never>?

    /// Injected from PlacementsMainTabView — needed by PlacementInterviewTakeView.
    @Environment(V2NavState.self) private var v2Nav
    @Environment(V2TaskRouter.self) private var taskRouter
    @Environment(AppState.self) private var appState

    private let api = PlacementsAssessmentsApi.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduled assessments").v2Eyebrow()

            if isLoading && rows.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(ColorTokens.gold)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let loadError {
                Text(loadError)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.vertical, 8)
            } else if rows.isEmpty {
                Text("Assessments scheduled by your placement office will appear here. In the meantime, keep building readiness with Compass and your daily plan.")
                    .font(V2Theme.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(rows) { row in
                    AssessmentRowCard(
                        row: row,
                        isStarting: startingId == row.id,
                        onTap: { handleTap(row: row) }
                    )
                }
            }

            if let startError {
                Text(startError)
                    .font(V2Theme.small)
                    .foregroundStyle(ColorTokens.error)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await load() }
        // Refresh on app foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
        }
        .onDisappear { gradePollTask?.cancel() }
        // MCQ sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "mcq" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { start in
            if let quizId = start.engine.quizId {
                PlanTaskQuizLoaderSheet(quizId: quizId) {
                    Task {
                        await sync(assessmentSessionId: start.assessmentSessionId)
                        await load()
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text("MCQ assessment is not configured yet.")
                        .font(V2Theme.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Button("Close") { activeStart = nil }
                }
                .padding()
            }
        }
        // Interview sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "interview" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { start in
            PlacementInterviewTakeView(
                start: start,
                onComplete: {
                    Task {
                        let syncResult = await sync(assessmentSessionId: start.assessmentSessionId)
                        await load()
                        if let status = syncResult?.status, status != "graded" {
                            startGradePoll(assessmentSessionId: start.assessmentSessionId)
                        }
                    }
                }
            )
            .environment(v2Nav)
            .environment(taskRouter)
            .environment(appState)
        }
        // Capstone sheet
        .sheet(item: Binding(
            get: { activeStart.flatMap { $0.engine.type == "capstone" ? $0 : nil } },
            set: { if $0 == nil { activeStart = nil } }
        )) { start in
            PlacementCapstonePairView(
                start: start,
                onClose: {
                    Task {
                        let syncResult = await sync(assessmentSessionId: start.assessmentSessionId)
                        activeStart = nil
                        await load()
                        if let status = syncResult?.status, status != "graded" {
                            startGradePoll(assessmentSessionId: start.assessmentSessionId)
                        }
                    }
                }
            )
        }
    }

    // MARK: - Actions

    private func handleTap(row: PlacementAssessmentRow) {
        let status = row.session?.status
        // Guard: graded, submitted, and expired are terminal — no action.
        guard status != "graded", status != "submitted", status != "expired" else { return }

        // Auto-clear any previous start error.
        startError = nil

        // Guard: in_progress — resume (re-present) rather than starting a new session.
        if status == "in_progress" {
            // We don't have the original AssessmentStartResult anymore.
            // Block re-tap and rely on sync poll + foreground refresh.
            // The row already shows "In progress" label.
            return
        }

        startingId = row.id
        Task {
            defer { startingId = nil }
            do {
                let result = try await api.startAssessment(row.id)
                activeStart = result
            } catch {
                startError = friendlyError(error, for: row)
            }
        }
    }

    /// Maps API errors to learner-friendly strings.
    private func friendlyError(_ error: Error, for row: PlacementAssessmentRow) -> String {
        // V2APIError path (used by V2APIClient — the PlacementsAssessmentsApi client)
        if let v2Err = error as? V2APIError {
            if let code = v2Err.extractCode() {
                switch code {
                case "NOT_OPEN":    return "This assessment hasn't opened yet."
                case "CLOSED":      return "This assessment is closed."
                case "NOT_ENROLLED": return "You're not enrolled in this cohort."
                default:            break
                }
            }
            // 403 without a code
            if case .httpError(403, _) = v2Err {
                return "You're not enrolled in this cohort."
            }
            if case .httpError(409, _) = v2Err {
                return "This assessment is not available right now."
            }
        }
        // Legacy APIError path (fallback)
        if let apiErr = error as? APIError {
            switch apiErr {
            case .forbidden: return "You're not enrolled in this cohort."
            case .conflictWithCode(let code, _, _):
                switch code {
                case "NOT_OPEN":    return "This assessment hasn't opened yet."
                case "CLOSED":      return "This assessment is closed."
                case "NOT_ENROLLED": return "You're not enrolled in this cohort."
                default:            break
                }
            default:
                break
            }
        }
        return "Could not start assessment: \(error.localizedDescription)"
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            rows = try await api.listAssessments()
        } catch {
            loadError = "Could not load assessments."
        }
        isLoading = false
    }

    @discardableResult
    private func sync(assessmentSessionId: String) async -> AssessmentSyncResult? {
        // Best-effort: ignore errors; return result so caller can inspect status.
        return try? await api.syncSession(assessmentSessionId)
    }

    // MARK: - Submitted-not-graded background poll

    /// Polls listAssessments every 20 s up to 5 min until any session shows
    /// "graded". Cancels if the view disappears (onDisappear cancels gradePollTask).
    private func startGradePoll(assessmentSessionId: String) {
        gradePollTask?.cancel()
        gradePollTask = Task {
            for _ in 0..<15 {   // 15 × 20 s = 5 min
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                // Try a direct sync first.
                if let result = try? await api.syncSession(assessmentSessionId),
                   result.status == "graded" {
                    await load()
                    return
                }
                // Also reload the list (catches server-driven status changes).
                await load()
                // Check if any row is now graded for this session.
                let anyGraded = rows.contains { r in
                    r.session?.id == assessmentSessionId && r.session?.status == "graded"
                }
                if anyGraded { return }
            }
        }
    }
}

// MARK: - Row Card

private struct AssessmentRowCard: View {
    let row: PlacementAssessmentRow
    let isStarting: Bool
    let onTap: () -> Void

    private var statusLabel: String {
        switch row.session?.status {
        case "graded":
            if let score = row.session?.result?.score {
                return "Graded — \(Int(score.rounded()))%"
            }
            return "Graded"
        case "submitted":   return "Submitted — grading…"
        case "in_progress": return "In progress"
        case "scheduled":   return "Not started"
        case "expired":     return "Expired"
        default:            return "Not started"
        }
    }

    private var statusColor: Color {
        switch row.session?.status {
        case "graded":      return ColorTokens.success
        case "submitted":   return ColorTokens.gold
        case "in_progress": return .orange
        case "expired":     return ColorTokens.textTertiary
        default:            return ColorTokens.textTertiary
        }
    }

    private var isActionable: Bool {
        let s = row.session?.status
        return s != "graded" && s != "submitted" && s != "expired" && s != "in_progress"
    }

    private var typeIcon: String {
        switch row.assessment.type {
        case "interview": return "mic.fill"
        case "capstone":  return "laptopcomputer"
        default:          return "checklist"
        }
    }

    /// Human-readable window subtitle, e.g. "Opens 25 Jun · Closes 28 Jun"
    private var windowLabel: String? {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        var parts: [String] = []
        if let s = row.assessment.opensAt,
           let d = ISO8601DateFormatter().date(from: s) {
            parts.append("Opens \(fmt.string(from: d))")
        }
        if let s = row.assessment.closesAt,
           let d = ISO8601DateFormatter().date(from: s) {
            parts.append("Closes \(fmt.string(from: d))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: { if isActionable { onTap() } }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: typeIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 34, height: 34)
                    .background(ColorTokens.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.assessment.title)
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(row.assessment.type.uppercased())
                        .font(V2Theme.tiny)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if let window = windowLabel {
                        Text(window)
                            .font(V2Theme.tiny)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(statusLabel)
                            .font(V2Theme.small)
                            .foregroundStyle(statusColor)
                    }
                }

                Spacer(minLength: 0)

                if isStarting {
                    ProgressView()
                        .tint(ColorTokens.gold)
                        .scaleEffect(0.8)
                } else if isActionable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(16)
            .background(ColorTokens.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isActionable || isStarting)
        .opacity((!isActionable && row.session?.status != "in_progress") ? 0.6 : 1.0)
    }
}

// MARK: - AssessmentStartResult: Identifiable

extension AssessmentStartResult: Identifiable {
    var id: String { assessmentSessionId }
}
```

- [ ] **Step 2: Build check — iterate until green**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40
```

Expected: `BUILD SUCCEEDED`. Common issues to fix:
- `Identifiable` conformance redeclared (the extension existed in the old file too — remove it from one location).
- `sync()` return type mismatch (added `@discardableResult` + return type `AssessmentSyncResult?`).
- `onReceive` requires `import Combine` — add it if the compiler complains. Actually `NotificationCenter.default.publisher` is available via Combine — add `import Combine` at the top if needed.
- Swift 6 concurrency: `startGradePoll` mutates `@State` from a Task — that's fine since the Task is on @MainActor via the surrounding View context; if the compiler disagrees, wrap body in `await MainActor.run { }`.

- [ ] **Step 3: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsView.swift ScaleUp.xcodeproj
git commit -m "feat(placements): harden assessments view — error mapping, capstone pair screen, poll, foreground refresh, score/dates"
```

---

## Task 5: Final build verification + report + main commit

**Files:**
- No new source changes — this task verifies, writes the report, and does the final commit.

- [ ] **Step 1: Full clean build**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
xcrun simctl list devices available | grep iPhone | head -5
xcodegen generate && xcodebuild -scheme ScaleUp -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40
```

Expected: last line contains `BUILD SUCCEEDED`.

- [ ] **Step 2: Capture SHA**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git log --oneline -5
```

- [ ] **Step 3: Write the report**

Write `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/.assessment-ios-hardening-report.md` with:
- Status (BUILD SUCCEEDED / FAILED)
- Git SHA of final commit
- Files modified/created
- Capstone pairing approach (built `PlacementCapstonePairView` reusing `CapstonePairingCodePanel` — NOT reusing `CapstonePairView` because it requires `CapstoneLibraryEntry` bundle and `CapstoneService`)
- The full BUILD line from xcodebuild tail
- Deferred items (MCQ onComplete hook — relies on foreground-refresh + grade-poll from item #4; in_progress resume — blocked at tap, relies on foreground refresh)
- Concerns (ISO8601 `expiresAt` parsing — uses plain `ISO8601DateFormatter()` which handles `Z`-suffixed strings but not fractional seconds; if backend sends `+00:00` format, consider `capstoneDecoder`)

- [ ] **Step 4: Omnibus commit (all hardening files)**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add \
  ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsApi.swift \
  ScaleUp/Features/Placements/Assessments/PlacementsAssessmentsView.swift \
  ScaleUp/Features/Placements/Assessments/PlacementCapstonePairView.swift \
  ScaleUp/Features/Placements/Assessments/PlacementInterviewTakeView.swift \
  ScaleUp.xcodeproj \
  .assessment-ios-hardening-report.md
git commit -m "feat(placements): student take-flow hardening — capstone pairing, mic gate, async-grade refresh, error mapping [iOS]"
```

---

## Self-Review Against Spec

**Spec coverage check:**

| Item | Task | Status |
|------|------|--------|
| 1. Capstone real pairing screen | Task 2 | Covered — `PlacementCapstonePairView` with `CapstonePairingCodePanel`, 20s sync poll |
| 2. Mic permission gate before attachSession | Task 3 | Covered — `requestMicPermission()` in `PlacementInterviewTakeView`, denial screen + Settings link |
| 3. Error code mapping NOT_OPEN/CLOSED/NOT_ENROLLED | Task 4 (`friendlyError`) | Covered — maps both `V2APIError.extractCode()` and `APIError.conflictWithCode` |
| 4. Submitted-not-graded refresh + foreground refresh | Task 4 | Covered — `startGradePoll` (20s × 15), `onReceive(didBecomeActiveNotification)` |
| 5. Interview results no auto-dismiss + Retry/Close error | Task 3 | Covered — `showResultsOverlay` Done button, `placementErrorOverlay` |
| 6. MCQ completion sync | Task 4 (note) | Partially — sync fires on dismiss (existing); foreground + grade poll catches completion. No onComplete hook added to `PlanTaskQuizLoaderSheet` (D2C risk). Deferred. |
| 7a. Guard re-tap in_progress | Task 4 | Covered — early `return` in `handleTap` for in_progress |
| 7b. Graded score display | Task 4 | Covered — `statusLabel` includes score % |
| 7c. Opens/Closes display | Task 4 | Covered — `windowLabel` in `AssessmentRowCard` |
| 7d. Expired status label | Task 4 | Covered — "Expired" label + opacity dimming |
| 7e. Auto-clear startError | Task 4 | Covered — `startError = nil` at top of `handleTap` |
| `pairingCode/expiresAt/timeBudgetSeconds` in meta | Task 1 | Covered |
| V2APIError.extractCode | Task 1 | Covered |
| Capstone pairing approach note in report | Task 5 | Covered |

**Placeholder scan:** No TBDs, TODOs, or vague steps — all code blocks are complete and compilable.

**Type consistency check:**
- `PlacementCapstonePairView(start: AssessmentStartResult, onClose: () -> Void)` — matches usage in Task 4's sheet.
- `PlacementInterviewTakeView(start: AssessmentStartResult, onComplete: () -> Void)` — matches usage in Task 4's interview sheet.
- `api.syncSession(_ sessionId: String) -> AssessmentSyncResult` (returns `AssessmentSyncResult` which has `status: String?`) — matches `result.status == "graded"` checks in poll code.
- `AssessmentMeta.pairingCode: String?`, `expiresAt: String?`, `timeBudgetSeconds: Int?` — all accessed via `start.meta?.pairingCode` etc. consistently.
- `V2APIError.extractCode() -> String?` extension — used in `friendlyError(_:for:)` correctly.

One concern: `PlacementsAssessmentsView` has `import UIKit` for `UIApplication.didBecomeActiveNotification`. Swift 6 / SwiftUI projects often have UIKit available implicitly but the explicit import prevents ambiguity. Also add `import Combine` if `onReceive` is used (it's a Combine publisher API).

**Fix for `onReceive` + Combine:** If the build fails with "value of type 'View' has no member 'onReceive'", add `import Combine` at the top of `PlacementsAssessmentsView.swift`.
