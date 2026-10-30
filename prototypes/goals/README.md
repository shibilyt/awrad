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

## Decisions 34 to 36 (v4)

- No "next goal" card (34): reaching today's target plays an alert only (strong haptic, chime, ring pulse, a banner that fades after about 2.5 s). Lab → Controls has a Sound toggle (on by default) and an event log.
- The circle is anchored to the bottom of the counter (35); the Arabic card and buttons stay at the top and the gap is tap area. Session pills and the make-up line sit just above the circle.
- A tracker can have "streak counts at N a day" (36): ring toward N, the alert at N, then a plain running total. Preset: Data → "Tracker with a daily number".

## Decisions 14 to 30 (v3)

The counter, rows, stats sheet, editing, History, pace, total-goal streaks and trackers follow `docs/slices/04-goals-decisions.md`. The saved state key is now `awrad-goals-proto-v3`, so older saved goals are dropped on first load. Open-ended total goals fill their list ring toward the daily streak amount (any count by default) and show "12,050 of 70,000" on the row (decision 33). Make-up fills a missed day with either enough to keep the streak (default) or the full target, chosen in the sentence flow (decision 31). Defaults: create flow B, green ring with a minimum tick, lower-half tap area.

Presets (Lab → Data, or `proto.preset(name)`):

| Preset | Shows |
|---|---|
| `tags` | Swalath broken with no tag, Fathimiyya "Devoted", Istighfar a 2-day streak with a tag, Nariyya (pace) on 🔥 3 days |
| `calendar` | Fathimiyya with make-up on: every calendar state, 2 excused days used, yesterday missed (count past 100 to fill it) |
| `cap` | Cap of 110 on Fathimiyya, counter at 105 |
| `totalStreak` | Istighfar (no end date) with a streak at 1,000 a day |
| `tracker` | A "whenever I can" tracker on a streak, in the Tracking section |

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
