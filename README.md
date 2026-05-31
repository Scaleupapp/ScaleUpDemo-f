# ScaleUp — iOS

Native iOS client for ScaleUp, an outcome-driven adaptive learning platform. Learners declare an objective (placement, role switch, interview prep, competitive exam, upskilling), and the system computes the path, runs diagnostics, generates a personalized plan, and tracks a single **Readiness Score** that compounds toward the goal.

> **Status:** V2 redesign is live on TestFlight. Build 176+ on `master`. iOS is the lead platform; Android is still on V1 parity.

---

## What the App Does

ScaleUp organizes learning around a few core surfaces:

- **Home** — One hero recommended task + readiness trajectory + "This Week" card. Activity palette, not a forced track.
- **Learn** — Content discovery (videos, articles, lessons, mindmaps), gap-path rail, AI + editorial curation.
- **Compass** — Single unified AI companion with four modes: Tutor, Quiz, Plan, Motivation. Persistent thread, daily token budget.
- **You** — Readiness ring, target date, week progress, top-gap CTA, per-topic mastery drill-down, multi-objective switcher.

### Capabilities

| Area | What it does |
|---|---|
| **Auth** | Phone-first OTP (no SSO). Phone → OTP → existing logs in, new registers + onboards. |
| **Onboarding** | Objective selection → Reality Check (declared vs actual) → Calibration Insights. |
| **Diagnostic** | Adaptive baseline per objective. Computes knowledge + behavioral + cognitive gaps; produces calibration report + trajectory forecast + top-3 leverage actions. |
| **Adaptive Plan** | Day-by-day plan; predicted impact per task; weekly recalibration based on quiz performance, skip rates, time invested. |
| **Quizzes** | On-demand AI-generated quizzes after content; daily role-specific skill assessments. |
| **Notes** | AI-assisted note-taking from lessons; optional publish to Creator Hub; auto-flashcards. |
| **Interview Practice** | Mock interviews (technical + behavioral). Dual pipeline: **Gemini Live** (real-time streaming) or **Whisper + GPT-4o + TTS** (async fallback). |
| **Coding Drills & Capstones** | Daily meta-skill **drills** (Prompt / Bug-Hunt / Decompose) and longer **capstones** coded on a paired laptop (mobile = command + anti-cheat surface), 6-dimension AI scoring + voice reflection. Auto-assembled **tracks**, a paste-a-JD **capstone generator** (Claude drafts → sandbox-proven → Gemini quality-reviewed → async, notifies on ready), recruiter **share** links (scores only, no code), and Compass-as-Coder pair-programmer. All under one **Coding** hub (Practice / Capstones / Progress). Languages: JS/TS, Python, Java, SQL, Go, Rust, Kotlin, Swift, C++. |
| **Readiness & Mastery** | 0–100 readiness ring visible everywhere; per-topic mastery, coverage + recall, trajectory forecast. |
| **Creator Hub** | Apply, tier up, upload lessons/notes, view reach/engagement/outcome analytics. |
| **Competition & Cohorts** | Opt-in skill challenges, leaderboards, quiet streak tracking. No global feed. |
| **Analytics** | Mixpanel (product) + push notifications for milestones/prompts. |

See [LEGACY_V1.md](LEGACY_V1.md) for the V1 surfaces that are now deprecated, and [BackendReq.md](BackendReq.md) for the contract this app expects from the backend.

---

## Tech Stack

