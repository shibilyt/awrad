# 0007: Key components, colour cross-fades and a dev-only gallery

Status: Accepted (2026-10-27). Extends [0006](0006-shape-spacing-type-motion-from-shared-tokens.md), whose "fades only, no other animation" it widens to colour cross-fades; everything else in 0006 stands.

## Context

`contracts/design-system/v1/components.md` specifies the shared containers, buttons, inputs and navigation, and the tokens they need (elevation, component sizes and shapes, `largeTitle`, the `select` and `segmentIndicator` motions). It asks every app for a debug-only component gallery in light and dark, LTR and RTL. On the web, ADR 0006 allowed page and content fades only, while the spec's state changes (option rows, checkboxes, switches, pills, the bottom bar's pill) are colour changes, and its overlays (dialog, bottom sheet) need to appear somehow.

## Decision

- **Components** live in `src/shared/ui/`, on React Aria where it gives the behaviour (radio and checkbox groups, switch, tabs, modal dialogs, progress bar), styled only with token classes. ARCHITECTURE.md lists them.
- **Motion stays fades, plus colour cross-fades.** `select-fade` (motion.css) transitions colours and opacity over `select.colorDuration` with `select.easing`, the only `transition` in the app. Nothing moves: the segmented pill's fill and bar, the bottom bar's pill and the switch thumb cross-fade in place instead of sliding (the switch has an off thumb and an on thumb that swap opacity). Dialogs and the bottom sheet fade in and out (`overlay-fade`, `contentSwap.fadeIn` / `fadeOut`); the sheet doesn't slide up. A pending button shows three dots that fade in turn, not a spinner. `prefers-reduced-motion` switches to the `reducedMotion` timing, or no animation for the dots.
- **Press** stays an opacity change (`data-pressed:opacity-90`), not the mobile `press` scale.
- **Elevation** is generated: `shadow-floating`, in the `shadow` colour role (transparent in dark), is the only shadow class; `check:raw-values` rejects Tailwind's others and raw `box-shadow` lengths.
- **Secondary fills on a card.** Light `secondaryContainer` is the `surface` colour, so a secondary button, an unselected option row or pill on a `surface` card would vanish. There they fill with `background` and `onSurface`, as fields already do (`useSecondaryFill`). Dialogs and sheets (`surfaceBar`) count as the page.
- **The token generators fail on keys they don't know** (`scripts/token-keys.mjs`), so a new token can't be silently skipped.
- **Gallery:** `/dev/components`, rendered by `main.tsx` only under `import.meta.env.DEV`, outside the router. Production builds drop the branch, so the gallery's code and sample strings aren't in `dist`. Its sample text is an i18n namespace of its own (`src/dev/gallery/locales`), checked by `check:translations`; dependency-cruiser lets only `main.tsx` import `src/dev`. The light/dark toggle sets `data-color-scheme` on `<html>`, which `colors.gen.css` turns into one scheme's roles for that subtree; the RTL toggle switches the UI to Arabic.

## Consequences

- Option rows, checkboxes, switches, pills and the bottom bar animate their colours over 150 ms; the rest of 0006's rules (no movement, scaling or springs) are unchanged.
- The account screens use the new buttons, cards, dialog and top bar: secondary buttons are now `secondaryContainer`, the delete button an `error` fill, and the dialog's actions sit at its end on `surfaceBar`.
- `data-color-scheme` is available to the app, but screens still never choose or check the scheme.
