# Plan Tab Redesign — Phase 5: Journey Timeline + Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The final polish phase. Adds a horizontally-scrollable week strip (the journey timeline), refreshes the milestone footer visual, and wires Mixpanel instrumentation for `task_started`, `task_completed`, `external_link_opened`, and `recalibration_offered_from_plan` so the team can measure the redesign's impact against the spec §10 success criteria.

**Architecture:**
- Pure client-side work — no backend changes. The journey-timeline strip reads `plan.weeklySchedule[]` (already available since Phase 2) and shows one card per week with progress ring (`done/total tasks`). Tap a week card → scrolls the Plan tab to that week's task section. The milestone footer redesign refreshes the existing `MilestonePreview`/`milestonesSection` visual layer to match the new card style. Analytics events fire from existing tap handlers + completion paths.

**Tech Stack:** Swift 5 + SwiftUI (`ScrollViewReader` for scroll-to-week), React Native + TypeScript (FlatList horizontal for the strip + scrollTo for jump).

**Spec:** `docs/superpowers/specs/2026-05-09-plan-tab-redesign-design.md` §6.4 (journey timeline), §6.5 (milestone footer), §7 phase 5 (mixpanel instrumentation per success criteria §10).

**Phase 1-4 prerequisite (all on master/main):**
- Backend: `42312b9` (Phase 4 ExternalContentTouch wiring)
- iOS: `fe5f132` (Phase 4 external_link tap)
- Android: `506ee20` (Phase 4 external_link tap)

**Repo layout:**
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/ScaleUp/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

---

## File Structure

**Created:**
- `ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift`
- `ScaleUpAndroid/src/screens/plan/components/JourneyTimelineStrip.tsx`

**Modified:**
- `ScaleUp/Features/Plan/Views/PlanTabView.swift` — render JourneyTimelineStrip below NextCheckInPill; render this-week list inside `ScrollViewReader` with anchored sections per week; refresh `milestonesSection`; remove parked `weeklySection`; fire 4 new analytics events at the right moments.
- `ScaleUp/Core/Analytics/AnalyticsEvent.swift` — add 4 new events.
- `ScaleUpAndroid/src/screens/plan/PlanTabScreen.tsx` — same changes mirrored.
- `ScaleUpAndroid/src/services/analytics/AnalyticsEvent.ts` — add 4 new events.
- `ScaleUpAndroid/src/screens/plan/components/MilestonePreview.tsx` — refresh visual to match Phase 2 card style.

**Repo paths:**
- iOS: `/Users/nirpekshnandan/My Products/ScaleUpDemo-f/`
- Android: `/Users/nirpekshnandan/My Products/ScaleUpAndroid/`

Each task ends with a commit.

---

## Task 1: iOS — `JourneyTimelineStrip` + scroll integration

**Files:**
- Create: `ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift`
- Modify: `ScaleUp/Features/Plan/Views/PlanTabView.swift` — render strip below NextCheckInPill; rewrite `planContent(_:)` to use `ScrollViewReader` with `.id(weekNumber)` anchors so tap-on-week scrolls to that week's tasks; render ALL weeks (not just current) as collapsible sections.

The strip is horizontally scrollable, ~80pt-tall cards, one per week. Each card shows:
- Week number (eyebrow)
- Compact label (truncated `weekLabel`)
- Progress ring: `done / total` tasks for that week
- Current week highlighted with gold border; complete weeks faded; future weeks normal

Tap a card → scrolls the main Plan-tab list to that week's section.

- [ ] **Step 1: Create `JourneyTimelineStrip.swift`**

Create `ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift`:

