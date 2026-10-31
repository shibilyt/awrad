# Slice 4: Goals

Status: Agreed 2026-10-31 (scope and questions 1–15, all as recommended); 4a done 2026-10-31; 4b next (steps 3 and 4 done)
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 4
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)
Decisions: [`04-goals-decisions.md`](04-goals-decisions.md) (49 decisions, 2026-10-30 and 2026-10-31). Prototype: branch `prototype/goals`, `prototypes/goals/`.

## Goal

People set daily, weekly, total and occasion goals for any dhikr with one editable sentence, see what's due today, and keep going through streaks, gentle consistency tags, make-up days and excused days. All of it works offline and signed out on phones, and syncs when signed in.

## Proposed split

The decisions are more than one pass across five projects can deliver (playbook, "Size"). Proposed:

| Slice | What | Platforms |
|---|---|---|
| **4a. Goal rules** | Contract and domain only, like slice 1: the goal document, dated versions, count attribution (shared or dedicated), streak units, consistency, make-up, excused days, pace, list placement, validity. Fixtures and runners. Also the whole slice 4 contract, including the `goal` and `goal_order` sync entities, so 4b builds against it | Contracts, Android, iOS, server, web |
| **4b. Goals** | Screens and sync: create (sentence), My Goals (Today, Upcoming, Tracking, Paused), History, editing, ending and deleting, the stats sheet, the empty state, reordering, the "too many goals" note, dhikr deletion ending goals, conflict notices. Progress is read from the local count log, which 4b creates and slice 5 fills | All four |
| **5. Counting** | The counter (bottom circle, tap area, ring, minimum tick, target alert, cap), adjust, undo and reset, late counting, make-up filling, count log sync, sound and vibration settings | All four |

Home's Today's goals card (decision 24) stays with the Home screen in 7+, built to the decisions recorded here.

## Scope (4a and 4b)

| In scope | Out of scope (and where it goes instead) |
|---|---|
| The goal document: dhikr, a snapshot of the dhikr's label, name, shared or dedicated counts, dated versions of its settings, pauses, excused days, ended | The counter screen and tapping (5) |
| Session kinds: anytime, after a prayer, at a time, between two times (decision 10) | Reminders and notifications (7+) |
| Count attribution: which count-log entries fill which goal (decisions 1–2) | Count log sync (5); 4a fixes its shape |
| Streaks in the goal's rhythm, consistency tags, the 3-day return to 🔥 (19, 21, 43) | Volume buttons and pocket mode (later, decision 45) |
| Make-up with a window and fill amount, excused days with a monthly limit (18, 20, 31) | Seasonal goal suggestions (later, decision 40) |
| Daily pace for total goals with an end date; "today" rings for open-ended totals and trackers with a number (28, 29, 33, 36) | Sequenced dhikr in one goal (later) |
| Create with the sentence, including occasions, details, examples and the read-back (6–9) | The other create flows (A wizard, C templates) from the prototype |
| My Goals sections and user order; History grouped by year; Start again (12, 25, 26) | Home's goal card (7+, to these decisions) |
| Editing from today with dated versions; structural edits end and restart (23) | Stats beyond the stats sheet (history and stats, 7+) |
| End goal, delete from History, Undo (27) | |
| Deleting a custom dhikr ends its goals (37) | |
| The empty state's Isthighfar suggestion (40, 41) and the "too many goals" note (42) | |
| Conflicting goal edits: first to the server wins, notice with retry (44) | |

Platforms: server ☐ · Android ☐ · iOS ☐ · web ☐ (4a includes the web: a TypeScript rules module and fixture runner, question 2)

## Open questions

All answered 2026-10-31: **all as recommended**.

