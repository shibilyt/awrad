# Goal model v1

The goal rules as executable cases, shared by Android, iOS, the server and the web: slice 1 ([`docs/slices/01-domain-foundation.md`](../../../docs/slices/01-domain-foundation.md)), slice 1b (Hijri), and slice 4a ([`docs/slices/04-goals.md`](../../../docs/slices/04-goals.md), decisions in [`04-goals-decisions.md`](../../../docs/slices/04-goals-decisions.md)). Language for the rules is in [`CONTEXT.md`](../../../CONTEXT.md); when the two disagree, these fixtures are the spec. Slice 4a edited this version in place (nothing is released).

| File | Rule | Cases |
|---|---|---|
| `goal-model.schema.json` | The goal model (`urn:awrad:goal-model:1`): `goal` (what a rule evaluates on one day), `goal_timeline` and `goal_document` (every dated version), `goal_order_document`, `count_log_entry`. `goal_rules` holds the validity rules a schema can express; rule fixtures use `goal`, `version` and `goal_timeline`, so they can't contain goals that break them | – |
| `fixtures/effective_practice_day.json` | Instant + timezone + day reset → the effective practice day | 10 |
| `fixtures/goal_is_due.json` | Whether a goal is due on a day (every schedule kind, active period, pauses, excused days) | 63 |
| `fixtures/requirement_standing.json` | Window, progress, target and status, per requirement type (for days per period: that day against the daily target) | 30 |
| `fixtures/days_per_period.json` | Qualifying days against required days per week, month or Hijri month; excused days lower the number | 18 |
| `fixtures/goal_completion.json` | Derived completion per completion policy | 11 |
| `fixtures/goal_streak.json` | The current streak and its unit: days, one weekday, weeks, months or occasions; make-up and days pending it, excused days, amount and pace thresholds, versions, ended goals | 64 |
| `fixtures/goal_validity.json` | Which goals and goal documents are invalid, with error codes; platforms reject them at construction, sync and import | 43 |
| `fixtures/goal_version_on_day.json` | Which dated version a document is judged by on a day, and the `goal` it resolves into | 12 |
| `fixtures/goal_version_add.json` | Saving a detail edit as a version from today; same-day edits; day sets compare regardless of order; the 100-version cap | 10 |
| `fixtures/count_attribution.json` | Count-log entries + goals (shared or dedicated, sessions) → each goal's counts per day and session | 9 |
| `fixtures/make_up.json` | Each due day's status (met, minimum only, made up, pending, missed, in progress) with make-up | 26 |
| `fixtures/excused_days.json` | Whether a day can be excused or un-excused | 30 |
| `fixtures/consistency.json` | The consistency tag, and whether a row shows the streak, the tag or nothing | 19 |
| `fixtures/daily_pace.json` | Today's share of a total goal with an end | 17 |
| `fixtures/today_ring.json` | What a list ring fills toward today | 20 |
| `fixtures/goal_list_placement.json` | Today, Upcoming (with when), Tracking, Paused or History, and the order in each | 21 |
| `fixtures/goal_order_merge.json` | Merging a conflicting `goal_order` without asking | 8 |

## Conventions