```swift
import SwiftUI

struct JourneyTimelineStrip: View {
    let weeks: [APIPlanWeeklyEntry]
    let currentWeekNumber: Int?
    let onWeekTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                Text("YOUR JOURNEY")
                    .font(Typography.micro)
                    .tracking(1.4)
                    .foregroundStyle(ColorTokens.gold)
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(weeks, id: \.weekNumber) { week in
                        weekCard(week)
                            .onTapGesture { onWeekTap(week.weekNumber) }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func weekCard(_ week: APIPlanWeeklyEntry) -> some View {
        let tasks = week.tasks ?? []
        let done = tasks.filter { $0.progress.status == .complete }.count
        let total = tasks.count
        let isCurrent = (week.weekNumber == currentWeekNumber)
        let isComplete = total > 0 && done == total

        VStack(alignment: .leading, spacing: 6) {
            Text("WEEK \(week.weekNumber)")
                .font(Typography.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(week.weekLabel)
                .font(Typography.bodyBold)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                progressRing(done: done, total: total)
                Text(total > 0 ? "\(done)/\(total)" : "—")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(width: 168, height: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isCurrent ? ColorTokens.gold : ColorTokens.gold.opacity(0.10),
                            lineWidth: isCurrent ? 1.5 : 1
                        )
                )
        )
        .opacity(isComplete && !isCurrent ? 0.6 : 1.0)
    }

    private func progressRing(done: Int, total: Int) -> some View {
        let progress: Double = total > 0 ? Double(done) / Double(total) : 0
        return ZStack {
            Circle()
                .stroke(ColorTokens.gold.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ColorTokens.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
        .frame(width: 18, height: 18)
    }
}
```

If `Typography.bodyBold` differs (Phase 2.5 already used it), match. Same for `Spacing.lg/sm/md`.

- [ ] **Step 2: Rewrite `planContent(_:)` to use `ScrollViewReader` + per-week sections**

Open `ScaleUp/Features/Plan/Views/PlanTabView.swift`. The existing `planContent(_:)` looks roughly:

```swift
private func planContent(_ plan: PlanDTO) -> some View {
    ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ObjectiveBriefCard(plan: plan).padding(.horizontal, Spacing.lg)
            NextCheckInPill(...).padding(.horizontal, Spacing.lg)
            if let current = viewModel.currentWeekTasks(in: plan) {
                ThisWeekTasksList(weekNumber: current.weekNumber, weekLabel: current.weekLabel, tasks: current.tasks, onTaskTap: { handleTaskTap($0) })
            }
            if !plan.milestones.isEmpty { milestonesSection(plan.milestones) }
            Spacer().frame(height: Spacing.xxl)
        }
        .padding(.top, Spacing.md)
    }
}
```

Refactor to:
1. Wrap the inner `ScrollView` in `ScrollViewReader { proxy in ... }`.
2. Insert `JourneyTimelineStrip(weeks: plan.weeklySchedule, currentWeekNumber: viewModel.currentWeekTasks(in: plan)?.weekNumber, onWeekTap: { week in withAnimation { proxy.scrollTo(week, anchor: .top) } })` BELOW the `NextCheckInPill`.
3. Replace the single `ThisWeekTasksList` with a `ForEach(plan.weeklySchedule) { week in ThisWeekTasksList(...).id(week.weekNumber) }` so EVERY week is rendered, each with `.id(weekNumber)` for scroll-to anchoring. The `currentWeekNumber` is highlighted in the strip but not visually distinct in the list — Phase 5 surfaces all weeks together.
4. Keep ObjectiveBriefCard + NextCheckInPill + milestonesSection unchanged.
5. The `weeklySection` private function (parked since Phase 2) can now be deleted — Phase 5 supersedes it.

Replacement skeleton:

```swift
private func planContent(_ plan: PlanDTO) -> some View {
    ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ObjectiveBriefCard(plan: plan)
                    .padding(.horizontal, Spacing.lg)

                NextCheckInPill(
                    nextCheckInAt: plan.nextCheckInAt,
                    isEligibleNow: recalVM.eligibility?.eligible == true,
                    onRecalibrateTap: {
                        AnalyticsService.shared.track(.recalibrationOfferedFromPlan(source: "pill"))
                        showRecalibration = true
                    }
                )
                .padding(.horizontal, Spacing.lg)
                .onAppear {
                    if recalVM.eligibility?.eligible == true {
                        AnalyticsService.shared.track(.recalibrationOfferedFromPlan(source: "pill_seen"))
                    }
                }

                JourneyTimelineStrip(
                    weeks: plan.weeklySchedule,
                    currentWeekNumber: viewModel.currentWeekTasks(in: plan)?.weekNumber,
                    onWeekTap: { weekNumber in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(weekNumber, anchor: .top)
                        }
                    }
                )

                ForEach(plan.weeklySchedule, id: \.weekNumber) { week in
                    ThisWeekTasksList(
                        weekNumber: week.weekNumber,
                        weekLabel: week.weekLabel,
                        tasks: week.tasks ?? [],
                        onTaskTap: { handleTaskTap($0) }
                    )
                    .id(week.weekNumber)
                }

                if !plan.milestones.isEmpty {
                    milestonesSection(plan.milestones)
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.top, Spacing.md)
        }
    }
}
```

Note: `AnalyticsService.shared.track(.recalibrationOfferedFromPlan(source:))` is fired **once when the pill becomes eligible** (the `.onAppear` guard) AND **once when tapped**. Both events let the team measure both impression-to-conversion and raw click rate. The `source` field distinguishes them.

NOTE: the actual `currentWeekNumber` highlight in the strip still updates as tasks complete because `viewModel.currentWeekTasks(in: plan)` recomputes each render.

Now delete the parked `weeklySection(_:)` private function — search for `private func weeklySection` and remove the function and any helpers it uniquely calls. Inspect first:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
grep -n "weeklySection\|WeeklyAllocationCard\|private func" ScaleUp/Features/Plan/Views/PlanTabView.swift | head -20
```

If `WeeklyAllocationCard` is only called by `weeklySection`, also delete it.

- [ ] **Step 3: Refresh `milestonesSection` visuals**

The current `milestonesSection` likely just wraps `MilestonePreview`. Update it to add an eyebrow header matching the Phase 2/JourneyTimelineStrip card style. Find and replace:

```swift
private func milestonesSection(_ milestones: [APIPlanMilestone]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.gold)
            Text("MILESTONES")
                .font(Typography.micro)
                .tracking(1.4)
                .foregroundStyle(ColorTokens.gold)
        }
        MilestonePreview(milestones: milestones)
    }
    .padding(.horizontal, Spacing.lg)
}
```

(Adapt to whatever MilestonePreview looks like today — keep its rendering but wrap with the eyebrow.)

- [ ] **Step 4: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse \
  ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift \
  ScaleUp/Features/Plan/Views/PlanTabView.swift 2>&1 | tail -10
```

Expected: silent. If `recalibrationOfferedFromPlan` isn't yet defined on AnalyticsEvent, the parse will fail — that's wired in Task 2. To unblock parse-only test now, comment out the two analytics lines temporarily, parse, then uncomment.

OR: do Task 2 (analytics events) FIRST before parse-checking Task 1. Order Tasks 1+2 as a single atomic unit if you'd rather avoid the temp comment.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Features/Plan/Views/Components/JourneyTimelineStrip.swift ScaleUp/Features/Plan/Views/PlanTabView.swift
git commit -m "feat(ios-plan): JourneyTimelineStrip + per-week sections + milestone eyebrow"
```

---

## Task 2: iOS — Mixpanel events for task_started / task_completed / external_link_opened / recalibration_offered_from_plan

**Files:**
- Modify: `ScaleUp/Core/Analytics/AnalyticsEvent.swift`

Per spec §10, these four events feed the success criteria measurement:
- `task_started` — fires when user taps a task (any type)
- `task_completed` — fires when a task transitions to complete (manual completion sheet success OR after auto-complete confirms via reload)
- `external_link_opened` — fires when external_link tap successfully opens the URL
- `recalibration_offered_from_plan` — fires when the eligible-now CTA appears AND when tapped

For Phase 5 we add the events to the union and fire them from existing tap handlers / sheet completion / NextCheckInPill `.onAppear`.

- [ ] **Step 1: Add the events to `AnalyticsEvent`**

Open `ScaleUp/Core/Analytics/AnalyticsEvent.swift`. Find the existing `case planTaskTapped(taskType: String, taskId: String)` (line 140 area). Add four new events nearby:

```swift
    case planTaskStarted(taskType: String, taskId: String, topicCanonical: String)
    case planTaskCompleted(taskType: String, taskId: String, topicCanonical: String, selfRating: Int?)
    case externalLinkOpened(taskId: String, url: String, topicCanonical: String)
    case recalibrationOfferedFromPlan(source: String)
