# Design tokens v1

The design system's single source for Android, iOS and web: colours, fonts, shapes, spacing, type and motion. Each app generates its code from these files, and its build fails on drift. **Screens use tokens by name, never a raw number or colour.** To change the look or feel of the app, edit these files and regenerate.

| File | What |
|---|---|
| `colors.json` | Colour roles, light and dark (below) |
| `fonts/` | Font files, checksums, licences (`fonts/README.md`) |
| `shape.json` | Corner radii: a scale and named roles |
| `spacing.json` | Spacing scale, named roles, standard sizes |
| `typography.json` | Named text styles |
| `motion.json` | Easings, durations, springs, haptics, named motions, reduced motion |

## Colours

The colour roles Android, iOS and web use, light and dark (design system, decided 2026-10-26). Each app's theme is checked against `colors.json`, so the three can't drift.

- **Palette:** only the colours in `palette`. That's the design's eight, plus white and black (also used translucent), plus one error red per theme. `npm test` rejects any role value outside it.
- **Contrast:** `npm test` checks every pair in `contrast` in both themes. Translucent colours are composited over their background first.
  - Text needs 4.5 : 1.
  - Control borders and progress indicators need 3 : 1.

| Role | Use | Light | Dark |
|---|---|---|---|
| `background` | Screen background | `#FFFFFF` | `#121412` |
| `surface` | Cards and grouped content | `#E8EDE9` | `#000000` |
| `surfaceBar` | Bottom navigation, sheets, bars | `#F9FBFA` | `#313B34` |
| `onSurface` | Main text and icons | `#000000` | `#E3E5E3` |
| `onSurfaceVariant` | Secondary text | `#000000` at 65% | `#E3E5E3` at 65% |
| `outline` | Progress-ring and bar tracks | `#000000` at 10% | `#313B34` |
| `outlineStrong` | The few controls invisible without a line (a checkbox's box) | `#000000` at 50% | `#E3E5E3` at 50% |
| `primary` | Brand fills: main buttons, arrow buttons | `#23553C` | `#23553C` |
| `onPrimary` | On primary | `#FFFFFF` | `#FFFFFF` |
| `primaryContainer` | Selected fill: selected tab pill, chips | `#B7D6B6` | `#23553C` |
| `onPrimaryContainer` | On primaryContainer | `#000000` | `#B7D6B6` |
| `accent` | Accent text and icons: streaks, links, selected tab label | `#23553C` | `#B7D6B6` |
| `progress` | Progress rings and bars | `#23553C` | `#E3E5E3` |
| `error` | Errors and destructive actions | `#B3261E` | `#F2B8B5` |
| `onError` | On an error fill | `#FFFFFF` | `#000000` |
| `scrim` | Dimmed backdrop behind dialogs and sheets | `#000000` at 40% | `#000000` at 40% |

Rules for screens:
- **Pick by role, never by hex or by checking the theme.**
- **Headings and titles use `onSurface`,** as in the design. Green is for accents (links, streaks, the selected tab) and fills.
- **No outlines by default.** The design is built from filled shapes, not lines. A line appears only where it's required:
  - **Keyboard focus on the web:** a ring in `accent`. Accessibility requires a visible focus indicator.
  - **A checkbox's (or radio's) box:** `outlineStrong`. An unticked box is invisible otherwise.
  - **A field in error:** an `error` border, always with the error message.
- **Text fields are filled, never outlined:**
  - The fill is `surface` on a `background`, or `background` on a `surface` card.
  - On mobile, focus is shown by the cursor and keyboard only.
- **Secondary buttons and unselected pills are filled** like fields. A selected pill or chip is `primaryContainer`.
- **Rows inside a card are separated by spacing,** not divider lines.
- **The app icon artwork is exempt** (Android launcher background `#D5FFDC`) until the icon is redesigned.
- **`#23553C` is never text on a dark background.** It reads at only 2.2 : 1 there. Dark-mode accent text is `accent`, the pale green.
- **Surfaces stack as `background` → `surface`.** In dark mode a surface is darker than the background (black on `#121412`), as in the design.