- **Dates** are effective practice days (`YYYY-MM-DD`), from the account's day reset (midnight or Maghrib, slice 3d): "today", "yesterday" and "the end of today" all mean practice days. Count entries are already bucketed by practice day. Instants are UTC (`…Z`).
- **Weekdays and week starts** are names (`monday`), never numbers. The frozen apps disagreed on whether weekday 1 is Sunday or Monday.
- **Counts** are whole numbers. Progress counts entries in the window **up to and including** the evaluated date.
- **`not_due`:** outside the active period; on a day off the schedule, paused or excused (per due date, tracker, days per period); or for a week or month with no due days (period total, days per period). A `not_due` answer's window is the evaluated day, and its progress is that day's count inside the active period (0 outside it).
- **Sessions:** the top-level `target` is `null`, and each session reports its own progress, target and status. The day is met only when every session is. Counts without a session, or with a session the goal doesn't have, are ignored, including in the total.
- **In progress:** today, the current week or month, or the current occasion, never breaks a streak, but only while the goal is still running (up to and including its last day). After that its last day, period or occasion is final.
- **Hijri dates** come from [`hijri-calendar/v1`](../../hijri-calendar/v1/) with the account's month-start corrections (`hijri_corrections` in a case's `given`; absent means none). Outside the table, Hijri schedules and Hijri-month periods are never due.
- **Month days past the month's end** fall on its last day: Gregorian day 31 in April, Hijri day 30 in a 29-day month, 29 February in a common year.
- **Yearly ranges** are inclusive. A range whose end comes before its start runs over the year end. A single day is a range with start = end. Impossible days (30 February, Hijri day 31) are rejected by the schema.
- **Days per period:** the required days are the period's number less its excused days, capped by the due days the window actually has (a partial first or last week, pauses, a weekday schedule). A period that needs 0 days isn't due.
- **A total goal with no rhythm** ("70,000 in total") uses the `every_day` schedule, so it's due every day of its active period (brief, question 8). `one_time` is evaluated the same way; the sentence never writes it.

## The goal document

A goal syncs as one `goal` entity ([`../../sync/v1/`](../../sync/v1/)) whose document is `$defs/goal_document`:

| Member | What it is |
|---|---|
| `dhikr_id` | The built-in dhikr's catalog ID, or the custom dhikr's entity ID. Never changes: another dhikr is another goal |
| `dhikr_snapshot` | `{title: {en, ar, ml}, arabic, kind}`: the dhikr's label when the goal was last saved, so History reads correctly after a custom dhikr is gone (decision 37). Apps show the live dhikr while it exists, and the snapshot only when it's gone |
| `name` | The user's own name, or `null` to show the dhikr's title |
| `counts` | `shared` or `dedicated` (below). Set at creation, never changed |
| `created_on` | The practice day it was created |
| `versions` | 1 to 100 dated versions, oldest first: `{from, schedule, active_period, count_policy, sessions, requirement, completion, make_up}` |
| `paused` | Pause ranges `{from, to}`, inclusive, `to` null while paused. Not versioned |
| `excused` | Excused days. Not versioned |
| `ended` | `null`, or `{on, reason}`: `user` (End goal), `completed` (a total reached), `date` (its active period ran out, or no scheduled day is left), `structural_edit`, `dhikr_deleted` |

`goal_timeline` is the same without `dhikr_id`, `dhikr_snapshot`, `name` and `counts`: the part rules need. Rules that look across days accept a `goal_timeline` or a single `goal` (`$defs/goal_input`); a `goal` stands for a timeline with one version from its start date that has never ended.

**Ending.** `ended.on` is the goal's last day, inclusive. "End goal", a structural edit and the custom dhikr cascade write the practice day they happen on; `completed` writes the day the total was reached, and `date` the last day. Clients write `completed` and `date` themselves when they first see them (`goal_list_placement` finds them), so a completed goal never comes back if an adjustment later lowers its total (decision 26). A finished goal is never reactivated; Start again creates a new goal.

## Dated versions

**Editing never rewrites the past** (decision 23).

