# Legacy V1 — Removal Tracking

Merged v2-redesign into master on 2026-05-18. The following v1 files were
replaced by v2 equivalents but are kept in the codebase to allow rollback
if the v2 launch hits issues.

The v1 fallback is still wired: `V2RootView` shows `MainTabView` (v1) when
`V2FeatureFlag.isEnabled` is false, and `ScaleUpApp` still routes existing
users through `OnboardingContainerView`. The deprecated surfaces below are
the parts of v1 that v2 has explicitly replaced and that have **no caller
inside `Features/V2/`** (either directly or via a transitively-reused v1
surface). They will be deleted in a follow-up cleanup PR once v2 is proven
stable in production.

## Removal timeline
- **2026-05-18** — v2 merged to master, v1 files marked `@deprecated`
- **2026-05-18 → 2026-06-15** — monitor crash rate + user reports on v2
- **2026-06-15** (4 weeks) — if no rollback needed, run the removal PR
- **2026-06-30** — final cleanup of any LOW-confidence files that survived

## How to remove

After 2026-06-15, if metrics look good:

1. `git rm` every HIGH-confidence file listed below
2. Run the build; resolve any compile errors by deleting the stale callers
   (they're also v1 — `MainTabView` and its `Tab.view` switch land here)
3. Walk the MEDIUM list manually — confirm each is truly unreachable, then
   `git rm`
4. Walk the LOW list — each needs explicit human judgment
5. Delete `App/MainTabView.swift` and simplify `V2RootView` to always show
   `V2MainTabView` (drop the `flag.isEnabled` branch)
6. Delete this `LEGACY_V1.md`
7. Single PR titled `chore: remove legacy v1 surfaces (post-v2 cleanup)`

---

## HIGH confidence dead files (32)

These are reachable only from v1 tab roots (or are total orphans with zero
callers anywhere). Marked with `@available(*, deprecated)`. Compile produces
warnings on the remaining v1 call sites (e.g. `MainTabView` → `HomeView`);
those go away when the listed file is deleted.

### App-level

| File | Replaced by |
|---|---|
| `ScaleUp/App/MainTabView.swift` | `Features/V2/Core/V2MainTabView.swift` (see MEDIUM — kept live for now) |

### Home tab (replaced by `V2HomeView`)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Home/Views/HomeView.swift` | `Features/V2/Home/V2HomeView.swift` |
| `ScaleUp/Features/Home/ViewModels/HomeViewModel.swift` | `Features/V2/Home/V2HomeViewModel.swift` |
| `ScaleUp/Features/Home/Services/DashboardService.swift` | v2 reads `/api/v2/home/*` via `V2APIClient` |
| `ScaleUp/Features/Home/Services/CalibrationPromptStore.swift` | v2 uses server-side cooldown only |
| `ScaleUp/Features/Home/ViewModels/PlanBrewingViewModel.swift` | inlined into `V2HomeViewModel` |
| `ScaleUp/Features/Home/Views/PlanBrewingPill.swift` | inlined into `V2HomeView` |
| `ScaleUp/Features/Home/Views/ReadinessScoreCard.swift` | `V2HomeView` readiness popover |
| `ScaleUp/Features/Home/Views/CalibrationBannerView.swift` | Compass-driven prompt |
| `ScaleUp/Features/Home/Views/SeeAllContentView.swift` | `V2LearnView` |
| `ScaleUp/Features/Home/Views/Components/PlanGenerationBanner.swift` | inlined into `V2HomeView` |

### Plan tab (replaced by `V2PlanHomeView` / `V2PlanDetailView`)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Plan/Views/PlanTabView.swift` | `Features/V2/Compass/V2PlanHomeView.swift` + `Features/V2/You/V2PlanDetailView.swift` |
| `ScaleUp/Features/Plan/ViewModels/PlanTabViewModel.swift` | `Features/V2/You/V2PlanDetailViewModel.swift` |
| `ScaleUp/Features/Plan/Services/PlanService.swift` | `V2APIClient` against `/api/v2/plan/*` |
| `ScaleUp/Features/Plan/Views/RecalibrationNudge.swift` | Compass-driven prompt |
| `ScaleUp/Features/Plan/Views/Components/GeneratingPlanView.swift` | inlined into `V2HomeView` |
| `ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift` | `V2PlanDetailView` timeline |
| `ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift` | `V2TaskRouter` auto-completion |
| `ScaleUp/Features/Plan/Views/Components/MilestonePreview.swift` | `V2PlanDetailView` milestone strip |
| `ScaleUp/Features/Plan/Views/Components/NextCheckInPill.swift` | inlined into `V2PlanDetailView` |
| `ScaleUp/Features/Plan/Views/Components/ObjectiveBriefCard.swift` | inlined into `V2YouObjectivesView` |
| `ScaleUp/Features/Plan/Views/Components/TaskRow.swift` | rebuilt in `V2PlanDetailView` |
| `ScaleUp/Features/Plan/Views/Components/ThisWeekTasksList.swift` | `V2HomeView` "This Week" card |
| `ScaleUp/Features/Plan/Views/Components/TopicMasterySection.swift` | `V2YouAnalyticsView` |

### Progress tab (replaced by `V2YouAnalyticsView`)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Progress/Views/ProgressTabView.swift` | `Features/V2/You/V2YouAnalyticsView.swift` |
| `ScaleUp/Features/Progress/ViewModels/ProgressViewModel.swift` | `Features/V2/You/V2YouViewModel.swift` |
| `ScaleUp/Features/Progress/Views/GapsView.swift` | `V2LearnView` gap-path rail |
| `ScaleUp/Features/Progress/Views/ConsumptionHistoryView.swift` | `V2YouAnalyticsView` |
| `ScaleUp/Features/Progress/Views/RecalibrationCard.swift` | Compass-driven prompt |
| `ScaleUp/Features/Progress/Views/TopicDetailView.swift` | `V2YouAnalyticsView` topic drill-down |
| `ScaleUp/Features/Progress/ViewModels/TopicDetailViewModel.swift` | rolled into `V2YouViewModel` |
| `ScaleUp/Features/Progress/RecommendationService.swift` | `V2LearnViewModel` paths |

### Journey (replaced by v2 plan/objective surfaces)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Journey/JourneyService.swift` | `V2APIClient` against `/api/v2/plan/*` |
| `ScaleUp/Features/Journey/ViewModels/MyPlanViewModel.swift` | `V2PlanDetailViewModel` |
| `ScaleUp/Features/Journey/Views/MyPlanView.swift` | `V2PlanDetailView` |
| `ScaleUp/Features/Journey/Views/GenerateJourneyView.swift` | `V2PlanCreationView` |
| `ScaleUp/Features/Journey/Views/MilestonesView.swift` | `V2PlanDetailView` milestones section |
| `ScaleUp/Features/Journey/Views/AddMilestoneSheet.swift` | superseded — v2 milestones are server-generated |
| `ScaleUp/Features/Journey/Views/ObjectiveBriefView.swift` | `V2YouObjectivesView` brief |

### Quiz list/detail (replaced by `V2TaskRouter` quiz launch)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Quiz/Views/QuizListView.swift` | `V2TaskRouter` + `PlanTaskQuizLoaderSheet` |
| `ScaleUp/Features/Quiz/Views/QuizDetailView.swift` | direct launch via `V2TaskSheet` |
| `ScaleUp/Features/Quiz/ViewModels/QuizListViewModel.swift` | n/a — quiz lists no longer browsed |

### Discover orphans (zero callers)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Discover/Views/ContentDetailView.swift` | `V2ContentDispatcher` in `V2TaskSheet` |
| `ScaleUp/Features/Discover/Views/ExploreGridView.swift` | n/a — DiscoverView no longer renders this grid |

### Common orphans (zero callers)

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Common/Views/ObjectiveSwitcherView.swift` | `V2YouObjectivesView` |
| `ScaleUp/Features/Circles/Views/TextSourceSheet.swift` | n/a — Circles feature was never shipped |

### Competition components used only by dead HomeView/ProfileTab

| File | Replaced by |
|---|---|
| `ScaleUp/Features/Competition/Views/DailyChallengeCarousel.swift` | `V2CompetitionHomeView` |
| `ScaleUp/Features/Competition/Views/CompetitionStatsSection.swift` | `V2YouAnalyticsView` |

### Tests of dead code

| File | Notes |
|---|---|
| `Tests/UnitTests/CalibrationPromptStoreTests.swift` | Tests `CalibrationPromptStore` (deprecated). Remove with subject. |

---

## MEDIUM confidence (5)

These have one or two indirect references that a human should confirm before
deletion. Marker is a comment header only — no `@available` annotation (it
would generate warnings on the still-active call sites that must be cleaned
up first).

| File | Notes |
|---|---|
| `ScaleUp/App/MainTabView.swift` | Still wired as fallback in `V2RootView` when `V2FeatureFlag.isEnabled` is false. Remove this when the v1 fallback is retired (simplify `V2RootView` to always render `V2MainTabView`). |
| `ScaleUp/Features/Auth/Views/LoginView.swift` | Per `feedback_auth_flow_decision`, auth is phone-first OTP only; email login is no longer offered. Still navigable from `WelcomeView`'s "Sign In with Email" button — that button + this view should go together. |
| `ScaleUp/Features/Auth/Views/RegisterView.swift` | Same as above — email registration. |
| `ScaleUp/Features/Auth/Views/ForgotPasswordView.swift` | Only reachable from `LoginView`. |
| `ScaleUp/Features/Profile/Views/ProfileTabView.swift` | Defines `FollowListSheet` which v2 reuses. The rest of the file (the v1 Profile tab) is dead. Recommend extracting `FollowListSheet` into its own file before deleting `ProfileTabView`. |

---

## LOW confidence — needs human review (3)

Listed only; no markers applied.

| File | Why uncertain |
|---|---|
| `ScaleUp/Features/Profile/Views/AITutorHistoryView.swift` | Spec lists this as "not deprecated" in the v2 reuse list, but the only caller found is `ProfileTabView.swift` (dead). If v2 doesn't actually reuse this, it's HIGH dead. Needs confirmation from the v2 You-tab author. |
| `ScaleUp/Features/Notes/Views/MyFlashcardsView.swift` | Only caller is `ProfileTabView`. If `ProfileTabView` goes, this likely goes too — but flashcards may want a v2 surface that doesn't yet exist. |
| `ScaleUp/Features/Notes/Views/NotesAnalyticsView.swift` | Only caller is `ProfileTabView`. Same situation as above. |

---

## Not deprecated (intentionally — still load-bearing for v2)

These v1 surfaces are deliberately reused by v2 and must NOT be deleted:

`EditProfileSheet`, `FollowListSheet`, `CreatorApplicationView`,
`ApplicationStatusView`, `AdminDashboardView`, `UserManagementView`,
`CreatorPromotionView`, `ContentModerationView`, `PendingApplicationsView`,
`PendingNotesReviewView`, `CreateContentView`, `MyContentView`,
`EditContentView`, `SettingsView`, `NotificationListView`,
`AddObjectiveSheet`, `MyNotesView`, `NotesDetailView`, `FlashcardStudyView`,
`InterviewSessionView`, `InterviewHistoryView`, `AITutorHistoryView`,
`CompetitionHubView`, `ChallengeSessionView`, `PlaylistDetailView`,
`DiscoverView`.

Also load-bearing and explicitly verified during the audit (transitively
reachable from a reused v1 surface — do not delete):

- `Features/Discover/Views/CreatorProfileView.swift` (via `DiscoverView` + `PlayerView`)
- `Features/Notes/Views/ContentDestinationView.swift` (via `V2YouSections`)
- `Features/Notes/Views/MindMapView.swift`, `AudioSummaryPlayerView.swift`,
  `NoteManageView.swift` (via `NotesDetailView` / `MyNotesView`)
- `Features/Notes/Views/ContributorCardView.swift`,
  `CreateNoteRequestSheet.swift`, `NoteRequestDetailView.swift`,
  `NoteRequestsListView.swift`, `CreateNotesView.swift` (note flow)
- `Features/Notes/Services/NotesService.swift`, `NoteRequestService.swift`
- `Features/Notes/ViewModels/CreateNotesViewModel.swift`
- `Features/Interview/**` (entire interview stack — reused by `V2TaskSheet`)
- `Features/Competition/Views/LeaderboardView.swift`,
  `LiveEventLobbyView.swift`, `LiveEventSessionView.swift`,
  `LiveEventResultsView.swift`, `ChallengeResultsView.swift`,
  `ChallengeReviewView.swift`, `ShareScoreCardView.swift` (transitively
  reached via `CompetitionHubView` / `ChallengeSessionView`)
- `Features/Competition/Services/CompetitionService.swift`,
  `ViewModels/ChallengeViewModel.swift`, `LeaderboardViewModel.swift`,
  `LiveEventViewModel.swift`
- `Features/Player/**` (entire player stack — reused by `V2TaskSheet`)
- `Features/Quiz/Views/QuizSessionView.swift`, `QuizResultsView.swift`
- `Features/Quiz/ViewModels/QuizSessionViewModel.swift`, `QuizResultsViewModel.swift`
- `Features/Quiz/Services/QuizService.swift`
- `Features/Diagnostic/**` (entire diagnostic stack — `DiagnosticContainerView`
  remains the entry point under `ScaleUpApp.swift` for both v1 and v2 users;
  v2 only swaps the post-diagnostic results screen)
- `Features/Onboarding/**` (still used by v1 fallback users)
- `Features/Auth/Views/{WelcomeView,PhoneAuthView,PhoneVerificationView}.swift`
- `Features/Auth/{Services,ViewModels}/**`
- `Features/Splash/**`
- `Features/Profile/Views/{EditProfileSheet,CreatorApplicationView,
  ApplicationStatusView,AdminDashboardView,UserManagementView,
  CreatorPromotionView,ContentModerationView,PendingApplicationsView,
  AddObjectiveSheet,ImageCropView,ProfileHeaderView,SettingsView}.swift`
- `Features/Profile/Services/**`, `Features/Profile/ViewModels/**`,
  `Features/Profile/UserInferenceService.swift`
- `Features/Notifications/**`
- `Features/Journey/ObjectiveService.swift` (used by `ObjectiveContext`,
  `AddObjectiveSheet`, `ProfileViewModel`, `InterviewSetupView`)
- `Features/Progress/KnowledgeService.swift` (used by `V2LearnViewModel`)
- `Features/Creator/**`
- `Features/Diagnostic/**`
