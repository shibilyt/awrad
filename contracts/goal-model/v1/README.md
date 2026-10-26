# Goal model v1

The goal rules as executable cases, shared by Android, iOS and the server (slice 1, [`docs/slices/01-domain-foundation.md`](../../../docs/slices/01-domain-foundation.md)). Language for the rules is in [`CONTEXT.md`](../../../CONTEXT.md); when the two disagree, these fixtures are the spec.

| File | Rule | Cases |
|---|---|---|
| `goal-model.schema.json` | The goal model (`urn:awrad:goal-model:1`). `goal_shape` is the structure; `goal` adds the validity rules (a target unless tracker, a target on every session, the streak threshold's value set). Rule fixtures use `goal`, so they can't contain invalid goals | – |
| `fixtures/effective_practice_day.json` | Instant + timezone + day reset → the effective practice day | 10 |
| `fixtures/goal_is_due.json` | Whether a goal is due on a day (Gregorian schedules, active period, pauses) | 29 |
| `fixtures/requirement_standing.json` | Window, progress, target and status, per requirement type (for days per period: that day against the daily target) | 25 |
| `fixtures/days_per_period.json` | Qualifying days against required days per week or month | 12 |
| `fixtures/goal_completion.json` | Derived completion per completion policy | 11 |
| `fixtures/goal_streak.json` | The current streak, per day or per period | 24 |
| `fixtures/goal_validity.json` | Which goals are invalid, with error codes; platforms reject them at construction, sync and import | 13 |

## Conventions

- **Dates** are effective practice days (`YYYY-MM-DD`); count entries are already bucketed by day. Instants are UTC (`…Z`).
- **Weekdays and week starts** are names (`monday`), never numbers. The frozen apps disagreed on whether weekday 1 is Sunday or Monday.
- **Counts** are whole numbers. Progress counts entries in the window **up to and including** the evaluated date.
- **`not_due`:** outside the active period; on a day off the schedule (per due date, tracker, days per period); or for a week or month with no due days (period total, days per period). A `not_due` answer's window is the evaluated day, and its progress is that day's count inside the active period (0 outside it).
- **Sessions:** the top-level `target` is `null`, and each session reports its own progress, target and status. The day is met only when every session is. Counts without a session are ignored, including in the total.
- **In progress:** today, or the current week or month, never breaks a streak, but only while the goal is still running. After the goal has ended, its last day or period is final.
- **Days per period:** the required days are capped by the due days the window actually has (a partial first or last week, pauses, a weekday schedule).

## Running

`npm test` in `contracts/` checks every file and every case against these schemas. Each platform runs the cases through its own implementation:

| Platform | Runner | Implementation |
|---|---|---|
| Android | `:core:testing` fixture runner, run by `:core:domain:test` | `:core:domain` |
| iOS | `AwradTesting` fixture runner, run by `swift test` | `AwradDomain` |
| Server | ExUnit fixture runner | `Awrad.Goals.Rules` |

Hijri, yearly and seasonal schedules are added in slice 1b as new cases (and schedule kinds) in this version.
