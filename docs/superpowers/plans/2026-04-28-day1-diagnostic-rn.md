# Day-1 Diagnostic — React Native (Android) Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Add the Day-1 Diagnostic flow to the React Native app — new users land in the diagnostic immediately after onboarding; output drives plan generation.

**Architecture:** New screens module under `src/screens/diagnostic/`. New `diagnosticService.ts` mirroring `quizService.ts`. New Redux slice. App-state extended with a `'diagnostic'` value rendered by `AppNavigator` between `'onboarding'` and `'home'`.

**Tech Stack:** TypeScript, React Native, Redux Toolkit, axios, React Navigation v7.

**Repo:** `/Users/nirpekshnandan/My Products/ScaleUpAndroid`
**Branch:** `feature/day1-diagnostic-rn` (to be created)

---

## File structure

- Create `src/models/diagnostic.ts` — TypeScript types for all DTOs
- Create `src/services/diagnosticService.ts` — API surface
- Create `src/store/slices/diagnosticSlice.ts` — phase + state
- Create `src/screens/diagnostic/DiagnosticContainer.tsx` — phase router
- Create `src/screens/diagnostic/WelcomeScreen.tsx`
- Create `src/screens/diagnostic/SelfRatingScreen.tsx`
- Create `src/screens/diagnostic/QuestionScreen.tsx`
- Create `src/screens/diagnostic/ResultsScreen.tsx`
- Modify `src/store/index.ts` — register diagnostic reducer
- Modify `src/store/slices/authSlice.ts` — extend `appState` union with `'diagnostic'`; add `diagnosticComplete?: boolean` to user
- Modify `src/types/auth.ts` (or wherever User type lives) — add `diagnosticComplete?: boolean`
- Modify `src/navigation/AppNavigator.tsx` — render `<DiagnosticContainer />` when `appState === 'diagnostic'`
- Modify `src/services/analytics/AnalyticsEvent.ts` — add 4 new event types

---

## Phase A — Foundations

### Task A: Models, service, slice, analytics, navigation gate

**Goal:** All non-UI plumbing in place. Compiles + passes typecheck.

1. **Create `src/models/diagnostic.ts`:**
```ts
export type FlowType = 'new_user' | 'existing_user_tune';
export type SelfRating = 'novice' | 'familiar' | 'proficient' | 'expert' | 'unsure';

export interface DiagnosticCompetency {
  name: string;
  questionCap: number;
}

export interface DiagnosticOption {
  key: string;     // "A" | "B" | "C" | "D"
  text: string;
}

export interface DiagnosticQuestion {
  _id: string;
  competency: string;
  difficulty: 'easy' | 'medium' | 'hard';
  prompt: string;
  options: DiagnosticOption[];
}

export interface DiagnosticAttemptStart {
  attemptId: string;
  flowType: FlowType;
  competenciesToAssess: DiagnosticCompetency[];
}

export interface DiagnosticNextQuestion {
  question?: DiagnosticQuestion;
  done?: boolean;
}

export interface DiagnosticCompetencyResult {
  competency: string;
  score: number;          // 0-100
  band: SelfRating | 'expert';
  calibrationDelta?: number;
}

export interface DiagnosticResults {
  attemptId: string;
  results: DiagnosticCompetencyResult[];
}
```

2. **Create `src/services/diagnosticService.ts`:**
```ts
import { api } from './api';
import {
  DiagnosticAttemptStart,
  DiagnosticNextQuestion,
  DiagnosticResults,
  SelfRating,
} from '../models/diagnostic';

export const DiagnosticService = {
  start: () => api.post<DiagnosticAttemptStart>('/diagnostic/start'),
  submitSelfRating: (attemptId: string, ratings: Record<string, SelfRating>) =>
    api.post<void>(`/diagnostic/${attemptId}/self-rating`, { ratings }),
  nextQuestion: (attemptId: string) =>
    api.get<DiagnosticNextQuestion>(`/diagnostic/${attemptId}/next-question`),
  submitAnswer: (attemptId: string, payload: { questionId: string; selectedAnswer: string; timeTaken: number }) =>
    api.post<void>(`/diagnostic/${attemptId}/answer`, payload),
  finish: (attemptId: string) =>
    api.post<DiagnosticResults>(`/diagnostic/${attemptId}/finish`),
  abandon: (attemptId: string) =>
    api.post<void>(`/diagnostic/${attemptId}/abandon`),
};
```
(If `api.post` requires a body argument explicitly, pass `undefined` or `{}` for the no-body endpoints.)