```

Then update the analytics name + properties switch (look at how `planTaskTapped` maps) to include these. Mirror the snake_case-named keys pattern used in the Android event union (`task_type`, `task_id`, `topic_canonical`, `self_rating`).

If the file uses a `var name: String` and `var properties: [String: Any]` computed properties switching on `self`, add cases like:

```swift
        case .planTaskStarted: return "plan_task_started"
        case .planTaskCompleted: return "plan_task_completed"
        case .externalLinkOpened: return "external_link_opened"
        case .recalibrationOfferedFromPlan: return "recalibration_offered_from_plan"
```

And properties:

```swift
        case .planTaskStarted(let taskType, let taskId, let topic):
            return ["task_type": taskType, "task_id": taskId, "topic_canonical": topic]
        case .planTaskCompleted(let taskType, let taskId, let topic, let selfRating):
            var props: [String: Any] = ["task_type": taskType, "task_id": taskId, "topic_canonical": topic]
            if let selfRating { props["self_rating"] = selfRating }
            return props
        case .externalLinkOpened(let taskId, let url, let topic):
            return ["task_id": taskId, "url": url, "topic_canonical": topic]
        case .recalibrationOfferedFromPlan(let source):
            return ["source": source]
```

- [ ] **Step 2: Fire `planTaskStarted` from `handleTaskTap`**

In `PlanTabView.swift`, find `handleTaskTap(_:)`. The existing first line fires `planTaskTapped`. Right after it (before the switch), add:

```swift
    AnalyticsService.shared.track(.planTaskStarted(
        taskType: typeRaw,
        taskId: task.taskId,
        topicCanonical: task.topic.canonicalName
    ))
```

Keep `planTaskTapped` firing too — it's the event the team has been collecting since Phase 2.5; `task_started` is the spec-required name. They mean the same thing semantically; fire both for the transition window.

- [ ] **Step 3: Fire `externalLinkOpened` from the externalLink case**

In the same `handleTaskTap`, in the `.externalLink` case AFTER `UIApplication.shared.open(url)`, add:

```swift
    AnalyticsService.shared.track(.externalLinkOpened(
        taskId: task.taskId,
        url: urlString,
        topicCanonical: task.topic.canonicalName
    ))
```

(`urlString` is already captured by the if-let.)

- [ ] **Step 4: Fire `planTaskCompleted` from the manual completion sheet**

Open `ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift`. Find the `submit()` function. Right after the successful `service.markTaskComplete(...)` call and before the `onComplete()` invocation, add:

```swift
    AnalyticsService.shared.track(.planTaskCompleted(
        taskType: task.type.rawValue,
        taskId: task.taskId,
        topicCanonical: task.topic.canonicalName,
        selfRating: selectedRating
    ))