1. **The split** into 4a, 4b and 5 as above? *Recommended: yes.*
2. **The web.** It's online-only and has no domain runner today. In 4b it can create, edit, list and show History. Does the web also count, in slice 5? *Recommended: yes, the same counter, sending counts in small batches while online.* And does the web evaluate rules itself (a TypeScript runner for the goal fixtures), or ask the server for evaluated progress? *Recommended: a TypeScript runner, so lists render without a round trip and the fixtures stay the single spec.*
3. **The goal model version.** Edit `goal-model/v1` in place (nothing is released) or start `v2`? *Recommended: edit v1 in place and update the slice 1 runners as part of 4a.*
4. **Where the user's goal order lives.** One `goal_order` entity per account holding the list of goal IDs (like `practice_policy`, merged rather than conflicted), or a sort key on each goal? *Recommended: one `goal_order` entity: reordering is one change, not one per goal.*
5. **Dated versions.** Kept inside the goal document as `versions: [{from, …settings}]`? A goal edited daily for years could grow, so cap at 100 versions, folding the oldest into the first. *Recommended: yes, inside the document.*
6. **Limits.** At most 300 active (not ended) goals per account, and 2,000 in total including History? *Recommended: yes. Nobody reaches them, and they bound the server.*
7. **Custom dhikr deletion.** The sync README says "From slice 4, a custom dhikr that goals use can't be deleted". Decision 37 replaces that: the server ends its goals as a cascade in the same revision, listed in the receipt's `cascaded`. *Recommended: yes, and update the README.*
8. **Which days a total goal is due.** "Say Salawat 70,000 times in total" with no rhythm: due every day (so streaks, pace and Today's goals work), or only on days the user picks? *Recommended: every day by default; the sentence's rhythm can narrow it. The old apps made it due only on its first day.*
9. **"Before a prayer" sessions** (the old apps have before and after, with a lead time). Keep "before a prayer" as a session kind? *Recommended: yes: `before_prayer` and `after_prayer`, with no lead time (the window only guides).*
10. **White Days (13–15 of each Hijri month) and the sacred months.** The old Android app has White Days, and `goal-presets/v1` has both, but decision 6's list leaves them out. *Recommended: add both to the occasions.*
11. **Dropping the old count modes** (Stretch, Exact, Bounded, warn over target, block at target). Minimum, target and "stop at" cover them all. *Recommended: drop them.*
12. **Day boundary.** Every "day" in these rules follows the practice day from 3d (midnight or Maghrib reset): "until the end of today" means the end of the practice day, and the excused-days month is the Gregorian month of the practice day. *Recommended: yes.*
13. **Stats sheet extras** in the old apps (7/30/90-day ranges, peak day, per-session share, time estimate). *Recommended: leave them to "history and stats" (7+), and keep D22's sheet.*
14. **Suggested goals on a dhikr's page** (hand-written per dhikr in the old app). *Recommended: drop for now; "Set a goal" prefills the sentence, and suggestions can return with the content review.*
15. **Flame tiers** (more flames for longer streaks, at different thresholds on Android and iOS). *Recommended: drop them; one 🔥 and the number.*

## Behaviour inventory (step 2)

Study of the frozen apps, 2026-10-31.

**Paths:**
- `A:` = `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/`
- `I:` = `awrad-ios/awrad/awrad/`
- `IT:` = `awrad-ios/awrad/awradTests/`

Android and iOS are almost identical (iOS mirrors Android), and the rows note where they differ. No frozen app has a goal limit, streak freeze or grace, make-up, excused days or completion celebration.

| Behaviour | Today (frozen apps) | Decision | Evidence |
|---|---|---|---|
| Where counts live | Per goal (goal, slot, date); goals of one dhikr never share | change: per dhikr, shared or dedicated (D1, D2, D5) | `A:data/repository/GoalRepositoryImpl.kt:252-306`, `I:Core/AwradCalculators.swift:21-36` |
| Second goal on a dhikr | No prompt; dhikr page hides an identical suggested goal | change: ask about sharing only then (D3) | `A:ui/screens/dhikrdetail/DhikrDetailViewModel.kt:128-141` |
| Count sync | Per-bucket increment/decrement/reset commands, server ledger | change: append-only log keyed by dhikr and practice day (D5; slice 5) | `A:data/sync/ProgressSyncRepository.kt:561,702`, `awrad_server/lib/awrad_server/progress_sync/count_ledger.ex:35-60` |
| Create flow | Pick a dhikr, then 3 shapes plus a large Advanced composer; 7 quick presets | change: one editable sentence with clauses (D6, D7) | `A:ui/screens/goals/SelectGoalShapeStep.kt:22-27`, `A:data/model/GoalPreset.kt:3-12` |
| Entry points | Goals +, onboarding first goal, dhikr suggestions, open counter after create | keep + and "Set a goal" from a dhikr (D8); onboarding is slice 6 | `I:Features/Library/LibraryView.swift:862,981` |
| Requirement kinds | Per due date, cumulative, period total, none (tracker) | keep, plus days per period (slice 1) | `A:data/model/GoalPolicy.kt:3-8` |
| Schedule kinds | Daily, weekdays, month days (both calendars), every N days, yearly, seasons, specific dates | keep (D6), with the sentence's limits (D9) | `A:data/model/GoalPolicy.kt:10-18` |
| Occasions | Ramadan, its last 10, Dhul Hijjah 1–10, White Days, Ashura, Arafah; no six of Shawwal | change to D6's list; White Days and sacred months: question 10 | `A:data/model/GoalRecurrence.kt:34-72`, `contracts/goal-presets/v1/README.md` |
| Verb by kind | None; the title only | change: Say, Read, Recite (D6) | `A:ui/screens/goals/GoalsViewModel.kt:170` |
| Count rules | 6 modes (Tracker, Minimum, Target, Stretch, Exact, Bounded); warn or block over target | change: "at least" and "stop at" only; past the target always counts, only a cap stops (D7, D15, D34); question 11 | `A:util/CountCapCalculator.kt:26-104`, `A:ui/screens/goals/model/GoalDraft.kt:68-75` |
| "Allow counting past target" | Flips a block-at-target goal to allow | drop (D34) | `A:domain/usecase/AllowCountingPastTargetUseCase.kt:35-73` |
| Duration and end | Gate whether it's due; `DurationEnded` never applied; not editable | change: until / N days / until I stop, editable end, Ended into History (D7, D23, D26) | `A:util/GoalProgressCalculator.kt:46-55` |
| Total goal schedule | A quick one-time goal is due only on its start day, then falls into Past | change: question 8 | `A:ui/screens/goals/model/GoalDraft.kt:780-784`, `IT:GoalQuickSetupTests.swift:15-37` |
| Default streak threshold | Android: the target or minimum; iOS: 1 | change: an explicit "streak counts at" clause (D7, D29) | `IT:GoalQuickSetupTests.swift:6-13` |
| Suggested goals per dhikr | Hand-written suggestions on the dhikr page, confirm then create | question 14 | `A:data/DhikrBenefits.kt:11-17` |
| Starter goal | Onboarding: Istighfar, 70 by default, quick picks 33/70/100/313 | change: "Isthighfar 100 a day, at least 70" on the empty state (D40) | `A:ui/screens/onboarding/FirstGoalPresets.kt:25-52` |
| Validation | Duration, threshold, schedule, timing, target unless tracker | keep, shown inline in the sentence (D7) | `A:domain/model/goalcreation/GoalFactory.kt:35-51` |
| Sessions | Anytime, before/after a prayer with a lead time, time window; own minimum, target, cap | change: session kinds (D10), sessions XOR minimum/cap (D9); "before a prayer": question 9 | `A:data/model/GoalSlot.kt:3-33` |
| A session day is met | The total against the sum of session targets: one session can cover another | change: every session meets its own number (D11) | `A:util/GoalProgressCalculator.kt:19-31,301-324` |
| Counting off-schedule | Warn and allow by default; a strict mode; paused or ended goals blocked | change: windows guide, never block (D11); paused and ended: slice 5 | `A:ui/screens/counting/CountingAvailability.kt:56-104` |
| Pause | "Archive", no pause history; a pause breaks the streak | change: dated pause ranges (already `paused` in the goal model), skipped like excused days, Paused section (D12, D20) | `A:domain/model/goalcreation/GoalLifecycleUpdateFactory.kt:6-31`, `A:util/GoalProgressCalculator.kt:258-268` |
| Lists | Active (Today, Upcoming) and History (Past, Completed, Archived), newest first. iOS: Upcoming is only the next 7 days | change: Today, Upcoming with when, Tracking, Paused, History; user order (D12, D25, D30) | `A:ui/screens/goals/GoalsViewModel.kt:87-115`, `I:Features/Goals/GoalsView.swift:12-52` |
| Reordering | None (`createdAt DESC`) | change: user order (D25) | `A:data/database/dao/GoalDao.kt:14` |
| Home card | Due today, first unfinished first, 3 goals, trackers included, streak and recent days | change: D13, D24, D30 (built with Home in 7+) | `A:ui/screens/home/HomeViewModel.kt:185,229-235` |
| Row ring | Today's share, period total, or lifetime total for cumulative | change: every ring means today (D33) | `A:util/GoalProgressCalculator.kt:208-240` |
| Streak | Days only, up to 366 back; partial today reads 0 | change: the goal's rhythm, open current period (D43); per-period rules already in `goal_streak.json` | `A:util/GoalProgressCalculator.kt:243-276` |
| Streak display | Flame tiers: Android 6/21/40, iOS 3/15/30 | change: one 🔥 and the consistency fallback (D19, D21); question 15 | `A:ui/components/GoalStreak.kt:45-55`, `IT:GoalLifecycleTests.swift:139-157` |
| Consistency | Stats show adherence, presence, "affinity" | change: Steady and Devoted tags (D19, D32) | `A:util/GoalHistoryStatsCalculator.kt:107-121` |
| Missed days, late counting | Missed only in stats; no counting for yesterday | change: late counting (D17), make-up (D18, D31), excused (D20) | `A:util/GoalHistoryStatsCalculator.kt:83-106` |
| Day boundary | Midnight or Maghrib reset | question 12 | `A:util/EffectiveDayWindowResolver.kt:15-32` |
| Completion | Cumulative with auto-complete; reopens if counts drop; edits can reopen; iOS has manual complete | change: completed into History, never reactivated (D12, D26) | `A:data/repository/GoalRepositoryImpl.kt:224-242,288-300` |
| Target reached | Sound and 1 s vibration; iOS "Keep counting" card | change: alert only, no card (D34; slice 5) | `A:service/DhikrCountingService.kt:454-470` |
| Goal page and stats | Detail screen; the counter's insights with 7/30/90/all ranges, peak day, per-session share, time estimate. iOS: last 12 rows | change: the counter is the goal page, a stats sheet (D22); question 13 | `A:util/GoalHistoryStatsCalculator.kt:8-46`, `I:Features/Goals/GoalDetailView.swift:215-240` |
| Editing | In place; changes how past days are judged | change: dated versions; structural edits end and restart (D23) | `A:util/GoalProgressCalculator.kt:299-300`, `IT:GoalLifecycleTests.swift:314-396` |
| Removing a session | Archived so its counts resolve; the last can't go | keep the principle under D23 (a version without it) | `A:domain/model/goalcreation/GoalScheduleUpdateFactory.kt:43-64` |
| Delete | Hard delete with its counts, no undo | change: end, delete only from History or without counts, Undo; shared counts stay (D27) | `A:data/repository/GoalRepositoryImpl.kt:244-250` |
| End goal | None; only by date or reaching the total | change: "End goal" (D27) | `A:ui/screens/goals/GoalsViewModel.kt:97-102` |
| History actions | Restore (archived), delete; no Start again | change: Start again, read-only stats, years (D26) | `A:ui/screens/goals/GoalsScreen.kt:725-800` |
| Deleting a custom dhikr | One confirm, then goals, counts and audio are hard-deleted | change: goals end into History, history and counts stay, label snapshot (D37) | `A:data/repository/CustomDhikrDeletionCascade.kt:11-57`, `I:Core/AwradStore.swift:502-519` |
| Goal limits | None | change: none, a gentle note (D42); server bounds: question 6 | — |
| Goal sync conflicts | Conflict rows; the only UI is a count in Settings | change: first wins, notice with retry (D44) | `awrad_server/lib/awrad_server/progress_sync/entity_conflict.ex:10-20` |
| Goal reminders and streak nudge | Per-goal reminders, "keep your streak" nudge | out of scope (7+); the nudge must follow D43's units | `A:data/model/GoalReminder.kt:3-13`, `A:notification/UrgencyNudgeFireValidator.kt` |

## Domain and fixtures (step 3, slice 4a)

Done 2026-10-31. The rules, conventions and every judgment call the decisions left open are in [`contracts/goal-model/v1/README.md`](../../contracts/goal-model/v1/README.md) (section "Judgment calls"). The user reviewed them on 2026-10-31: decisions 46–49.

**New and changed terms in `CONTEXT.md`:**
- dhikr snapshot;
- shared and dedicated counts, and the count log;
- dated version;
- excused day;
- sessions (kinds);
- ended and completed goals;
- streak unit;
- make-up (window and fill);
- consistency and the consistency tag;
- daily pace;
- My Goals sections (Tracking);
- goal order;
- conflicts on goals.

**Goal model changes (`goal-model/v1`, edited in place):**
- **Sessions** gain a `kind`: `anytime`, `before_prayer {prayer}`, `after_prayer {prayer}`, `at_time {time}`, `between {from, to}`. Their ID is derived from the kind (`after_fajr`), so shared counts match sessions across goals. A session carries a `target` only, which is its streak amount (47).
- **The streak threshold** gains `{"amount": N}` (29, 36) and `daily_pace` (a total with an end, 28–29). A tracker may now have a streak amount.
- **Make-up:** `{window: off | next_day | within_3_days, fill: streak | target}` (18, 31). Valid for daily (`per_due_date`) goals, and for totals whose streak counts at `{"amount": N}`, filled to N (48). A missed day inside its window is pending and doesn't break the streak (46).
- **Excused days:** a list of dates on every goal.
- **The goal document** (`$defs/goal_document`): `dhikr_id`, `dhikr_snapshot`, `name`, `counts`, `created_on`, `versions` (1–100), `paused`, `excused`, `ended`. Its rule-facing part is `$defs/goal_timeline`, and `$defs/goal` stays what a rule evaluates on one day.
- **Rules evaluate a goal on a day by the version in force that day.**
- **Every "day" is the practice day** (question 12). A total goal with no rhythm uses `every_day` (question 8).
- **Presets** gain Ramadan's first and middle ten (`goal-presets/v1`). White Days and the sacred months were already there (question 10).

**Fixture files** (`awrad-fixture/1`, one rule each):

| File | Rule | Cases |
|---|---|---|
| `goal_version_on_day.json` | Which version applies on a date, and the `goal` it resolves into (an ended goal's end caps it) | 12 |
| `goal_version_add.json` | A detail edit adds a version from today; same-day edits replace it; day sets compare regardless of order; the 100-version fold | 10 |
| `count_attribution.json` | Count-log entries plus goals (shared or dedicated, sessions) → each goal's counts per day and session | 9 |
| `make_up.json` | Counts past a later day's needs fill missed days inside the window, oldest first; each due day's status: met, minimum only, made up, pending, missed, in progress | 26 |
| `excused_days.json` | Whether a day can be excused or un-excused, with the reason | 30 |
| `goal_streak.json` (extended) | Units (days, one weekday, weeks, months, occasions), make-up and days pending it, excused days, amount and pace thresholds, versions, ended goals | 64 |
| `consistency.json` | Kept due days out of the last 30 (or periods out of the last 12) → `devoted`, `steady` or none; no tag before 7 due days (4 periods); whether the row shows 🔥, the tag or nothing | 19 |
| `daily_pace.json` | What's left ÷ due days left, rounded up, for total goals with an end; recalculated per day | 17 |
| `today_ring.json` | What a list ring fills toward today, per requirement | 20 |
| `goal_list_placement.json` | Today (including goals with a day pending make-up), Upcoming (with when), Tracking, Paused or History, and the order in each | 21 |
| `goal_order_merge.json` | Merging a conflicting `goal_order` without asking | 8 |
| `goal_validity.json` (extended) | Sessions XOR minimum/cap, session IDs and windows, an end date XOR a number of days, make-up only on daily goals, pace only on totals with an end; for documents, versions in order and structural fields equal | 43 |
| `goal_is_due.json`, `days_per_period.json` (extended) | Excused days aren't due, and lower an "N days a period" number | 63, 18 |

`npm test` runs every goal-model case through `contracts/tools/goal-rules.mjs`, a reference reading of the README (`tools/check-goal-model.mjs`).

**Count log entry** (shape fixed now, synced in 5): `$defs/count_log_entry`, `{id, dhikr_id, practice_day, session_id, goal_id, amount, counted_at}`. `goal_id` is set only for dedicated goals, `amount` is never 0 and may be negative (adjust, undo), and `id` is a UUIDv7.

**Slice 1 cases whose meaning changed** (the platform runners from slice 1 fail on them until step 5):
- every goal gains `excused` and `make_up`, and sessions gain `kind` and derived IDs (`fajr` became `after_fajr`) and carry a `target` instead of a `count_policy`, in every goal-model file;
- `goal_streak` expects `{current, unit, weekday, pending_make_up}`, and accepts a `goal_timeline`;
- `goal_streak` `ramadan_streak_spans_years` (32 → 1) and `ramadan_streak_broken_last_year` (3 → 0) now count Ramadans;
- `goal_is_due` `end_date_earlier_than_duration` and `duration_earlier_than_end_date` were removed: a goal with both an end date and a number of days is now invalid;
- `goal_validity` accepts `{document}` as well as `{goal}`, with new error codes. `session_streak_minimum_without_minimum` was removed: sessions have no streak threshold any more (47).

## Contract (step 4)

Done 2026-10-31: [`contracts/sync/v1/README.md`](../../contracts/sync/v1/README.md), `sync.schema.json`, `contracts/api/paths/sync.yaml` (bundled).

- **Sync entities** (`sync/v1`):
  - `goal`: the goal document, with a UUIDv7 ID;
  - `goal_order`: `{goal_ids}`, one per account (ID = the account's), merged by the phone rather than conflicted, like `practice_policy`. It can't be deleted.
- **Server rules:**
  - a goal names a built-in dhikr or a custom dhikr of the account (`dhikr_not_found`). One naming a deleted custom dhikr is applied and stored ended (`dhikr_deleted`);
  - the goal rules are `document_invalid`, with a field error per rule;
  - the limits from question 6 (`goal_limit_reached`): 300 goals that haven't ended and 2,000 in all;
  - a `goal_order` keeps only the account's non-deleted goals; repeats are invalid;
  - a goal's `dhikr_id` and `counts` never change: a put changing either is `goal_field_immutable`;
  - goal documents are checked structure first, then goal rules, with `{field, code}` errors pinned by `goal_document_validity.json` (all four platforms);
  - deleting a custom dhikr ends its active and paused goals at the same revision, listed in `cascaded`, on the server's UTC date.
- **Conflicts:** goals use the existing conflict receipt. Phones take the server's goal (or remove it when the server's copy is deleted) and show decision 44's notice (`goal_edit_not_applied`) with a retry, instead of 3b's Keep mine / Use theirs.
- **Phones:** a goal references its custom dhikr, and a goal order its goals, for outbox ordering. Deleting a custom dhikr ends its goals locally without queuing them. Goals count as profile data at the first sign-in.
- **Fixtures:** `goal_document_validity.json` (37 cases), and cases added to `sync_receipts` (21), `apply_changes` (13), `outbox_enqueue` (5) and `profile_switch` (1). `tools/check-sync-contract.mjs` checks the goal rules, the cascade, the goal order rewrite and goal conflicts.
- **No new HTTP operations:** everything goes through `/api/v1/sync/commands` and `/api/v1/sync/changes`, whose schemas and examples now include both entities.
- **ADR:** root `DECISIONS.md` ADR-2026-10-31, "Counts belong to the dhikr; goals choose shared or dedicated".

## Platform work (step 5)

| Project | 4a | 4b | Validation | Status |
|---|---|---|---|---|
| awrad-server-next | Rule runner updates (`Awrad.Goals.Rules`) | Goal entities in sync, cascade, limits | `mix validate` | 4a ☑ · 4b ☐ |
| awrad-android-next | `:core:domain` rules and the fixture runner | `:feature:goals`: sentence, lists, History, edit, stats sheet; local count log | Gradle validation | 4a ☑ · 4b ☐ |
| awrad-ios-next | `AwradDomain` rules and the fixture runner | The same in `AwradKit` | `scripts/validate` | 4a ☑ · 4b ☐ |
| awrad-web-next | TypeScript rules in `src/shared/goals` and the fixture runner | `src/features/goals` | `npm run validate` | 4a ☑ · 4b ☐ |

**4a evidence (2026-10-31).** The phones' sync layer for goals moved into 4a, so the shared sync fixtures pass everywhere: entity types and codecs, outbox ordering, the custom dhikr drop, goal conflicts, goal order merging, and local storage. 4b keeps the screens, the goal repository and ending goals locally when their dhikr is deleted. On the combined branch:
- contracts: 826 goal-model and 413 sync checks;
- server: `mix validate`, 1,128 tests, nothing skipped;
- Android: Gradle validation, 416 unit tests;
- iOS: `scripts/validate`, 460 tests and the app build;
- web: `npm run validate`, 1,244 tests.

Every platform runs all goal-model fixtures and `goal_document_validity`. `goal_order_merge` runs on the phones and the web only (the server never merges).

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| Create a daily goal with a minimum, offline and signed out (en) | ☐ | ☐ | — | |
| Create a weekly and a Ramadan goal with the sentence (ar, RTL) | ☐ | ☐ | ☐ | |
| Edit the target; past days keep their old target in the stats calendar | ☐ | ☐ | ☐ | |
| A structural edit ends the goal into History and starts a new one | ☐ | ☐ | ☐ | |
| End a goal, Start again from History, delete with Undo | ☐ | ☐ | ☐ | |
| Delete a custom dhikr used by goals; they end on every device | ☐ | ☐ | ☐ | |
| Conflicting edits on two devices: the notice and the retry | ☐ | ☐ | — | |
| Empty state: start the Isthighfar goal in one tap, offline | ☐ | ☐ | — | |

## Definition of done

Copied from the playbook and ticked at close.