- **A detail edit** (the numbers, sessions, the streak rule, make-up, the end; the name isn't versioned) applies from today as a new version (`goal_version_add.json`):
  - a second edit on the same day replaces today's version;
  - an edit back to the previous settings removes it;
  - unchanged settings add nothing. Weekdays, month days and dates are sets, compared regardless of order; phones write weekdays Monday first and the rest ascending;
  - a 101st version folds the oldest into the next (the first goes, and the second takes its `from`).
- **Structural fields** are equal in every version: the schedule kind (and a yearly schedule's calendar), the requirement type (and its period), and the start date. Changing one ends the goal (`structural_edit`) and starts a new one today. A different dhikr is always a new goal.
- **The version in force on a day** is the one with the latest `from` on or before it; days before the first version use the first (`goal_version_on_day.json`).
- **Resolving a document into a `goal` for a day:** that version's settings, plus the document's `paused` and `excused`. If the goal has ended, and the version's own last day is later than `ended.on` (or it has none), the active period ends on `ended.on` instead (`end_date: ended.on`, `duration_days: null`).
- **A rule evaluates each day with the version in force that day:** whether it's due, its target, minimum and streak amount, its sessions, its make-up window. A week or month is judged by the version in force on its last day so far (the period's last day, or today). Two things read the version in force today: the streak unit, and the last day (whether the goal has ended).
- **Daily pace** judges each day against the end its version had then, even after the goal is ended early (`daily_pace.json`, `ending_doesnt_rewrite_past_pace`).

## Sessions

A session is `{id, kind, …, target}` with one of five kinds (decision 10): `anytime`, `before_prayer {prayer}`, `after_prayer {prayer}`, `at_time {time}` and `between {from, to}`. Prayers are `fajr`, `dhuhr`, `asr`, `maghrib` and `isha`; times are local `HH:MM`. A `between` window may run past midnight, but can't be empty. Kinds only guide: any session can be counted at any time of its day, and windows never block (decision 11).

**The ID is derived from the kind**, so a shared count made in one goal's "after Fajr" fills the same session of another goal on that dhikr:

| Kind | ID |
|---|---|
| `anytime` | `anytime` |
| `before_prayer`, `after_prayer` | `before_<prayer>`, `after_<prayer>` |
| `at_time` | `at_HHMM` (`at_0630`) |
| `between` | `between_HHMM_HHMM` (`between_2100_2330`) |

**A session carries a target only** (decision 47): no minimum, cap or streak threshold of its own, and its streak amount is its target. A tracker's session may have no target (`null`, any count). Two sessions of one goal can't share an ID, and a goal with sessions has no minimum or cap (decision 9).

## Counts: shared and dedicated

Counts belong to the dhikr (root `DECISIONS.md` ADR-2026-10-31). Each profile keeps an append-only **count log** of `$defs/count_log_entry`: `{id, dhikr_id, practice_day, session_id, goal_id, amount, counted_at}`. `id` is a UUIDv7, `amount` is never 0 and is negative for an adjustment or undo, and `goal_id` is set only for a count made in a dedicated goal. The log syncs from slice 5; its shape is fixed here.

`count_attribution.json` turns the log into the `count_entry` lists every other rule reads:
- a **shared** goal takes every entry of its dhikr without a `goal_id`, wherever it was made;
- a **dedicated** goal takes only entries with its own `goal_id`, and they fill no other goal;
- with sessions in that day's version, an entry goes to the session with its `session_id`, and entries without one, or with a session the goal doesn't have, are dropped; without sessions it goes to the day;
- entries sum per day and session, and a sum of 0 or less is no count. Attribution doesn't filter by date: the rules ignore counts outside the active period.

## Streaks

**The streak amount** is what a day needs to keep the streak (a session's is its target): `any_count` is 1; `minimum`, `target` and `maximum` are the count policy's values; `{"amount": N}` is N (decisions 29 and 36); `daily_pace` is that day's pace share, and at least 1. `daily_pace` is only for a total with an end date or a number of days, and the sentence makes it their default; an open-ended total defaults to `any_count`.

**A day's status** (`make_up.json`), for each unit (the day, or each session):
- `met`: at least its target (if it has a daily target: per due date, days per period) and its streak amount;
- `made_up`: filled by make-up to its fill amount;
- `minimum_only`: at least the streak amount, below the target;
- `pending`: not kept, but its make-up window is still open (decision 46): today is on or before its last window day, and the goal is still running;
- `missed`; or, for today, `in_progress`.

With sessions, the day takes the worst session status: in progress, then missed, pending, made up, minimum only, met. A day **keeps the streak** when it's met, minimum only or made up. **Today and pending days are open:** they neither break the streak nor add to it, so a missed day with make-up on breaks the streak only once its window closes unfilled. With make-up off, a missed day breaks it at once. `goal_streak` also lists the pending days (`pending_make_up`), so a row can read "🔥 15 · make up Mon".

**Streak units** (`goal_streak.json`, decision 43), from the version in force today:

| Goal | Unit | Counts | Display |
|---|---|---|---|
| Period total or days per period, week | `week` | Weeks meeting the requirement | 🔥 5 weeks |
| Period total or days per period, month or Hijri month | `month` | Months meeting it | 🔥 3 months |
| Yearly schedule (an occasion) | `occasion` | Occasions whose every due day kept the streak | 🔥 2 Ramadans |
| Weekdays with exactly one weekday | `weekday` (with `weekday`) | Due days | 🔥 12 Fridays |
| Anything else | `day` | Due days | 🔥 15 days |

**An occasion** is one year's due days of a yearly schedule, in its own calendar (the Hijri year for Hijri ranges). A range that runs over the year end belongs to the year it starts in. The current occasion is in progress while it has due days after today, or today or a pending day isn't settled yet; it doesn't break the streak while in progress, and adds only once complete.

## Make-up

`make_up` is `{window, fill}` (decisions 18, 31 and 48). `window` is `off`, `next_day` or `within_3_days`. `fill` is `streak` (fill to the streak amount, the sentence's default) or `target` (fill to the target, or the streak amount if higher). A window other than `off` is allowed on:
- per-due-date goals;
- totals whose streak counts at `{"amount": N}`, filled to N, so `fill` must be `streak` there. A total without an amount has no daily number to fill, so no make-up.

- A **missed day's** window is its own version's, and counted in practice days: the next day, or the next 3.
- **Every later day** in the window gives what it has past its own needs: its target, or its streak amount if higher. A day that isn't due gives all its counts. Paused days, excused days and days after the goal's end give nothing.
- Missed days are filled **oldest first**, each up to its fill amount, and a day can be filled across several days. A partly filled day is pending while its window is open, and missed after.
- **With sessions**, each session is made up from the same session only.
- Make-up is derived from the counts, never stored, so an adjustment that lowers a later day also lowers what it made up.

## Excused days

`excused_days.json` (decision 20). An excused day is skipped like a paused day: not due, so it neither breaks nor adds to a streak, and in "N days a period" goals it lowers that period's number by one.

Excusing a day needs, checked in this order (the reason is the first that fails):

1. the goal is still running (`goal_finished`: ended, or past its last day);
2. the day is before today (`not_past`);
3. it isn't excused already (`already_excused`);
4. the goal is judged by day (`not_available` for period totals);
5. the day is due (`not_due`: off-schedule, paused or outside the active period);
6. it wasn't kept (`not_missed`: met, minimum only or made up; for days per period, a day that didn't qualify). A day pending make-up can be excused;
7. fewer than 2 days are already excused in that day's Gregorian month (`limit_reached`).

Un-excusing needs a running goal and an excused day (`not_excused`), and frees the place in that month.

## Consistency

`consistency.json` (decisions 19, 21 and 32):
- **Daily-rhythm goals** (units day, weekday, occasion) count the due days that kept the streak among the last 30 due days.
- **Period goals** count the met periods among the last 12.
- Today, or the current period, is included only once kept or met, and a day pending make-up only once its window closes.
- **No tag before 7 due days or 4 periods.** After that, **Devoted** at 90% or more, **Steady** at 80% or more, and no tag below.

**What a row shows:**
- 🔥 and the streak when it's 3 or more;
- otherwise the tag ("Steady · 25/30") if there is one;
- otherwise 🔥 for a streak of 1 or 2;
- otherwise nothing.

## Daily pace, rings and lists

- **Daily pace** (`daily_pace.json`, decision 28), for a total with an end:
  - what's left before today, divided by the due days from today to the last day, rounded up;
  - fixed for the day, recalculated the next day;
  - `null` without an end, or when today isn't due.
- **Today's ring** (`today_ring.json`, decision 33). Every ring means today:
  - daily goals and N days a period: today's target. With sessions, their targets combined, each session counting up to its own;
  - period totals: the week or month so far;
  - totals: their streak amount, which is the pace with `daily_pace`;
  - trackers: their number until it's reached, and never with any count;
  - nothing when today isn't due.
- **Placement** (`goal_list_placement.json`, decisions 12, 25, 26, 30 and 46). The first match wins:
  1. **History:** ended in the document, completed by its policy, past its last day, or no scheduled day left in the next 400 days;
  2. **Paused:** paused today;
  3. **Tracking:** trackers;
  4. **Today:** due today, or with a day pending make-up (so it can be made up);
  5. **Upcoming:** with its next due day.

  **Order:**
  - Today, Tracking and Paused follow the account's `goal_order`, then the goals it doesn't name by `created_on` and ID;
  - Upcoming is soonest first, then that order;
  - History is newest first, then that order.

## The goal order

`goal_order` is one sync entity per account, its ID the account's ID, holding `$defs/goal_order_document` `{goal_ids}`. It's written only when the user reorders, with every active goal in their order. Phones merge a conflict on it instead of asking (`goal_order_merge.json`), keeping `base_document` like the practice policy:
- unchanged locally, take theirs;
- otherwise mine wins, less the goals the server dropped since the base, plus the goals the server added since the base, appended in its order;
- queue the result on the server's version when it differs from theirs.

## Validity

`goal_validity.json` describes invalid goals (`goal`) and documents (`document`). Errors are sorted alphabetically.

| Code | Problem |
|---|---|
| `target_required` | No target on a goal that isn't a tracker |
| `session_target_required` | A session without a target, when the goal isn't a tracker |
| `streak_threshold_value_required` | The streak threshold names a minimum, target or maximum that isn't set |
| `streak_pace_not_allowed` | `daily_pace` on anything but a total with an end |
| `end_date_and_duration` | Both an end date and a number of days |
| `make_up_not_allowed` | A make-up window on a goal that isn't per due date, or a total counting at an amount with `fill: streak` |
| `sessions_with_minimum_or_cap` | Sessions together with a minimum or cap on the goal (sessions have no place for one) |
| `session_id_mismatch` | A session ID that isn't derived from its kind |
| `session_duplicate` | Two sessions with one ID |
| `session_window_empty` | A `between` window from a time to the same time |
| `structural_change` | Versions disagree on a structural field |
| `versions_out_of_order` | Version `from` days not strictly increasing |
| `first_version_not_created_on` | The first version doesn't start on `created_on` |

A document has every version's errors (each version with the document's pauses and excused days) plus its own. The schema's `goal_rules` expresses the first seven; `tools/check-goal-model.mjs` checks that goal_validity agrees with it.

## Judgment calls

The decisions don't settle these; slice 4a settled them as follows. The user reviewed them on 2026-10-31: 1, 5, 6 and 17 (the server's date) were accepted (decision 49); 9 and 10 were replaced by decisions 48 and 46; 24–27 came from applying decisions 46–48.

