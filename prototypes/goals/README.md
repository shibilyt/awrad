# Goals prototype

An interactive, high-fidelity wireframe of Awrad's goals feature, for trying UX and UI ideas while goals are designed. Throwaway: nothing here is app code, and the rules in `prototype.js` are a simplified stand-in for the fixture-tested domain code.

## Run it

From the repo root (fonts, icons and the dhikr catalog load from `../../contracts/`):

```sh
python3 -m http.server 5190
```

Then open <http://localhost:5190/prototypes/goals/> in Chromium. Opening `index.html` as a file shows a "styles didn't load" notice instead.

Add `?reset` to the URL to drop the saved state (goals, settings and variants persist in `localStorage`).

## What's in it

- **Phone frame** (390 × 844): Home, My Goals (Active and History), the counting page, the create flow (draft v0) and the goal ⋮ menu, with real navigation.
- **Lab panel** beside the phone:
  - **Controls:** light/dark, LTR/RTL (Arabic), reduced motion, the "today" date (with jumps to the next Thursday, white day and 1 Ramadan), shortcuts to each screen and to the counter at 0, 13, 70, 99, 100 and 110, a haptics log.
  - **Data:** the goals as editable JSON (goal-model shape plus prototype fields).
  - **Variants:** switches generated from `VARIANTS` in `prototype.js`.
  - **Notes:** what's still open, assumed or not designed after decisions 14 to 30. **Data** also has presets that rewrite the seed counts to show a state (below).

## Changing it

| To | Edit |
|---|---|
| Add an A/B switch | An entry in `VARIANTS` (`prototype.js`), then read it with `v('key')` |
| Compare create flows | `VARIANTS.createFlow` (A wizard, B sentence sheet, C templates), or Lab → Controls → Try A / B / C |
| Change a create flow | A: `STEP_DEFS` + `CREATE_STEPS`. C: `TEMPLATES`. Both share `newDraft` → `draftToGoal` |
| Change the sentence flow (B) | Wording per language: `SENTENCE_L10N` (en, ar, ml templates with slots). Draft and conversion: `sdNew`, `sdToGoal`, `sdFromGoal`, `sdErrors`. Pickers: `sdPicker`. Examples: `SD_EXAMPLES`. Console: `proto.sentence(i)` opens example `i` |
| Sessions on the counter | `sessionPills`, `currentSessionId`, `PRAYER_TIMES`; the Lab's "Time of day" picks the current session |
| Change chip or streak copy | `STRINGS` (`chip_*`, `streak_unit`) and `chipText()` |
| Change the seed goals | `seedGoals()` |
| Change a token | Don't, here: tokens are copied from `contracts/design-tokens/v1/` into the top of `prototype.css` |

From the browser console, `proto` exposes the state and helpers: `proto.count(99)`, `proto.set({ theme: "dark" })`, `proto.variant("ringStyle", "green")`, `proto.jump("create")`.

## Decisions 18, 34 and 41 to 44 (v6)

- Spelling (41): "Isthighfar" everywhere in the UI, the empty-state suggestion included. The dhikr picker searches the catalog's aliases, so "Isthighfar" and "Astaghfirullah" still find it.
- Gentle note (42): the sentence flow's preview shows "That's N goals a day. Small and steady is beloved: consider starting with fewer." when saving would make more than 7 daily goals (`GENTLE_DAILY_LIMIT`, `gentleNoteHTML`). Saving is never blocked. The wording is `[needs source]` (Lab notes). Preset: Data → "7 daily goals".
- Streak units (43): `streakOf` returns a unit per rhythm: days, a weekday ("12 Fridays"), weeks, months, or an occasion ("2 Ramadans", else "times"). "N days a week" rows add "· 2 of 3 days this week"; an excused day lowers that week's number (`daysNeeded`). Strings: `streak_unit` in `V6_STRINGS`. Presets: Data → "Weekly streak", "Friday streak".
- Conflict (44): Lab → Controls → Sync → "Simulate a conflict" shows the notice with "Pause again" and "Dismiss" (`showConflictNotice`).
- Make-up (18): turning it on defaults to "within 3 days".
- Settings (34): Home → the tune icon opens Settings with app-wide "Goal sound" and "Vibration" (both on by default). Vibration off silences `navigator.vibrate` (`haptic`); sound off silences the chime (`chime`). The Lab's Sound toggle moved here.

## Decisions 37 to 40 and number grouping (v5)