```

For auto-completing tasks (quiz, content, interview, competition), Phase 5 doesn't fire `task_completed` from the client because the completion happens server-side. The team can derive auto-completion rates from server logs. (Phase 5+ improvement: have the server return the task's new status in API responses and fire the event when the Plan tab observes a transition.)

- [ ] **Step 5: Fire `recalibrationOfferedFromPlan`**

Already wired in Task 1 above (the `.onAppear` on the pill + the tap handler). Verify the source-tag values match (`"pill_seen"` for impression, `"pill"` for click).

- [ ] **Step 6: Parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && xcrun swiftc -parse \
  ScaleUp/Core/Analytics/AnalyticsEvent.swift \
  ScaleUp/Features/Plan/Views/PlanTabView.swift \
  ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 7: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f"
git add ScaleUp/Core/Analytics/AnalyticsEvent.swift ScaleUp/Features/Plan/Views/PlanTabView.swift ScaleUp/Features/Plan/Views/Components/ManualCompletionSheet.swift
git commit -m "feat(ios-plan): mixpanel events — task_started, task_completed, external_link_opened, recalibration_offered_from_plan"
```

---

## Task 3: Android — `JourneyTimelineStrip` + per-week sections + milestone eyebrow

**Files:**
- Create: `src/screens/plan/components/JourneyTimelineStrip.tsx`
- Modify: `src/screens/plan/PlanTabScreen.tsx` — render strip, render ALL weeks (not just current), refresh milestone section.
- Modify: `src/screens/plan/components/MilestonePreview.tsx` — small visual refresh (eyebrow + matching card style).

Same UX as iOS. RN uses `FlatList horizontal` for the strip. Scroll-to-week uses a `ScrollView` ref with `scrollTo` (compute Y offset by section position) — simpler approach: use a single `ScrollView` wrapping all sections + a layout-callback to capture each section's `pageY`, then `ref.scrollTo({y, animated:true})` on tap.

- [ ] **Step 1: Create `JourneyTimelineStrip.tsx`**

Create `src/screens/plan/components/JourneyTimelineStrip.tsx`:

```tsx
import React from 'react'
import {View, Text, StyleSheet, FlatList, TouchableOpacity} from 'react-native'
import Icon from 'react-native-vector-icons/Ionicons'
import {Colors, Spacing, CornerRadius} from '../../../theme'
import type {WeeklyEntry} from '../../../services/planService'

interface Props {
  weeks: WeeklyEntry[]
  currentWeekNumber?: number
  onWeekTap: (weekNumber: number) => void
}

export const JourneyTimelineStrip: React.FC<Props> = ({weeks, currentWeekNumber, onWeekTap}) => {
  return (
    <View style={styles.container}>
      <View style={styles.eyebrowRow}>
        <Icon name="calendar-outline" size={11} color={Colors.gold} />
        <Text style={styles.eyebrow}>YOUR JOURNEY</Text>
      </View>
      <FlatList
        data={weeks}
        keyExtractor={w => String(w.weekNumber)}
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.list}
        renderItem={({item}) => <WeekCard week={item} isCurrent={item.weekNumber === currentWeekNumber} onTap={() => onWeekTap(item.weekNumber)} />}
      />
    </View>
  )
}

const WeekCard: React.FC<{week: WeeklyEntry; isCurrent: boolean; onTap: () => void}> = ({week, isCurrent, onTap}) => {
  const tasks = (week as any).tasks ?? []
  const total = tasks.length
  const done = tasks.filter((t: any) => t.progress?.status === 'complete').length
  const progress = total > 0 ? done / total : 0
  const isComplete = total > 0 && done === total

  return (
    <TouchableOpacity
      onPress={onTap}
      activeOpacity={0.85}
      style={[styles.card, isCurrent && styles.cardCurrent, isComplete && !isCurrent && styles.cardFaded]}
    >
      <Text style={styles.weekHeader}>WEEK {week.weekNumber}</Text>
      <Text style={styles.weekLabel} numberOfLines={2}>{week.weekLabel}</Text>
      <View style={styles.footer}>
        <ProgressDot progress={progress} />
        <Text style={styles.counter}>{total > 0 ? `${done}/${total}` : '—'}</Text>
      </View>
    </TouchableOpacity>
  )
}

// Tiny "filled-arc" ring fallback — RN doesn't have SVG by default. Render a
// solid filled circle for 100%, an outline for 0-99%. (For a true ring, add
// react-native-svg later.)
const ProgressDot: React.FC<{progress: number}> = ({progress}) => {
  const isFull = progress >= 1
  return (
    <View style={[styles.ring, isFull && styles.ringFull]}>
      {!isFull && progress > 0 ? (
        <View style={[styles.ringInner, {opacity: 0.5 + progress * 0.5}]} />
      ) : null}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { marginTop: Spacing.lg },
  eyebrowRow: { flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: Spacing.sm, paddingHorizontal: Spacing.lg },
  eyebrow: { color: Colors.gold, fontSize: 11, fontWeight: '700', letterSpacing: 1.4 },
  list: { paddingHorizontal: Spacing.lg, gap: Spacing.sm },
  card: {
    width: 168, height: 120,
    padding: Spacing.md,
    borderRadius: CornerRadius.large,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: 'rgba(232,184,75,0.10)',
    justifyContent: 'space-between',
  },
  cardCurrent: { borderColor: Colors.gold, borderWidth: 1.5 },
  cardFaded: { opacity: 0.6 },
  weekHeader: { color: Colors.textSecondary, fontSize: 10, letterSpacing: 1.2, fontWeight: '700' },
  weekLabel: { color: Colors.textPrimary, fontSize: 14, fontWeight: '700' },
  footer: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  ring: {
    width: 18, height: 18, borderRadius: 9,
    borderWidth: 2.5, borderColor: 'rgba(232,184,75,0.15)',
    alignItems: 'center', justifyContent: 'center',
  },
  ringFull: { backgroundColor: Colors.gold, borderColor: Colors.gold },
  ringInner: { width: 8, height: 8, borderRadius: 4, backgroundColor: Colors.gold },
  counter: { color: Colors.textSecondary, fontSize: 12 },
})
```