3. **Add 4 events to `src/services/analytics/AnalyticsEvent.ts`** (extend the union):
```ts
| { type: 'diagnostic_started'; flow_type: FlowType }
| { type: 'diagnostic_self_rating_submitted'; attempt_id: string }
| { type: 'diagnostic_finished'; attempt_id: string; duration_seconds: number; score: number }
| { type: 'diagnostic_abandoned'; attempt_id?: string; at_step: string }
```
Import `FlowType` from `../../models/diagnostic`. If the file's pattern is to inline string literals rather than importing types, keep `flow_type: string` for consistency.

4. **Create `src/store/slices/diagnosticSlice.ts`:**
```ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import {
  DiagnosticCompetency,
  DiagnosticQuestion,
  DiagnosticResults,
  SelfRating,
} from '../../models/diagnostic';

export type DiagnosticPhase = 'welcome' | 'selfRating' | 'quiz' | 'results' | 'error';

interface DiagnosticState {
  phase: DiagnosticPhase;
  attemptId: string | null;
  competencies: DiagnosticCompetency[];
  selfRatings: Record<string, SelfRating>;
  currentQuestion: DiagnosticQuestion | null;
  currentSelection: string | null;
  questionsAnswered: number;
  totalQuestionsTarget: number;
  results: DiagnosticResults | null;
  isLoading: boolean;
  errorMessage: string | null;
  startedAt: number | null;
  currentQuestionStartedAt: number | null;
}

const initialState: DiagnosticState = {
  phase: 'welcome',
  attemptId: null,
  competencies: [],
  selfRatings: {},
  currentQuestion: null,
  currentSelection: null,
  questionsAnswered: 0,
  totalQuestionsTarget: 0,
  results: null,
  isLoading: false,
  errorMessage: null,
  startedAt: null,
  currentQuestionStartedAt: null,
};

const diagnosticSlice = createSlice({
  name: 'diagnostic',
  initialState,
  reducers: {
    setPhase: (s, a: PayloadAction<DiagnosticPhase>) => { s.phase = a.payload; },
    setLoading: (s, a: PayloadAction<boolean>) => { s.isLoading = a.payload; },
    setError: (s, a: PayloadAction<string | null>) => {
      s.errorMessage = a.payload;
      if (a.payload) s.phase = 'error';
    },
    started: (s, a: PayloadAction<{ attemptId: string; competencies: DiagnosticCompetency[] }>) => {
      s.attemptId = a.payload.attemptId;
      s.competencies = a.payload.competencies;
      s.totalQuestionsTarget = a.payload.competencies.reduce((sum, c) => sum + c.questionCap, 0);
      s.startedAt = Date.now();
      s.phase = 'selfRating';
    },
    setRating: (s, a: PayloadAction<{ competency: string; rating: SelfRating }>) => {
      s.selfRatings[a.payload.competency] = a.payload.rating;
    },
    selfRatingsSubmitted: (s) => { s.phase = 'quiz'; },
    questionLoaded: (s, a: PayloadAction<DiagnosticQuestion>) => {
      s.currentQuestion = a.payload;
      s.currentSelection = null;
      s.currentQuestionStartedAt = Date.now();
    },
    selectOption: (s, a: PayloadAction<string>) => { s.currentSelection = a.payload; },
    answerSubmitted: (s) => { s.questionsAnswered += 1; s.currentSelection = null; },
    finished: (s, a: PayloadAction<DiagnosticResults>) => { s.results = a.payload; s.phase = 'results'; },
    reset: () => initialState,
  },
});

export const diagnosticActions = diagnosticSlice.actions;
export const diagnosticReducer = diagnosticSlice.reducer;
```

5. **Modify `src/store/index.ts`:** import `diagnosticReducer` and register it under `diagnostic` key.

6. **Modify `src/store/slices/authSlice.ts`:**
   - Extend `AppState` type union with `'diagnostic'`.
   - Note: leave `setAppState` as is — it already accepts a string union.

7. **Modify the User type** (likely in `src/types/auth.ts` or `src/models/user.ts` — check actual location):
   - Add `diagnosticComplete?: boolean`.

8. **Modify `src/navigation/AppNavigator.tsx`:**
   - Add a branch: `if (appState === 'diagnostic') return <DiagnosticContainer />;` before the `home` branch.
   - In `handleOnboardingComplete`, gate: if user has `diagnosticComplete === true`, dispatch `setAppState('home')`; else `setAppState('diagnostic')`.
   - In any other place where the app transitions to `home` after auth (e.g., post-login if onboarding is already done), apply the same gate.

