# Awrad Design System

The living, **code-accurate** design system for the Awrad Dhikr Goals Tracker. Its job: so nobody —
teammate or Claude — reinvents a token, a color, or a component on the next screen.

## What's here

| File | What it is | When to open it |
|---|---|---|
| [`tokens.md`](tokens.md) | **Source of truth** for color, type, shape, spacing, motion | Building any UI; picking a value |
| [`audit.md`](audit.md) | Health snapshot + prioritized fixes (score 72/100) | Planning cleanup; onboarding |
| [`components/`](components/) | One doc per reusable composable | Reusing or changing a component |
| [`components/_TEMPLATE.md`](components/_TEMPLATE.md) | Blank component doc to copy | Documenting a new component |

### Source-of-truth hierarchy

```
Kotlin code (ui/theme/*, ui/components/*)   ← ground truth, always wins
        │  extracted into
        ▼
tokens.md + components/*.md                 ← this folder, the reviewable mirror
        │  older / aspirational prose
        ▼
docs/style-guide.md                         ← patterns & motion narrative (token tables are STALE — see audit)
```

> `docs/style-guide.md` predates this folder and its color/type/shape numbers have **drifted from
> code** (font, `secondary` color, `small` radius all wrong). Trust `tokens.md` for values; mine
> `style-guide.md` for the richer motion/component *patterns* until they're folded in here.

---

## How to add to it

Three workflows, each backed by the `/design-system` skill. You can run them yourself or just ask
Claude in plain language — the phrasing in **"Ask Claude"** triggers the right one.

### 1. Audit — "where are we?"
Refresh [`audit.md`](audit.md): re-count hardcoded values, re-score, re-list drift.

- **Ask Claude:** _"audit the Awrad design system"_ or `/design-system audit`
- **Do it when:** starting a cleanup pass, before a big feature, or quarterly.

### 2. Document — capture an existing component
Turn a composable that already ships into a `components/<name>.md`.

1. Copy [`components/_TEMPLATE.md`](components/_TEMPLATE.md) → `components/<kebab-name>.md`.
2. Fill each section **from the real code** — cite the source file at the top.
3. Flag gaps you find (missing `contentDescription`, sub-48dp targets) in the Accessibility section.
4. Add a row to the component table in [`audit.md`](audit.md).
- **Ask Claude:** _"document the AwradBottomBar component in the design system"_ or
  `/design-system document AwradBottomBar`
- **Good next targets** (from the audit): the card family (`DhikrCard`/`CategoryCard`/`SuggestedCard`/
  `CircularProgressCard`), then shell primitives (`AwradShell`/`AwradBottomBar`/`AwradPagerTabs`).

### 3. Extend — design something new (or a new token)
Propose a new component/pattern/token **before** writing Compose, so it fits the system.

- **Ask Claude:** _"extend the design system with a spacing scale"_ or
  `/design-system extend <thing>`
- Output is a spec (API, variants, states, tokens used, a11y, open questions). Review it, then
  implement. For tokens, this means a new `object` in `ui/theme/` **and** a `tokens.md` update in the
  same change.
- **First extension the audit is begging for:** the `Spacing.kt` scale in
  [`tokens.md §4`](tokens.md#4-spacing--no-tokens-exist-highest-priority-gap).

---

## The one rule that keeps this honest

**Code and docs change together.** A PR that adds a token, recolors a role, or reshapes a component
must update `tokens.md` / the relevant `components/*.md` in the *same* change. If they drift, the
system is worse than no docs — it lies. The `audit` workflow exists to catch drift when that rule
slips.

## Conventions
- Component docs: `kebab-case.md`, one composable-family per file.
- Always **cite the source `.kt` file** at the top of a component doc.
- Prefer linking a `colorScheme` / `typography` / `shapes` role over quoting a hex/sp/dp literal.
- Keep `tokens.md` tables in sync with the exact values in `ui/theme/` — it cites those files so a
  reviewer can diff in seconds.