1. **Accepted.** **Session IDs are derived from the kind** (`after_fajr`, `at_0630`, …), so shared counts match sessions across goals. Two sessions of one kind in one goal are therefore invalid.
2. **Attribution drops an entry whose session the goal doesn't have** (when the goal has sessions that day). A goal without sessions takes all its dhikr's entries as the day's count.
3. **A day's count summing below 0** (two devices subtracting at once) counts as 0.
4. **`counts` (shared or dedicated) can't change** after creation, because it decides which past entries are the goal's.
5. **Accepted.** **`daily_pace` is a streak threshold value.** It's the default for a total with an end, and the sentence's "streak counts at N a day" replaces it with `{"amount": N}`. A pace share of 0 (nothing left) needs 1.
6. **Accepted.** **Pace rounds up**, so the goal finishes on time. It excludes today's own counts, so it doesn't shrink while counting. Totals with sessions have no pace.
7. **Make-up:**
   - windows count in practice days, not due days, so a Friday-only goal missed on Friday can be made up Saturday to Monday;
   - a day that isn't due gives all its counts;
   - a later due day gives only what's past its target, or its streak amount if higher;
   - paused and excused days give nothing;
   - oldest missed day first;
   - with sessions, each session only fills itself;
   - the window is the missed day's version's.