If `react-native-vector-icons/Ionicons` doesn't have `'calendar-outline'`, swap for `'time-outline'` or any other existing icon. Don't add new dependencies for Phase 5.

- [ ] **Step 2: Wire into `PlanTabScreen.tsx`**

Find the ready-state JSX in `src/screens/plan/PlanTabScreen.tsx`. Today it renders `ObjectiveBriefCard`, `NextCheckInPill`, `<ThisWeekTasksList for currentWeekTasks(plan)>`, then milestones. Replace the `<ThisWeekTasksList>` block with a JourneyTimelineStrip + a per-week ForEach.

Add state for the section refs:
```typescript
const [weekYOffsets, setWeekYOffsets] = useState<Record<number, number>>({})
const scrollViewRef = useRef<ScrollView>(null)

const recordWeekY = (weekNumber: number) => (e: any) => {
  const y = e.nativeEvent?.layout?.y
  if (typeof y === 'number') {
    setWeekYOffsets(prev => prev[weekNumber] === y ? prev : {...prev, [weekNumber]: y})
  }
}

const scrollToWeek = (weekNumber: number) => {
  const y = weekYOffsets[weekNumber]
  if (typeof y === 'number') {
    scrollViewRef.current?.scrollTo({y, animated: true})
  }
}
```

Add the `ref={scrollViewRef}` to the existing `<ScrollView>`. Replace the ready-state task block with:

```tsx
{plan.weeklySchedule.length > 0 && (() => {
  const current = currentWeekTasks(plan)
  return (
    <>
      <JourneyTimelineStrip
        weeks={plan.weeklySchedule}
        currentWeekNumber={current?.weekNumber}
        onWeekTap={scrollToWeek}
      />
      {plan.weeklySchedule.map(week => (
        <View key={week.weekNumber} onLayout={recordWeekY(week.weekNumber)}>
          <ThisWeekTasksList
            weekNumber={week.weekNumber}
            weekLabel={week.weekLabel}
            tasks={(week as any).tasks ?? []}
            onTaskTap={handleTaskTap}
          />
        </View>
      ))}
    </>
  )
})()}
```

