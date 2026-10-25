# Goal model v1

The goal rules as executable cases, shared by Android, iOS and the server (slice 1, [`docs/slices/01-domain-foundation.md`](../../../docs/slices/01-domain-foundation.md)). Language for the rules is in [`CONTEXT.md`](../../../CONTEXT.md); when the two disagree, these fixtures are the spec.

| File | Rule | Cases |
|---|---|---|
| `goal-model.schema.json` | The goal shape every fixture uses (`urn:awrad:goal-model:1`): schedule, active period, pauses, count policy, sessions, requirement, completion, count entries | – |
| `fixtures/effective_practice_day.json` | Instant + timezone + day reset → the effective practice day | 10 |
| `fixtures/goal_is_due.json` | Whether a goal is due on a day (Gregorian schedules, active period, pauses) | 29 |
| `fixtures/requirement_standing.json` | Window, progress, target and status for per due date, cumulative, period total and tracker goals | 20 |
| `fixtures/days_per_period.json` | Qualifying days against required days per week or month | 11 |
| `fixtures/goal_completion.json` | Derived completion per completion policy | 9 |
| `fixtures/goal_streak.json` | The current streak, per day or per period | 21 |

## Conventions

- **Dates** are effective practice days (`YYYY-MM-DD`); count entries are already bucketed by day. Instants are UTC (`…Z`).
- **Weekdays and week starts** are names (`monday`), never numbers. The frozen apps disagreed on whether weekday 1 is Sunday or Monday.
- **Counts** are whole numbers. Progress counts entries in the window **up to and including** the evaluated date.
- **Outside the active period** a goal is `not_due`. On a day off its schedule, a per-due-date or tracker goal is `not_due`.
- **Sessions:** the top-level `target` is `null`, and each session reports its own progress, target and status. The day is met only when every session is.
- **Days per period:** the required days are capped by the due days the window actually has (a partial first or last week, pauses, a weekday schedule).

## Running

`npm test` in `contracts/` checks every file and every case against these schemas. Each platform runs the cases through its own implementation:

| Platform | Runner | Implementation |
|---|---|---|
| Android | `:core:testing` fixture runner, run by `:core:domain:test` | `:core:domain` |
| iOS | `AwradTesting` fixture runner, run by `swift test` | `AwradDomain` |
| Server | ExUnit fixture runner | `Awrad.Goals.Rules` |

Hijri, yearly and seasonal schedules are added in slice 1b as new cases (and schedule kinds) in this version.