8. **`fill: target` fills to the target, or the streak amount if higher**, and also fills a minimum-only day up to its target, turning it into made up.
9. **Replaced by decision 48:** make-up is also for totals whose streak counts at `{"amount": N}`, filled to N (`fill: streak` only).
10. **Replaced by decision 46:** a missed day inside its open make-up window is pending and doesn't break the streak; with make-up off it breaks at once, as in the slice 1 case `partial_yesterday_breaks`.
11. **Excused days:**
    - only before today; today can't be excused;
    - not on period totals (no day-level judgment);
    - the month is the Gregorian month of the excused day, not of today;
    - an excused day can be un-excused while the goal runs, which frees its place;
    - there's no limit on how far back a day can be excused.
12. **Excused days in "N days a period"** lower the required number by one each. A period that then needs 0 days isn't due, so it's skipped in streaks.
13. **Occasions:**
    - only yearly schedules count in occasions. White Days (`hijri_month_days`) and Gregorian month days count due days;
    - an occasion is one year's due days in its own calendar, and a range over the year end belongs to its start year;
    - an occasion with a period requirement (six days of Shawwal) counts months.
14. **The unit "weekday"** is only for a schedule of exactly one weekday ("🔥 12 Fridays"). Several weekdays count days.
15. **Consistency:**
    - in the first 7 due days (or 4 periods) no tag shows, and the row shows the streak if any;
    - after that, the window is every due day so far, up to 30 (periods, up to 12);
    - the minimum for period goals is 4 periods;
    - kept days (met, minimum only, made up) count as met.