Don't forget `import {JourneyTimelineStrip} from './components/JourneyTimelineStrip'`.

- [ ] **Step 3: Refresh `MilestonePreview.tsx` visual**

Open `src/screens/plan/components/MilestonePreview.tsx`. Read it first:

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && cat src/screens/plan/components/MilestonePreview.tsx
```

Wrap the existing render with the same eyebrow used by JourneyTimelineStrip + apply the matching card border style (`'rgba(232,184,75,0.10)'` border). Keep the existing milestone row rendering unchanged.

If the change is just adding a wrapper, the diff stays small. Don't redesign internal milestone rows.

- [ ] **Step 4: TypeScript check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/screens/plan" | head -10
```

Expected: 0 errors. Common issue: `(week as any).tasks` cast — that's intentional because openapi-generated `WeeklyEntry` may type `tasks` loosely.

- [ ] **Step 5: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git add src/screens/plan/
git commit -m "feat(android-plan): JourneyTimelineStrip + per-week sections + milestone eyebrow"
```

---

## Task 4: Android — Mixpanel events

**Files:**
- Modify: `src/services/analytics/AnalyticsEvent.ts`
- Modify: `src/screens/plan/PlanTabScreen.tsx`
- Modify: `src/screens/plan/components/ManualCompletionSheet.tsx`

Mirror Task 2's iOS analytics work.

- [ ] **Step 1: Add events to AnalyticsEvent union**

Open `src/services/analytics/AnalyticsEvent.ts`. Find `plan_task_tapped` (added in Phase 2.5 follow-up). Add four new entries:

```typescript
| {type: 'plan_task_started'; task_type: string; task_id: string; topic_canonical: string}
| {type: 'plan_task_completed'; task_type: string; task_id: string; topic_canonical: string; self_rating?: number}
| {type: 'external_link_opened'; task_id: string; url: string; topic_canonical: string}
| {type: 'recalibration_offered_from_plan'; source: string}
```

- [ ] **Step 2: Fire `plan_task_started` from handleTaskTap**

In `PlanTabScreen.tsx`, find `handleTaskTap`. After the existing `plan_task_tapped` fire, add:

```typescript
AnalyticsService.track({
  type: 'plan_task_started',
  task_type: task.type,
  task_id: task.taskId,
  topic_canonical: task.topic.canonicalName,
})
```

In the `'external_link'` case, after the `Linking.openURL(url)` (in the `then` or right after the call), add:

```typescript
AnalyticsService.track({
  type: 'external_link_opened',
  task_id: task.taskId,
  url,
  topic_canonical: task.topic.canonicalName,
})
```

- [ ] **Step 3: Fire `plan_task_completed` from `ManualCompletionSheet.tsx`**

In `submit()`, right after the successful `await PlanService.markTaskComplete(...)`, before `onComplete()` and `onClose()`, add:

```typescript
const {AnalyticsService} = await import('../../../services/analytics')
AnalyticsService.track({
  type: 'plan_task_completed',
  task_type: task.type,
  task_id: task.taskId,
  topic_canonical: task.topic.canonicalName,
  self_rating: selectedRating,
})
```

(Or import normally at the top of the file — check whether `AnalyticsService` is already imported; if not, add the regular import.)

- [ ] **Step 4: Fire `recalibration_offered_from_plan` from PlanTabScreen**

In the rendered `<NextCheckInPill ... />`, the existing `onRecalibrateTap` callback navigates to RecalibrationFlow. Wrap the navigation:

```typescript
onRecalibrateTap={() => {
  AnalyticsService.track({type: 'recalibration_offered_from_plan', source: 'pill'})
  navigation.navigate('RecalibrationFlow' as never)
}}
```

For impressions, add a `useEffect` that fires when eligibility flips to true. Add a state ref to avoid double-firing:

```typescript
const eligibilitySeenRef = useRef(false)
useEffect(() => {
  if (plan && isCheckInDue(plan.nextCheckInAt) && !eligibilitySeenRef.current) {
    eligibilitySeenRef.current = true
    AnalyticsService.track({type: 'recalibration_offered_from_plan', source: 'pill_seen'})
  }
}, [plan])
```

Add the `useRef` import (`import {..., useRef} from 'react'`).

- [ ] **Step 5: TypeScript check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/(screens/plan|services/analytics)" | head -10
```

Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid"
git add src/services/analytics/AnalyticsEvent.ts src/screens/plan/
git commit -m "feat(android-plan): mixpanel events — task_started, task_completed, external_link_opened, recalibration_offered_from_plan"
```

---

## Task 5: Phase 5 acceptance — full sweep

- [ ] **Step 1: Backend tests** (no changes — sanity check)

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo/scaleup-backend" && node --test src/services/plan/ src/services/diagnostic/planGenerationService.test.js src/models/ExternalContentTouch.test.js src/controllers/planController.test.js 2>&1 | tail -10
```

