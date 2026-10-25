# Slice 01: Domain foundation (goal rules)

Status: Agreed (scope). Step 2 study done and decided 2026-10-21. Next: step 3, domain and fixtures
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 1
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

Every platform answers "where does this goal stand on this effective practice day?" the same way, from one specification. The goal rules (Schedule, Active period, Requirement, Completion, Streak and the effective practice day) exist once as shared fixtures and pass on every platform that implements them.

This is the architecture review's top recommendation: one home for goal evaluation instead of the 4–5 copies in the frozen apps.

## Scope

| In scope | Out of scope (and where it goes) |
|---|---|
| Domain types for Goal, Schedule, Active period, Requirement, Completion, Streak, in each implementing platform's domain module | Persistence (Room, SwiftData, Ecto): slice 3, goals |
| Pure rule functions: effective practice day, "is due on day", requirement standing for a day or period, completion, streak | API operations and schemas: slice 3 |
| `awrad-fixture/1` files for each rule, with boundary cases | Screens: slice 3 and later |
| A fixture runner on each implementing platform, wired into its validation and CI | Counting, count caps, slot (Session) availability, audio: slice 4 |
| A `CONTEXT.md` update for any term that changes | Reminders and notification obligations: later slice |
| | Prayer-time calculation: the rules take prayer times as **inputs**; computing them is a later adapter |
| | Wird cadence, tags, collective counters: later slices |