- Counter hint: "Tap anywhere to count" (the circle is at the bottom now); "Tap the circle to count" in circle-only mode. Numbers are grouped by locale everywhere ("12,667"), with Western digits in Arabic and Malayalam as before. The "Big numbers" variant is gone.
- Adjust count (38): ⋮ → "Adjust count", or a 500 ms long press on the counter number (it doesn't count a tap). A sheet with a number field, − / +, Today / Yesterday and a save button; no going below 0 (inline reason), additions stop at the cap, shared goals are named ("Also changes ..."), and additions past the target fill the make-up day first. Code: `adjustModel`, `openAdjust`, `saveAdjust`, the long press in `boot`.
- Undo and Reset (39): Undo removes only this counter session's own taps (`tapLog`), with no warning, and is disabled in ⋮ when there are none. "Reset today" always confirms and names the other goals it changes with the change (`openResetDialog`).
- Deleting a custom dhikr (37): Library → "Your dhikrs" → trash button → warning with the number of goals that end → goals move to History as Ended and keep their name and Arabic text from `dhikr_snapshot` (`openDhikrDeleteDialog`, `deleteDhikr`, `ensureSnapshots`). Deleted dhikrs persist in the saved state; "Reset goals to the seed" restores them.
- Empty state (40): no active goals shows the Isthighfar suggestion on Home and in My Goals (`suggestionHTML`). Start this goal saves at once; Choose another goal opens a blank sentence. Preset: Data → "No goals". The virtue line is a placeholder marked `[needs source]` in the Lab notes.

## Decisions 34 to 36 (v4)

- No "next goal" card (34): reaching today's target plays an alert only (strong haptic, chime, ring pulse, a banner that fades after about 2.5 s). Settings has a Goal sound switch (on by default); Lab → Controls has an event log.
- The circle is anchored to the bottom of the counter (35); the Arabic card and buttons stay at the top and the gap is tap area. Session pills and the make-up line sit just above the circle.
- A tracker can have "streak counts at N a day" (36): ring toward N, the alert at N, then a plain running total. Preset: Data → "Tracker with a daily number".

## Decisions 14 to 30 (v3)

The counter, rows, stats sheet, editing, History, pace, total-goal streaks and trackers follow `docs/slices/04-goals-decisions.md`. The saved state key is now `awrad-goals-proto-v3`, so older saved goals are dropped on first load. Open-ended total goals fill their list ring toward the daily streak amount (any count by default) and show "12,050 of 70,000" on the row (decision 33). Make-up fills a missed day with either enough to keep the streak (default) or the full target, chosen in the sentence flow (decision 31). Defaults: create flow B, green ring with a minimum tick, lower-half tap area.

Presets (Lab → Data, or `proto.preset(name)`):

| Preset | Shows |
|---|---|
| `tags` | Swalath broken with no tag, Fathimiyya "Devoted", Isthighfar a 2-day streak with a tag, Nariyya (pace) on 🔥 3 days |
| `calendar` | Fathimiyya with make-up on: every calendar state, 2 excused days used, yesterday missed (count past 100 to fill it) |
| `cap` | Cap of 110 on Fathimiyya, counter at 105 |
| `totalStreak` | Isthighfar (no end date) with a streak at 1,000 a day |
| `tracker` | A "whenever I can" tracker on a streak, in the Tracking section |
| `weeklyStreak` | Swalath "3 days a week" on 5 weeks, 2 of 3 days this week |
| `fridayStreak` | Surah Ikhlas every Friday on 12 Fridays |
| `sevenDaily` | 7 daily goals: a new daily goal in the sentence flow shows the gentle note |
| `noGoals` | No goals at all: the Isthighfar suggestion on Home and My Goals |

Console: `proto.open(dhikr)`, `proto.tap(n)`, `proto.stats()`, `proto.edit(goalId)`.

| To | Edit |
|---|---|
| Day states, streak, best, consistency, tags | `dayState`, `streakOf`, `bestStreakOf`, `consistencyOf`, `streakHTML` |
| Pace and the daily streak number | `paceOf`, `dayThreshold`, `dailyAmount`, `counterModel` |
| Make-up, late counting | `makeupInfo`, `increment`, `countDay` |
| Edit as dated versions, structural edits | `snapAt`, `isStructural`, `saveDraft` |
| Counter's moments (goal-done alert, cap, haptics) | `increment`, `counterView`, `goalDoneAlert`, `chime`, `showGoalBanner`, `haptic` |
| Counter layout (circle at the bottom) | `screens.counting`, `.counter-zone` in `prototype.css` |
| Tracker with a daily number | `counterModel` (tracker branch), `dayThreshold`, the `trackerNumber` preset |
