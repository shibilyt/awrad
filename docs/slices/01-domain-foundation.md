# Slice 01: Domain foundation (goal rules)

Status: Agreed (scope, 2026-10-21). Next: step 2, study
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

Filled in once the questions are answered: each rule's current behaviour in Android and iOS, the decision, and the evidence. Starting points:

- **Android:**
  - `util/GoalProgressCalculator.kt` (`isDueToday`, `currentProgressWindow`, `calculateStreakWithCounts`);
  - `GoalProgressUseCase`;
  - `util/GoalHistoryStatsCalculator.kt`;
  - `notification/ObligationSemantics.kt`;
  - `GoalRepositoryImpl` completion and cap logic.
- **iOS:** `Core/AwradCalculators.swift`, `Core/AwradDomain.swift`.
- **Shared:**
  - `contracts/behavior-model/v1/fixtures/behavior-cases.json` (families `effective_day`, `recurrence`, `streaks`);
  - `contracts/progress-model/v1/progress-model.schema.json`.
- **Spec:** `docs/reference/android-spec/prd/features/FEAT-GOAL-001.md`, `FEAT-PROGRESS-001.md`.
- **Known drift to settle:** streak threshold (decision 4); the target-policy switch copied 4–5 times; "all slots complete" computed in three places (slot part deferred to slice 4).

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