## Shapes (`shape.json`)

- **The scale:** 8, 12, 16, 20, 24, 28, 32, and fully rounded.
- **Roles:**
  - `card` 24;
  - `tile`, `button` and `field` 16;
  - `chip`, `roundButton` and `navPill` fully rounded;
  - `navBar` 28;
  - `sheet`, `dialog` and `screenDepth` 32.
- **Corners are continuous** (squircle) where the platform makes it cheap:
  - iOS uses `.continuous`;
  - Android uses a small in-house smooth-corner shape;
  - the web uses `corner-shape: squircle` where supported, and plain rounding elsewhere.

## Spacing (`spacing.json`)

- **The scale:** 2, 4, 8, 12, 16, 20, 24, 32, 40, 48.
- **Roles:**
  - `pageMargin` 20;
  - `sectionGap` 20;
  - `cardPadding` 16;
  - `rowGap` 12;
  - `inlineGap` 8.
- **Sizes:**
  - `touchTarget` 48;
  - `listRow` 56;
  - icons 24 and 20;
  - the small ring 36, with stroke 4.

## Type (`typography.json`)

- Named styles from `title` (22) to `navLabel` (11), plus `counter` (56, with tabular digits).
- iOS scales every style with Dynamic Type, relative to its `iosTextStyle`.

## Motion (`motion.json`)

Building blocks:
- **Easings:**
  - `emphasized` (0.2, 0, 0, 1);
  - `decelerate` for things entering;
  - `accelerate` for things leaving.
- **Durations:**
  - `fade` 100;
  - `color` 150;
  - `short` 250;
  - `medium` 300;
  - `page` 350;
  - `long` 450.
- **Springs** (dampingRatio, stiffness, mass 1):
  - `spatial` (0.8, 380) for anything that moves;
  - `spatialFast` (0.6, 800) and `spatialSlow` (0.8, 200);
  - `effects` (1.0, 1600) for colour and opacity, which never bounces;
  - `bouncy` (0.5, 1500) for small pops;
  - `bouncySoft` (0.5, 200) for soft entrances.
- **Spring conversion:**
  - iOS: `response = 2π / √stiffness`, `dampingFraction = dampingRatio`.
  - Web, where springs are needed: `damping = 2·dampingRatio·√stiffness`.
- **Haptics:**
  - `tick` for a count, a tab or a step;
  - `threshold` for crossing a release point;
  - `success` for reaching a target.

Named motions (`motions`) say which platforms use them:
- **Page transitions on Android:** `pagePush` / `pagePop` (scale and fade); `screenDepth` makes the page behind round to 32 and dim to 0.34.
- **Page transitions on iOS:** the native push.
- **Tabs:** `tabSwitch`.
- **Navigation pill:** `navPill`.
- **Touch feedback:** `press`.
- **Counting:**
  - `countTap`: a light tick, the number rolls, and a 1.04 pop;
  - `countComplete`;
  - `ringFill`.
- **Sheets:** `sheet` (follows the finger, settles with the fling speed, corners go to 0 at full height).
- **Expanding sections:** `expand`.
- **Lists:** `listAppear`.
- **Swapping text in place:** `contentSwap`.
- **Web:** `webPage`, a fade only.

**Reduced motion:** when the system asks for it, every movement, scale and spring becomes a 150 ms cross-fade. Haptics stay. The web follows `prefers-reduced-motion`.

The motion values combine three sources:
- **The frozen Android app's motion:** page transitions, the screen-depth corners, the nav pill and press feedback.
- **Material 3 Expressive spring values,** which PixelPlayer also uses. Its code is proprietary, so only numbers and ideas are reused, never code.
- **A unified timing,** replacing the frozen apps' 16 different durations.