Expected: every test passes. (No backend changes in Phase 5; this is a sanity check.)

- [ ] **Step 2: iOS parse-check**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpDemo-f" && find ScaleUp/Features/Plan ScaleUp/Core/Analytics -name "*.swift" -print0 | xargs -0 xcrun swiftc -parse 2>&1 | tail -10
```

Expected: silent.

- [ ] **Step 3: Android typecheck**

```bash
cd "/Users/nirpekshnandan/My Products/ScaleUpAndroid" && npx tsc --noEmit 2>&1 | grep -E "src/(screens/plan|services/analytics|services/plan)" | head -10
```

Expected: 0 errors in those paths.

- [ ] **Step 4: No commit needed.** Acceptance only.

---

## What Phase 5 ships

After this plan executes:
- iOS + Android Plan tab shows a horizontally-scrollable week strip with progress rings; tapping a week scrolls to that week's tasks below.
- All weeks are visible (not just current) — users can plan ahead and look back.
- Milestone footer has consistent visual treatment with the rest of the new card style.
- Mixpanel collects 4 new events feeding the spec §10 success-criteria measurement: task starts, task completions (with self-rating where applicable), external-link opens, recalibration-offer impressions and clicks.

**What Phase 5 does NOT ship:**
- `task_completed` events for auto-completing types (quiz/content/interview/competition) — those finalize server-side. Future work: have the API return the new task status in completion responses so the client can fire the event when it observes a transition. Server logs cover this gap for now.
- True circular progress ring on Android (uses a simpler dot indicator since RN has no built-in arc primitive). Adding `react-native-svg` would enable a real ring; deferred to avoid the dependency.
- Per-week empty state ("No tasks this week") within the JourneyTimelineStrip — handled by ThisWeekTasksList's existing empty-state copy.
- A11y labels on the week-strip cards. Add in a follow-up if accessibility audit flags them.

This is the final phase of the Plan-tab redesign per the spec. After this, the spec is fully executed.

---

## Self-review checklist

- ✅ Spec coverage: §6.4 journey timeline, §6.5 milestone footer, §7 phase 5 deliverables, §10 success-criteria measurement events all map to tasks.
- ✅ Placeholder scan: clean.
- ✅ Type consistency: analytics event keys are snake_case across iOS+Android (`task_type`, `task_id`, `topic_canonical`, `self_rating`, `source`). `weekNumber` used as ScrollViewReader/scroll-to anchor consistently.
- ✅ No new dependencies: SwiftUI's built-in `ScrollViewReader` + Circle for the ring; RN's built-in `FlatList` + `View` for the strip.
- ✅ Phase 1-4 dependencies: `currentWeekTasks(in:)`, `ManualCompletionSheet`, `NextCheckInPill`, `MilestonePreview`, `ThisWeekTasksList`, `recalVM.eligibility` — all in place.
