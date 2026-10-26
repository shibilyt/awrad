# Slice 01b: Domain foundation, Hijri (calendar, yearly, seasons)

Status: In progress. Step 3 fixtures ready for review (2026-10-26)
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 1b
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)
Builds on: [slice 01a](01-domain-foundation.md) (`contracts/goal-model/v1/`)

## Goal

Every platform agrees on the Hijri date of an effective practice day, and on when Hijri, yearly and seasonal goals are due. Like 01a, the rules exist once as shared fixtures and pass on Android, iOS and the server (which evaluates for the web).

## Scope

| In scope | Out of scope (and where it goes) |
|---|---|
| A rule for the Hijri date of an effective practice day, with month-start corrections | Showing Hijri dates, month names in en/ar/ml, a "primary calendar" display setting: slice 3 and later |
| New schedule kinds: Hijri month days, yearly (Gregorian or Hijri), seasons | Wird Hijri gates (`HijriAnchor`): the wird slice, reusing this slice's calendar |
| Goal presets (seasons and occasions) with stable keys in `contracts/` | Storing and syncing Hijri corrections, and the "Today is 1 Ramadan" screen: the practice-settings slice. Regional corrections: later |
| Hijri months as periods for period-total and days-per-period goals | Reminders on Hijri dates: the reminders slice |
| Fixture cases for all of it, run on every implementing platform | Moon-sighting data feeds |

