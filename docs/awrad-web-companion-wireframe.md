# Awrad Web Companion — wireframe direction

Status: first-pass structural wireframe. This is a design artifact, not production UI code.

[Open the visual wireframe](awrad-web-companion-wireframe.html)

## Design brief

- **Primary user:** an existing Awrad user who wants to continue a private dhikr practice on the web, with a familiar mobile-like flow at every viewport.
- **Primary outcome:** open Awrad, understand what is due today, and complete the next count with confidence that it was saved canonically.
- **Secondary outcomes:** inspect goals, browse the dhikr library, and read a dhikr detail page without editing mobile-owned data.
- **Brand signal:** calm, devotional, precise, and contemporary; generous whitespace with a small amount of sage and gold emphasis.
- **Constraints:** authenticated Phoenix LiveView, English UI first, Arabic content must remain legible and RTL-ready, web is read-only for goals/library, count writes go through `WebSync` only.
- **Success metrics:** the next due goal is obvious within five seconds; a user can reach counting in one click from Today; saved/pending/retry state is always visible; keyboard and narrow layouts preserve the same primary action.

## Direction in one sentence

Make the web companion feel like the mobile app opened on a larger surface: one vertical practice feed, one obvious next action, persistent bottom navigation, and supporting detail that never competes with the count.

The responsive rule is **mobile UI first, extra space second**. At larger widths we center and widen the same reading column rather than turning the product into a dense desktop dashboard. A desktop rail is optional context; the primary interaction remains the mobile-like feed and bottom dock.

## Mobbin references and what we are borrowing

These are pattern references, not visual copies:

- [Charma — goals workspace](https://mobbin.com/screens/e8c9b013-b6d2-4357-bc0c-636342fd3bdd): persistent left navigation, clear page title, filter controls, and a scan-friendly list.
- [Frame — goal workspace](https://mobbin.com/screens/c532ad61-5838-47e1-904c-ff98207613ce): lightweight workspace rail and compact progress cards.
- [Arcade — library](https://mobbin.com/screens/02beed61-a42e-462c-a824-b61b0a9ce46c): search/filter toolbar and content-first card grid.
- [Uxcel — tutorials library](https://mobbin.com/screens/936f6232-9259-4780-aae4-0a3b3829d8a6): editorial card rhythm, category chips, and readable metadata.
- [MagicPath — habit dashboard](https://mobbin.com/screens/294d6dbf-ef02-42a2-9fb3-bc577a201fe0): a strong separation between today’s checklist, detail, and progress dashboards.
- [Duolingo — practice](https://mobbin.com/screens/6a2c3f44-35cc-4f84-b1f3-af2a7622c8bb): focus-first practice area with a single dominant action and secondary progress context.
- [Open — daily practice](https://mobbin.com/screens/2a3377af-dddb-4fc7-a9c7-21ff72fad3bc): calm focus mode with the practice title and progress as the visual center.

For the mobile-first pivot:

- [Finch — today routine](https://mobbin.com/screens/cb1439cb-ae56-488b-b945-5a1e6a1074ca): a friendly today feed, progress cue, and persistent bottom navigation.
- [Me+ — routine list](https://mobbin.com/screens/be193477-7417-4785-aa1b-3912902f4c8f): date context followed by stacked, scannable practice cards.
- [Alan — filtered content list](https://mobbin.com/screens/b6b5de09-67b9-4722-84a3-8710432d409a): filter chips and a focused list that keeps the content readable.
- [Apple Books — reading goal](https://mobbin.com/screens/7a549e63-8f9e-4a3e-80d4-af4727b701dd): a single progress arc and one clear “continue” action.

## Information architecture

```text
Awrad
├── Today                 /home
│   ├── Due today
│   ├── Recent practice
│   └── Count             /count/:goal_id
├── Goals                 /goals
│   ├── Active
│   ├── Completed
│   └── All goals
├── Library               /library
│   └── Dhikr detail      /library/:dhikr_id
└── Account               /users/settings
```

Global navigation is three items in the mobile mental model: Today, Goals, and Library. A compact rail may appear on wide screens as orientation, but the bottom dock and the three-item hierarchy remain the source of truth. Count is a contextual destination, not a fourth primary navigation item.

## Key user paths

### 1. Today → count → saved

```text
Today
  → choose the first due card
  → Count screen opens with the correct goal and slot
  → press +1, Space, or Enter
  → provisional count appears immediately
  → canonical receipt replaces it
  → “Saved to your account” remains visible
```

### 2. Goals → inspect a commitment

```text
Goals
  → Active / Completed / All goals filter
  → scan progress, schedule, and web support status
  → open Count only when an active anytime slot is supported
```

### 3. Library → dhikr detail

```text
Library
  → search Arabic, transliteration, or translation
  → filter by category
  → open a dhikr card
  → read Arabic, transliteration, translation, and audio availability
```

## Responsive skeleton

| Viewport | Shell | Main content | Priority changes |
| --- | --- | --- | --- |
| Narrow, 320–767px | Full-width mobile canvas + persistent bottom dock | One vertical feed, 16px gutters | Put the next due goal first; keep count and saved state above the fold. |
| Tablet, 768–1199px | Centered mobile-like canvas, optional compact context rail | 560–680px reading column | Preserve mobile card rhythm; use spare width for breathing room, not extra density. |
| Desktop, 1200px+ | Centered app canvas with optional rail | 640–760px primary column | Keep the feed and bottom dock visually primary; secondary metrics can sit in the margins. |

### Mobile-first interaction rules

- The bottom dock owns **Today**, **Goals**, and **Library** at every breakpoint. On wide screens it may become a centered floating dock or a compact dock under the primary column; it should not disappear from the mental model.
- Count opens as a focused surface with a clear back affordance. It does not add a permanent fourth tab.
- A page has one dominant action. Today uses “Continue practice”; Count uses “Add one”; Library uses search.
- Use compact, rounded cards with generous vertical rhythm. Avoid desktop tables as the default mental model; a wide list can progressively reveal metadata.
- Keep sync status close to the action that changes data. A toast alone is insufficient for pending or retry states.

## Page wireframes

### Today

1. Compact top bar: menu/account, browser-local date, and sync status.
2. Intro: “Today” and a short date line; avoid a generic desktop dashboard greeting.
3. One summary card with total counted, current streak, and “Continue practice”.
4. Stacked due-goal feed: Arabic, translation, progress, slot label, and count affordance.
5. Supporting stats follow the queue; they never push the next practice below the fold.

The first row is always the strongest visual item. Cards should be scannable without hiding the title behind a menu.

### Goals

1. Page intro plus a three-state filter segmented control.
2. A compact summary strip: active, completed, and due today.
3. Stacked cards on narrow screens; the same card rhythm can widen on larger screens without becoming a data-heavy table.
4. Each goal row contains title, Arabic preview, target, today’s progress, recurrence/slot, and a clear web support badge.
5. The read-only note sits below the data, not above it.

### Library

1. Search is the first control and remains visible while browsing.
2. Category filters are chips on narrow screens and a select/toolbar on desktop.
3. Featured “return to” card can highlight a frequently practiced dhikr without inventing a new data model.
4. Card grid: Arabic first, then transliteration and translation; audio is a small secondary control.
5. Empty search state explains what fields are searched and offers a clear reset.

### Dhikr detail

1. Back link and category label.
2. Large Arabic reading block with `dir="rtl"` and `lang="ar"`.
3. Transliteration and translation grouped as interpretation, not competing headings.
4. Audio preview row when available; explicit unavailable state when not.
5. “Used in your goals” context is optional and read-only.

### Count

1. Back to goals plus a small sync status pill.
2. Every viewport keeps the same sequence: goal context → dominant count action → progress → slot/status. Wider layouts may place supporting context beside the sequence, but never split attention across competing panels.
3. Narrow: the sequence becomes a full-height mobile-like surface with the count action comfortably reachable.
4. The count button supports click, Space, and Enter. The button is the only high-emphasis action.
5. Pending, saved, retry, and blocked states are announced in a persistent live region.

## Component inventory

| Component | Used on | Purpose | Important states |
| --- | --- | --- | --- |
| `AppRail` / `BottomNav` | all authenticated pages | Make location and next destination obvious | active, keyboard focus, narrow/tablet variants |
| `ContextBar` | Today, Count | Browser date, account, and sync visibility | saved, syncing, disconnected |
| `PageIntro` | Today, Goals, Library, Detail | Establish page purpose and hierarchy | default, compact |
| `MetricStrip` | Today, Goals | Summarize the current practice without charts | populated, zero, loading |
| `PracticeQueue` | Today | Prioritize the next due goal | active, completed, disabled, empty |
| `GoalRow` | Today, Goals | Show canonical progress and web support | active, completed, unsupported, stale |
| `LibraryToolbar` | Library | Search and category filtering | typing, filtered, no results |
| `DhikrCard` | Library | Preview Arabic-safe content | audio available/unavailable |
| `CountStage` | Count | Put the count action at the center | ready, saving, saved, retry, blocked |
| `SlotSelector` | Count | Choose among supported active anytime slots | selected, unsupported, unavailable |
| `SyncStatus` | Today, Count | Explain client/server state | saved, pending, retry, offline |
| `EmptyState` | all pages | Explain why the page is empty and what to do next | no goals, no matches, clear practice |

## Draft design tokens

These extend the existing Awrad palette without changing the production theme yet.

```css
:root {
  --wire-paper: #f7f8f5;
  --wire-surface: #ffffff;
  --wire-surface-soft: #eef2ed;
  --wire-ink: #1a1c1a;
  --wire-muted: #6f776f;
  --wire-line: #dce2dc;
  --wire-sage: #4b7c5a;
  --wire-sage-dark: #2e5c3d;
  --wire-sage-soft: #d4e8da;
  --wire-gold: #d4a843;
  --wire-gold-soft: #fff0d4;
  --wire-focus: #2d6cdf;

  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 24px;
  --space-6: 32px;
  --space-7: 48px;
  --space-8: 64px;

  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --radius-xl: 24px;
  --shadow-card: 0 8px 24px rgb(26 28 26 / 6%);
  --shadow-stage: 0 24px 60px rgb(26 28 26 / 12%);
}
```

Rules:

- Use sage for the current route, primary count action, and saved confirmation—not for every link.
- Use gold for streak or “keep going” signals, never for destructive or blocked actions.
- Prefer surface changes and whitespace over card borders. Borders are for grouping or keyboard visibility.
- Use the existing UI sans for controls and a restrained serif only for large editorial headings.
- Arabic content uses a script-capable stack such as `Noto Naskh Arabic`, `Amiri`, `Geeza Pro`, serif; never force Latin letter-spacing or truncation onto it.

## States and edge cases

- **Initial load:** preserve the page skeleton and announce when canonical data arrives.
- **Empty account:** explain that goals are created in the mobile app and link to the library.
- **No due goals:** celebrate a clear practice queue; do not show a dead-end blank panel.
- **Pending save:** show provisional progress, disable duplicate input, and announce “Saving your count…”.
- **Retry:** keep the user on the count page, preserve intent, and offer a clear retry affordance.
- **Disconnected socket:** keep navigation available, label the count as unsaved, and avoid implying canonical success.
- **Concurrent mobile change:** after refresh, re-query and show the canonical total with a concise “Updated from mobile” signal.
- **Unsupported slot:** show the reason inline; never present a disabled count button without explanation.
- **Long Arabic / translation:** allow wrapping, protect line height, and keep the count action reachable.
- **Browser midnight rollover:** refresh the date context and reset daily projections without requiring a full reload.
- **Reduced motion:** disable count pulse and transitions while preserving the state change and live announcement.

## Implementation notes for the next pass

- Keep the existing `Layouts.app` shell as the ownership boundary; evolve its rail and bottom navigation after the wireframe is approved.
- Keep `Practice` as the read-model boundary and `PracticeComponents` as the view-map rendering layer.
- Keep `WebSync.increment/3` as the only browser write boundary; the visual “saved” state must map to its canonical receipt.
- Use semantic landmarks (`aside`, `nav`, `main`, `section`) and real buttons/links rather than clickable containers.
- Preserve `aria-live="polite"` for count status and `aria-keyshortcuts="Space Enter"` on the count action.
- The wireframe intentionally does not introduce goal editing, community, dark mode, browser outbox, or a new API contract.

## Review checklist

- [ ] Five-second glance identifies Today, the next practice, and the primary action.
- [ ] Desktop and tablet preserve the same hierarchy without relying on hover.
- [ ] Narrow view keeps count and save state above the fold.
- [ ] Arabic remains readable at 200% zoom and with mixed-direction text.
- [ ] Every interactive element has a visible keyboard focus state.
- [ ] Pending, saved, retry, blocked, empty, and disconnected states are represented before production polish.
