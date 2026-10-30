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
  - **Notes:** open questions, assumptions and design gaps, including the gold ring token question.

## Changing it

| To | Edit |
|---|---|
| Add an A/B switch | An entry in `VARIANTS` (`prototype.js`), then read it with `v('key')` |
| Change the create flow | `STEP_DEFS` (each step's title, body and validity) and `CREATE_STEPS` (the order) |
| Change chip or streak copy | `STRINGS` (`chip_*`, `streak_unit`) and `chipText()` |
| Change the seed goals | `seedGoals()` |
| Change a token | Don't, here: tokens are copied from `contracts/design-tokens/v1/` into the top of `prototype.css` |

From the browser console, `proto` exposes the state and helpers: `proto.count(99)`, `proto.set({ theme: "dark" })`, `proto.variant("ringStyle", "green")`, `proto.jump("create")`.
