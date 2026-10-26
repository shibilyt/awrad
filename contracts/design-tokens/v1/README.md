# Design tokens v1: colours

The colour roles Android, iOS and web use, light and dark (design system, decided 2026-10-26). Each app's theme is checked against `colors.json`, so the three can't drift.

- **Palette:** only the colours in `palette`. That's the design's eight, plus white and black, plus one error red per theme. `npm test` rejects any role value outside it.
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
| `outline` | Decorative dividers | `#E8EDE9` | `#313B34` |
| `outlineStrong` | Borders of controls (fields, outlined buttons) | `#000000` at 50% | `#E3E5E3` at 50% |
| `primary` | Brand fills: main buttons, arrow buttons | `#23553C` | `#23553C` |
| `onPrimary` | On primary | `#FFFFFF` | `#FFFFFF` |
| `primaryContainer` | Selected fill: selected tab pill, chips | `#B7D6B6` | `#23553C` |
| `onPrimaryContainer` | On primaryContainer | `#000000` | `#B7D6B6` |
| `accent` | Accent text and icons: streaks, links, selected tab label | `#23553C` | `#B7D6B6` |
| `progress` | Progress rings and bars | `#23553C` | `#E3E5E3` |
| `error` | Errors and destructive actions | `#B3261E` | `#F2B8B5` |
| `onError` | On an error fill | `#FFFFFF` | `#000000` |

Rules for screens:
- **Pick by role, never by hex or by checking the theme.**
- **`#23553C` is never text on a dark background.** It reads at only 2.2 : 1 there. Dark-mode accent text is `accent`, the pale green.
- **Surfaces stack as `background` → `surface`.** In dark mode a surface is darker than the background (black on `#121412`), as in the design.
