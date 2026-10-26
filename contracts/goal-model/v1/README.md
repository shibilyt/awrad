# Goal model v1

The goal rules as executable cases, shared by Android, iOS and the server (slice 1, [`docs/slices/01-domain-foundation.md`](../../../docs/slices/01-domain-foundation.md)). Language for the rules is in [`CONTEXT.md`](../../../CONTEXT.md); when the two disagree, these fixtures are the spec.

| File | Rule | Cases |
|---|---|---|
| `goal-model.schema.json` | The goal model (`urn:awrad:goal-model:1`). `goal_shape` is the structure; `goal` adds the validity rules (a target unless tracker, a target on every session, the streak threshold's value set). Rule fixtures use `goal`, so they can't contain invalid goals | – |
| `fixtures/effective_practice_day.json` | Instant + timezone + day reset → the effective practice day | 10 |
| `fixtures/goal_is_due.json` | Whether a goal is due on a day (every schedule kind, active period, pauses) | 63 |
| `fixtures/requirement_standing.json` | Window, progress, target and status, per requirement type (for days per period: that day against the daily target) | 30 |
| `fixtures/days_per_period.json` | Qualifying days against required days per week, month or Hijri month | 16 |
| `fixtures/goal_completion.json` | Derived completion per completion policy | 11 |
| `fixtures/goal_streak.json` | The current streak, per day or per period | 30 |
| `fixtures/goal_validity.json` | Which goals are invalid, with error codes; platforms reject them at construction, sync and import | 13 |

## Conventions

- **Dates** are effective practice days (`YYYY-MM-DD`); count entries are already bucketed by day. Instants are UTC (`…Z`).
- **Weekdays and week starts** are names (`monday`), never numbers. The frozen apps disagreed on whether weekday 1 is Sunday or Monday.
- **Counts** are whole numbers. Progress counts entries in the window **up to and including** the evaluated date.
- **`not_due`:** outside the active period; on a day off the schedule (per due date, tracker, days per period); or for a week or month with no due days (period total, days per period). A `not_due` answer's window is the evaluated day, and its progress is that day's count inside the active period (0 outside it).
- **Sessions:** the top-level `target` is `null`, and each session reports its own progress, target and status. The day is met only when every session is. Counts without a session, or with a session the goal doesn't have, are ignored, including in the total.
- **In progress:** today, or the current week or month, never breaks a streak, but only while the goal is still running. After the goal has ended, its last day or period is final.
- **Hijri dates** come from [`hijri-calendar/v1`](../../hijri-calendar/v1/) with the account's month-start corrections (`hijri_corrections` in a case's `given`; absent means none). Outside the table, Hijri schedules and Hijri-month periods are never due.
- **Month days past the month's end** fall on its last day: Gregorian day 31 in April, Hijri day 30 in a 29-day month, 29 February in a common year.
- **Yearly ranges** are inclusive. A range whose end comes before its start runs over the year end. A single day is a range with start = end. Impossible days (30 February, Hijri day 31) are rejected by the schema.
- **Days per period:** the required days are capped by the due days the window actually has (a partial first or last week, pauses, a weekday schedule).

## Running

`npm test` in `contracts/` checks every file and every case against these schemas. Each platform runs the cases through its own implementation:

| Platform | Runner | Implementation |
|---|---|---|
| Android | `:core:testing` fixture runner, run by `:core:domain:test` | `:core:domain` |
| iOS | `AwradTesting` fixture runner, run by `swift test` | `AwradDomain` |
| Server | ExUnit fixture runner | `Awrad.Goals.Rules` |

Slice 1b added the Hijri and yearly schedule kinds and the `hijri_month` period to this version. Seasons are presets over them ([`goal-presets/v1`](../../goal-presets/v1/)), not a schedule kind.