Platforms: Android ☑ · iOS ☑ · server ☑ (evaluates for the web) · web ☐ (displays the server's standing; no rules)

## Decisions (answered 2026-10-21)

1. **The server evaluates goals for the web.** Its read views include each goal's standing; the web only displays it. Rules are implemented in Kotlin, Swift and Elixir; no TypeScript implementation.
2. **Gregorian first.** This slice is **01a**: daily, weekly (selected weekdays), interval (every N days), specific dates, Gregorian monthly. **01b** adds the Hijri calendar, yearly and seasons (Ramadan, Ashura, …). Nothing is dropped.
3. **All four existing Requirement types stay** (per due date, cumulative total, period total, none). Of the candidate new types:
   - **A. Days per period** ("dhikr on 5 of 7 days a week") is **added in this slice**.
   - **B. Sequence within a session** (e.g. Tasbih Fatimah 33/33/34 as one goal) gets **its own later slice and brief**. It changes what a goal is, and relates to "Practice plan" in `CONTEXT.md`.
   - **C. Carry-over / make-up** (a missed amount moves to the next due day) is a **later rule**, added to the plan.
   - **D. Progressive target** isn't added.
   - Already covered without new types: per-session targets (each slot's count policy), deadline totals (cumulative plus an end date), ranges (minimum, target, maximum), habits (target 1 or the "any positive" threshold).
   - Belong to other features: shared group targets (collective counters, counting slice); time- or content-based goals (wird).
4. **One streak rule everywhere:** a day counts toward the streak when it meets the goal's stored streak threshold. Defined once in fixtures.

## Behaviour inventory (step 2)

Studied 2026-10-21 from the frozen Android (`awrad-android/`) and iOS (`awrad-ios/awrad/`) code and tests.

Abbreviations:
- `A:` = `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/`
- `I:` = `awrad-ios/awrad/awrad/Core/`

**Headline:** each rule exists 3–5 times per platform, in UI calculators, history stats, notification semantics, counting availability and, on iOS, the widget. The copies disagree with each other.

### Current behaviour and decisions

| # | Rule | Android today | iOS today | Decision |
|---|---|---|---|---|
| 1 | Effective day at exactly Maghrib | UI: still the old day (`Date().after`, strict; `A:util/DateProvider.kt:70`). Notifications: new day (`>=`; `A:util/EffectiveDayWindowResolver.kt:26`) | New day (`>=`; `I:AwradCalculators.swift:3-13`) | **Fix:** the Maghrib instant belongs to the new day (`>=`), everywhere |
| 2 | Effective day without a location under Maghrib reset | Falls back to midnight | Falls back to midnight | **Keep**, and surface it in the UI (later slice) |
| 3 | Calendar used for Gregorian rules | Explicit Gregorian | `Calendar.current` in monthly windows and the widget, so a device set to the Islamic or Persian calendar breaks (`I:AwradCalculators.swift:206`) | **Fix:** rules always use an explicit Gregorian calendar (Hijri only where a schedule asks, in 1b) |
| 4 | Weekly/monthly with an empty set | "Every day" (reachable only through sync or legacy data) | Same | **Fix:** invalid; rejected at the boundary |
| 5 | Monthly on day 29–31 in shorter months | Never due that month | Same | **Decided:** dates past the month's end fall on its **last day** (31 → 30 April, 28/29 February) |
| 6 | Interval anchor | `anchor ?: start`; due when `days(anchor, D) >= 0 && % N == 0` | Same | **Keep** |
| 7 | Active period | Start and end inclusive; duration N → last day start+N−1; earlier bound wins; `duration <= 0` handled three ways | Same, `duration == 0` handled two ways | **Keep** the bounds; **fix:** `duration <= 0` is invalid |
| 8 | History range | Ignores the duration (`A:util/GoalHistoryStatsCalculator.kt:65`) | n/a | **Fix:** the active period bounds every rule |
| 9 | Week start for period totals | Monday, hard-coded (`A:util/GoalProgressCalculator.kt:132`) | Monday, hard-coded | **Decided:** a **week start** setting in the account practice policy (Saturday, Sunday or Monday; default Monday). It's an input to every week-based rule |
| 10 | Period windows vs active period | Not clipped to start/end | Not clipped | **Fix:** windows are clipped to the active period |
| 11 | Target basis with sessions | UI: total across sessions vs the **sum of session targets**. Notifications: **each session** must meet its own threshold | Same split | **Decided:** with sessions, the day is met when **each active session meets its own target** |
| 12 | Goal-level target, minimum, maximum | Ignored by progress (sum of session targets used); used by notifications | Same | **Decided:** without sessions, the goal-level count policy applies; with sessions, each session's own count policy |
| 13 | Tracker (no target) | Met when count > 0 | Same | **Keep** |
| 14 | Streak threshold | UI and history: `minimum ?: daily target`. Notifications: the stored threshold (`A:notification/ObligationSemantics.kt:88-91`) | UI: `minimum` → `minimumStreakCount` → target. Notifications: the stored threshold (`I:NotificationObligationSemantics.swift:157-166`) | **Decided:** the stored threshold, everywhere |
| 15 | Streak with a partial today | **Bug:** shows 0 until today meets the threshold (`A:util/GoalProgressCalculator.kt:258,265`). Notifications preserve it | **Same bug** (`I:AwradCalculators.swift:127-136`) | **Fix:** today in progress never breaks the streak. It only adds 1 once met |
| 16 | Streak over non-due days | Skipped | Skipped | **Keep** |
| 17 | Streak over paused days, before start, after end | UI ignores them; notifications only walk due days | Same | **Fix:** only days the goal is due count; paused days neither count nor break |
| 18 | Streak for period-total and cumulative goals | Single days compared with the whole period/lifetime target (meaningless); notifications force 0 | Same | **Decided:** period-total goals' streak = **consecutive periods** meeting their target. Cumulative and tracker goals = consecutive due days meeting the streak threshold |
| 19 | Completion: what triggers it | `autoCompleteOnTarget` flag, cumulative only; `completionPolicy` and `duration_ended` never acted on | `whenTargetReached` for any policy; `duration_ended` never acted on | **Fix:** completion is **derived** from the rules (target reached, or the duration has ended, per `completion_policy`), not a flag set by counting code |
| 20 | Completion when counts drop | Reopens | **Never reopens** | Follows 19: derived, so a goal below target isn't completed |
| 21 | "One-time" goals | Not a schedule kind | Stored as `specific_dates [creation day]`, so it **disappears the next day** (`awrad-ios/awrad/awrad/Features/Goals/GoalDraft.swift:117-126`) | **Decided:** a one-time goal has **no repeating schedule**. It's due every day of its active period until completed (a cumulative goal with an optional deadline) |
| 22 | "Today" rolling over while a screen is open | Never re-emits at midnight or Maghrib (`A:util/DateProvider.kt:27-35`) | Not recomputed at Maghrib in the foreground | **Not a rule.** The platforms' clock adapters must re-evaluate at the boundary (slices 3–4) |
| 23 | Days per period | Doesn't exist | Doesn't exist | **New** (decision 3A) |

### Test evidence

- **Android:** `GoalProgressCalculatorTest`, `GoalProgressUseCaseTest`, `GoalHistoryStatsCalculatorTest`, `ObligationSemanticsTest`, `NotificationObligationPlanServiceTest`, `BehaviorFixtureParityTest`. No test covers the partial-today streak, duration gating, or the Maghrib boundary in `DateProvider`.
- **iOS:** `awradTests.swift`, `NotificationObligationPlannerTests`, `CountingSlotTimingParityTests`, `WidgetRelationalMutationTests`. `BehaviorParityTests` reads the shared fixtures but only *executes* the slot-selection and notification families; the effective-day, recurrence and streak cases are copied into tests by hand.

### Consequences for later slices

- **Week start** becomes a field of the account practice policy (`day_reset`, `calculation_method`, `madhab`, `week_start`). It's added to the practice-settings API in the slice that builds settings. Until then, the rules take it as an input and the fixtures cover every value.
- **The clock adapters** (Android, iOS) must re-evaluate "today" at midnight or Maghrib while the app is open (row 22). That's tracked for slices 3–4.

## Domain and fixtures (step 3)

Planned fixture files, in a new `contracts/goal-model/v1/fixtures/` (final list once the Requirement types are settled):

| Rule | File | Covers |
|---|---|---|
| Effective practice day | `effective_practice_day.json` | Midnight and Maghrib day reset, timezone, the moment of change |
| Schedule | `goal_is_due.json` | Each kept frequency, start and end of the active period |
| Requirement standing | `requirement_standing.json` | Per due date, cumulative total, period total, none: met, not met, which period window |
| Days per period | `days_per_period.json` | Qualifying days counted in a week or month window; partial windows at the start and end of the active period |
| Completion | `goal_completion.json` | Each completion policy |
| Streak | `goal_streak.json` | Thresholds, gaps, non-due days, today in progress |

## Contract (step 4)

No API operations in this slice. Slice 3 adds a goal-standing field to the goal read views, computed by the server's rules from this slice.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-android-next | Goal model and rules in `:core:domain`; fixture runner in `:core:testing`, run by `:core:domain:test` | Gradle validation | ☐ |
| awrad-ios-next | The same in `AwradDomain`; fixture runner in `AwradTesting`, run by `swift test` | `scripts/validate` | ☐ |
| awrad-server-next | An `Awrad.Goals.Rules` module (pure functions); fixture runner in ExUnit | `mix validate` | ☐ |
| awrad-web-next | Nothing in this slice: it displays the server's goal standing from slice 3 | – | n/a |

## Integration evidence (step 6)

No UI in this slice. The evidence is every implementing platform passing the same fixture files in CI, with the run linked here.

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