Platforms: Android ☐ · iOS ☐ · server ☑ (evaluates for the web) · web n/a (displays the server's standing)

## Decisions (answered 2026-10-26)

1. **One shared Umm al-Qura table** in `contracts/hijri-calendar/v1/`, 1400–1500 AH. No platform uses a Hijri library for rules (root ADR-2026-10-26).
2. **Moon-sighting corrections**, as month-start corrections rather than a fixed offset:
   - A correction moves a month's start, and every later month's, until the next correction.
   - It's **at most 2 days from the table**.
   - Every month still has 29 or 30 days.
   - The account's corrections are part of the account practice policy. Server-published regional corrections are a later option, and the account's own corrections win over them.
   - Users will enter them as "Today is 1 Ramadan" (UI in a later slice).
3. **Seasons are presets, not a schedule kind.** The rules know two general Hijri schedules: `hijri_month_days` and `yearly` (Gregorian or Hijri dates and ranges).
   - A preset (Ramadan, white days, six days of Shawwal…) fills them in, and its key is only a label.
   - Users build their own occasions with the same schedules.
   - The presets live in `contracts/goal-presets/v1/`.
4. **Presets shipped:** today's six seasons, plus the odd nights of Ramadan, the sacred months and six days of Shawwal. Adding more is a content change.

Defaults kept from the draft:
- The Hijri date follows the effective practice day.
- A Hijri day 30 falls on the 29th in a 29-day month, and 29 February on the 28th in a common year.
- Outside the table, Hijri schedules aren't due. This replaces the draft's "invalid goal": an open-ended goal would otherwise always be invalid.

## Behaviour inventory (step 2)

Studied 2026-10-26 from the frozen Android, iOS and server code.

Abbreviations:
- `A:` = `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/`
- `I:` = `awrad-ios/awrad/awrad/`
- `S:` = `awrad_server/`

| # | Behaviour | Today (frozen apps) | Proposed decision | Evidence |
|---|---|---|---|---|
| 1 | Hijri calculation | Android: `java.time.chrono.HijrahDate` (Umm al-Qura) for goals, and ICU `ISLAMIC_UMALQURA` for wirds (two engines). iOS: Foundation `.islamicUmmAlQura`. Server: none | **Change:** one shared table (decision 1) | `A:util/GoalProgressCalculator.kt:13`, `A:data/wird/IcuHijriCalendar.kt:17-25`, `I:Core/AwradCalculators.swift:147-150` |
| 2 | Supported range | `HijrahDate` throws outside 1300–1600 AH; ICU falls back silently | **Change:** 1400–1500 AH; outside it Hijri schedules aren't due | `HijrahDate.from` calls have no guard |
| 3 | Hijri adjustment | None on any platform. A product note accepts the difference from sighting | **New:** month-start corrections (decision 2) | `awrad-android/prd/decisions/015-dual-calendar-system.md:75` |
| 4 | Hijri day boundary | Derived from the effective Gregorian date: changes at Maghrib only with the Maghrib reset | **Keep** | `A:ui/screens/home/HomeViewModel.kt:175`, `I:Features/Home/HomeView.swift:66-68` |
| 5 | Hijri monthly | `month_days` in the Hijri calendar | **Keep**, as a new `hijri_month_days` kind | `A:util/GoalProgressCalculator.kt:63-71`, `I:Core/AwradCalculators.swift:158-160` |
| 6 | Day 30 in a 29-day Hijri month | Never due that month | **Fix:** falls on the last day, as in 01a | `I:Core/AwradStore.swift:2505-2510` |
| 7 | Yearly (Gregorian or Hijri) | `month` plus a day set; an empty set means the whole month | **Keep** the idea, as one `yearly` kind with a calendar and explicit month-day pairs; no "empty means whole month" | `A:util/GoalProgressCalculator.kt:78-90`, `I:Core/AwradCalculators.swift:168-175` |
| 8 | Recurring Hijri specific dates | `GoalSpecificDate{calendar, month, dayOfMonth}`; **lost on sync** (the v1 wire format holds plain dates only); no editor UI | **Merge into `yearly`** (a recurring Hijri date is a yearly date) | `A:data/model/GoalRecurrence.kt:19-24`, `contracts/progress-model/v1/progress-model.schema.json:98` |
| 9 | Season codes | Six seasons. Android wires `ramadan_last_10`; iOS wires `ramadanLast10`: **only 3 of 6 survive sync** between them | **Fix:** presets with snake_case keys in `contracts/goal-presets/v1/`; the key is only a label (decision 3) | `A:data/contract/v1/ProgressContractV1.kt:273`, `I:Core/ProgressContractV1.swift:533` |
| 10 | Season catalog contents | `ramadan` (9:1–30), `ramadan_last_10` (9:21–30), `dhul_hijjah_1_10` (12:1–10), `white_days` (13–15 of every month), `ashura` (1:9–10), `arafah` (12:9) | **Keep** these six as presets, plus odd nights, sacred months, six days of Shawwal (decision 4) | `A:data/model/GoalRecurrence.kt:34-72`, `I:Core/AwradDomain.swift:450-457` |
| 11 | Season templates storage | Android seeds a table from code; iOS has a SwiftData table that's never seeded; server stores a free string | **Fix:** the presets file is the source. Goals store the full schedule, so no table is needed to evaluate them | `A:di/DatabaseModule.kt:118-136`, `S:lib/awrad_server/tracking/goal.ex:19-27` |
| 12 | Hijri month as a period | Period windows walk to the Hijri month's edges | **Keep**, as a `hijri_month` period for period-total and days-per-period goals | `A:util/GoalProgressCalculator.kt:156-178`, `I:Core/AwradCalculators.swift:253-273` |
| 13 | Server evaluation | Hijri and season rules fall through to `false`; season codes aren't validated | **Fix:** the server implements every rule | `S:lib/awrad_server/practice/eligibility.ex:69-125` |
| 14 | Device calendar | Android immune; iOS uses `Calendar.current` in places | **Fixed in 01a** (explicit calendars) | `docs/slices/01-domain-foundation.md` row 3 |
| 15 | Month names | Hard-coded English, even in Arabic | Out of scope (display); must come from localization resources | `A:util/DateUtils.kt:14-18`, `I:Core/AwradLocalization.swift:25-37` |

## Domain and fixtures (step 3)

Done 2026-10-26, awaiting review.
- **`CONTEXT.md`:** Hijri date, Hijri correction, Goal preset, the new schedule kinds, and the Hijri month as a period.
- **New contracts:**
  - `contracts/hijri-calendar/v1/`: the table, its schema, `hijri_date.json` (22 cases) and `hijri_corrections_validity.json` (16 cases);
  - `contracts/goal-presets/v1/`: 9 presets.
- **`goal-model.schema.json`:** new schedule kinds `hijri_month_days` and `yearly` (calendar `gregorian` or `hijri`), and the period `hijri_month`. Impossible yearly days (30 February, Hijri 31) are structural errors.
- **New goal-model cases**, 47 in total. Every rule that reads Hijri dates takes an optional `hijri_corrections`.

  | File | New cases | Covering |
  |---|---|---|
  | `goal_is_due` | 34 | Hijri and Gregorian yearly, ranges over the year end, day 30 / 29 February clamping, corrections, the table's edges |
  | `requirement_standing` | 4 | Hijri-month totals, with a correction, clipped, after the table |
  | `days_per_period` | 4 | Six days of Shawwal |
  | `goal_streak` | 5 | Ramadan across years, white days, Hijri-month periods, Shawwal across years |
- **Totals:** the goal model has 172 cases and the Hijri calendar 38, so 210 shared cases. All agree with the reference implementation.
- **`npm test` also checks the catalogs:** every table month is 29 or 30 days, and the presets match the schema.
- **CI:** the Android, iOS and server jobs now also run when `contracts/goal-model/` or `contracts/hijri-calendar/` change. Before, a fixture-only change didn't re-run the platforms.

## Contract (step 4)

No API operations in this slice.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-android-next | Table loader, Hijri date and corrections, new schedules and period in `:core:domain`; runners for the two new files | Gradle validation | ☐ |
| awrad-ios-next | The same in `AwradDomain` | `scripts/validate` | ☐ |
| awrad-server-next | The same in `Awrad.Goals.Rules`, with the calendar in `Awrad.Hijri` (table compiled from a checked `priv/` copy, server ADR 0004) | `mix validate` | ☑ |
| awrad-web-next | Nothing in this slice | – | n/a |

## Integration evidence (step 6)

No UI in this slice. The evidence is every implementing platform passing the same fixture files in CI.

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