9. **Create stub `src/screens/diagnostic/DiagnosticContainer.tsx`:**
```tsx
import React from 'react';
import { View, Text } from 'react-native';
export const DiagnosticContainer: React.FC = () => (
  <View><Text>Diagnostic placeholder</Text></View>
);
```

**Verification:**
```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
npx tsc --noEmit
```
Must pass with zero errors.

**Commit:** `feat(diagnostic-rn): models, service, slice, analytics, navigation gate`

---

## Phase B — UI screens

### Task B: 4 screens + container wiring

Replace the stub container with the real phase-router. Each screen reads from `useAppSelector(s => s.diagnostic)` and dispatches actions / fires service calls.

#### `DiagnosticContainer.tsx`
- `useAppSelector` for `phase`, `isLoading`, `errorMessage`.
- Switch on `phase`: render `<WelcomeScreen />`, `<SelfRatingScreen />`, etc.
- Show `<ActivityIndicator>` overlay when `isLoading`.

#### `WelcomeScreen.tsx`
- Headline: "Let's tune your plan to you"
- Body: "A 5-minute check-in to gauge where you are. We use this to skip what you already know and double down on gaps."
- Primary `<PrimaryButton>` "Start" → calls `DiagnosticService.start()`, dispatches `started(...)`, fires `diagnostic_started` analytics. Loading state during call.
- Secondary `TouchableOpacity` "Skip for now" → fires `diagnostic_abandoned({at_step: 'welcome'})`, dispatches `setAppState('home')` and `diagnosticActions.reset()`.

#### `SelfRatingScreen.tsx`
- Header: "How would you rate yourself on each topic?"
- For each competency: topic name + horizontal scrolling chips for `SelfRating` values.
  - Use the chip pattern from `InterestsStep.tsx` (gold border + tinted bg when selected).
- "Continue" `PrimaryButton` enabled when every competency has a rating. On press: dispatch `setLoading(true)`, call `DiagnosticService.submitSelfRating(attemptId, selfRatings)`, then load the first question:
  - `const next = await DiagnosticService.nextQuestion(attemptId);`
  - `dispatch(selfRatingsSubmitted())`
  - if `next.question`: `dispatch(questionLoaded(next.question))`
  - else: call finish flow
- Fire `diagnostic_self_rating_submitted({attempt_id})`.

#### `QuestionScreen.tsx`
- Mirror `QuizSessionScreen.tsx`'s option chip layout (A/B/C/D circle + text).
- Top: "Question {questionsAnswered + 1} of {totalQuestionsTarget}" + thin gold progress bar.
- Question prompt card (`Colors.surface` background).
- 4 options as `TouchableOpacity` rows. Selected option: gold border + tint.
- Bottom Submit `PrimaryButton`, disabled when `currentSelection == null`.
  - On press: compute `timeTaken = (Date.now() - currentQuestionStartedAt) / 1000`. Call `DiagnosticService.submitAnswer(...)`. Dispatch `answerSubmitted`. Then call `nextQuestion`:
    - If `done` or no `question`: call `DiagnosticService.finish(attemptId)`, dispatch `finished(results)`, fire `diagnostic_finished` analytics.
    - Else: dispatch `questionLoaded`.

#### `ResultsScreen.tsx`
- Header: "Here's where you stand"
- For each `DiagnosticCompetencyResult`:
  - Topic + band label (capitalize)
  - Score bar (0-100 width with gold fill)
  - If `Math.abs(calibrationDelta ?? 0) >= 2`, callout: "We noticed your self-rating differed from your assessment — we'll fine-tune as you go."
- "Continue to my plan" `PrimaryButton` → `dispatch(setAppState('home'))`, `dispatch(diagnosticActions.reset())`.

**Verification:**
```bash
npx tsc --noEmit
```
Plus a Metro bundler dry-run (best-effort). Manual smoke deferred to user.

**Commit:** `feat(diagnostic-rn): full UI flow`

---

## Self-review

1. Spec coverage: A (foundations + gate), B (UI). Existing-user banner deferred (matches iOS).
2. No placeholders: all type signatures and slice action shapes complete.
3. Type consistency: `attemptId` is `string`, `selfRatings` keyed by competency name, option `key` field consistent.
4. Backward compat: `User.diagnosticComplete?` optional; navigation gate falls back to `home` if field missing.