16. **The row shows the streak from 3 units in all rhythms** (decision 21 says 3 days), and also shows a streak of 1 or 2 when there's no tag. That makes the rule stateless.
17. **Ended goals:**
    - `ended.on` is the last day, inclusive;
    - an ended goal's last day is in progress while it's today, and final after;
    - the server's cascade writes the UTC date it applies the delete on (sync/v1), which can differ by a day from the user's practice day. **Accepted.**
18. **The same-day edit rules** in `goal_version_add`: replace today's version, and remove it when edited back. A last version starting after today is replaced in place. The 100-version fold drops the oldest version and gives its `from` to the next.
19. **The start date can't change** between versions: it's a structural field.
20. **Placement:**
    - a goal is in Today only when it's due today. Period totals with an every-day schedule are due every day, which covers decision 12's "mid-period" case;
    - a goal with no scheduled day in the next 400 days, ignoring pauses, is finished;
    - Upcoming looks 400 days ahead;
    - new goals not named in `goal_order` go after the named ones, oldest first.
21. **`goal_order` merge:** the phone's order wins, the server's additions are appended, and the server's removals are applied.
22. **The goal-level target of a goal with sessions** is ignored, as in slice 1.
23. **`one_time` is kept** and evaluated like `every_day`. The sentence writes `every_day` for a total with no rhythm.
24. **Pending days** (decision 46) are in `goal_streak`'s `pending_make_up`, not in a separate rule. A day is pending only while the goal is still running; after its end, an unfilled day is missed.
25. **A day pending make-up can be excused,** since it isn't kept: the user may excuse it instead of making it up.
26. **A goal with a day pending make-up is in Today's goals** even when today isn't due (a Friday goal on Saturday), so it can be made up; once the window closes it goes back to Upcoming.
27. **Session targets:** a session's `target` is `null` only on a tracker's session, which then keeps the streak with any count. The goal-level target of a goal with sessions is still ignored (22).

## Running

`npm test` in `contracts/` checks every file and every case against these schemas. It also runs `tools/check-goal-model.mjs`, which:
- runs every case through `tools/goal-rules.mjs`, a reference reading of this README that no platform imports;
- checks that every evaluated goal, timeline and document is valid;
- checks that `goal_validity` agrees with the schema.

Each platform runs the cases through its own implementation:

| Platform | Runner | Implementation |
|---|---|---|
| Android | `:core:testing` fixture runner, run by `:core:domain:test` | `:core:domain` |
| iOS | `AwradTesting` fixture runner, run by `swift test` | `AwradDomain` |
| Server | ExUnit fixture runner | `Awrad.Goals.Rules` |
| Web | Vitest fixture runner (slice 4a) | `src/shared/goals` |

Slice 1b added the Hijri and yearly schedule kinds and the `hijri_month` period to this version. Seasons are presets over them ([`goal-presets/v1`](../../goal-presets/v1/)), not a schedule kind.