- **Language:** Swift 6.0
- **UI:** SwiftUI
- **Min iOS:** 17.0
- **Xcode:** 16.0
- **Project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) via [project.yml](project.yml)
- **Dependencies (SPM):**
  - [Nuke](https://github.com/kean/Nuke) 12.0.0 — image loading
  - GoogleSignIn 8.0.0
  - Mixpanel 6.0.0
- **API types:** auto-generated from backend `openapi.yaml` into `ScaleUp/Generated/`

---

## Repository Layout

```
ScaleUpDemo-f/
├── project.yml              # XcodeGen project spec — the source of truth
├── ScaleUp/
│   ├── App/                 # App entry, scene config
│   ├── Core/                # Analytics, networking, storage, upload, push, coach marks
│   ├── DesignSystem/        # Tokens + reusable UI components
│   ├── Features/            # Feature modules (one folder per surface)
│   │   ├── auth/            # Phone OTP, login, registration
│   │   ├── onboarding/      # V2 onboarding flow
│   │   ├── diagnostic/      # Baseline assessment + calibration
│   │   ├── home/            # V2 Home (hero task, trajectory)
│   │   ├── discover/        # Learn tab content discovery
│   │   ├── plan/            # Adaptive plan + recalibration
│   │   ├── quiz/            # Quiz player, on-demand, daily
│   │   ├── notes/           # Notes + flashcards
│   │   ├── player/          # Content player (video / article)
│   │   ├── interview/       # Mock interview (Gemini Live + async)
│   │   ├── Coding/          # Coding drills + capstones (hub, generator, tracks, preflight, pair, live, result, share)
│   │   ├── progress/        # Mastery, readiness ring, analytics
│   │   ├── journey/         # Journey timeline
│   │   ├── competition/     # Cohorts, leaderboards
│   │   ├── creator/         # Creator Hub
│   │   ├── circles/         # Cohort interactions
│   │   ├── profile/         # You tab + settings
│   │   ├── notifications/   # In-app notification center
│   │   ├── splash/          # Launch
│   │   └── v2/              # V2-specific shared components
│   ├── Models/              # AITutor, Competition, Content, Plan, Quiz, etc.
│   ├── Generated/           # OpenAPI-generated Swift types — DO NOT edit by hand
│   ├── Resources/           # Assets, fonts, plists
│   └── Preview Content/     # SwiftUI previews
├── Tests/                   # ScaleUpTests + ScaleUpUITests
├── scripts/                 # Build / OpenAPI regen scripts
├── docs/                    # Design + product docs
├── pitch/                   # Pitch / keynote assets
├── LEGACY_V1.md
└── BackendReq.md
```

---

## Setup

### Prerequisites

```sh
brew install xcodegen
sudo gem install cocoapods   # only if you add Pods later; current build is SPM-only
```

You also need Xcode 16.0+ and command line tools.

### First-time setup

```sh
# 1. Generate the .xcodeproj from project.yml
xcodegen generate

# 2. Open
open ScaleUp.xcodeproj
```

> **Important — TestFlight version bumps:**
> Use the full `xcodegen` path when regenerating. If `xcodegen` is invoked via a stale shell alias, the new bundle version silently fails to apply and the TestFlight upload errors with a version-collision. Prefer the script under `scripts/` or invoke the absolute path from Homebrew.

### Regenerate API types

After the backend's `openapi.yaml` changes:

```sh
./scripts/regenerate-openapi-types.sh
```

This rewrites `ScaleUp/Generated/`. Commit the result alongside the feature that needs it.

---

## Build & Run

```sh
# Build for simulator
xcodebuild -scheme ScaleUp -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild test -scheme ScaleUp -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or just hit ⌘R in Xcode.

---

## Release / TestFlight

- Marketing version: `1.0.0`
- Current build: `176` (see [project.yml](project.yml))
- Team: `NK5P69WG2H`
- Signing: Automatic (Apple Distribution)

Steps:

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Run `xcodegen generate` (use full path — see warning above).
3. Archive in Xcode → Distribute → App Store Connect.
4. App Store Connect API credentials are documented in the local memory (issuer ID, key path, team ID).

---

## Backend Dependency

This app talks to [scaleup-backend](../ScaleUpDemo/scaleup-backend) (default `http://localhost:5000` in dev, EC2 in prod). Auth uses JWT access + refresh; SMS OTP comes via Twilio on the backend.

API base URL is configured in `ScaleUp/Core/` networking layer. Keep `Generated/` in sync with backend `openapi.yaml`.

---

## Integrations

| Integration | Used for | Where configured |
|---|---|---|
| Mixpanel | Product analytics | Token in build config |
| Google Sign-In | Optional social auth surface | SPM dep + Info.plist URL scheme |
| APNs | Push notifications | Entitlements + Core/PushNotificationManager |
| Backend (Twilio) | Phone OTP | Backend-side only |

---

## V1 vs V2

- **V1** (deprecated): 5-tab nav (Home/Discover/Plan/Progress/Profile), multi-banner home, 11 fragmented AI surfaces.
- **V2** (current): 4-tab nav (Home/Learn/Compass/You), one hero task, single Compass AI, readiness ring universal.

V2 is gated by a feature flag for per-user rollback if needed. See [LEGACY_V1.md](LEGACY_V1.md).

---

## Conventions

- Don't edit `ScaleUp/Generated/` by hand — regenerate from backend OpenAPI.
- Feature modules under `Features/` are self-contained; cross-feature shared code lives in `Core/` or `DesignSystem/`.
- New screens should bind to the Readiness Score where relevant — it is the universal lens.
- SwiftUI previews live under `Preview Content/`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| TestFlight rejects build with version collision | You ran `xcodegen` via stale alias — use full path, regenerate, re-archive. |
| API types out of sync after backend change | Run `scripts/regenerate-openapi-types.sh` and commit `Generated/`. |
| Missing Mixpanel events in prod | Confirm token is set in Release config, not just Debug. |
| OTP not arriving | Backend / Twilio issue — check backend logs, not the app. |

---

## Related Docs

- [LEGACY_V1.md](LEGACY_V1.md) — what V1 looked like, why V2 replaces it
- [BackendReq.md](BackendReq.md) — backend contract this app expects
- [docs/](docs/) — design + product docs
- Backend repo: `../ScaleUpDemo/scaleup-backend`
- Android repo: `../ScaleUpAndroid`
