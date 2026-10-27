# 0006: Shapes, spacing, type and motion generated from the shared tokens

Status: Accepted (2026-10-27). Extends [0005](0005-colours-from-shared-tokens.md) from colours to the rest of the design tokens.

## Context

`contracts/design-tokens/v1/` now defines corner radii (`shape.json`), spacing and standard sizes (`spacing.json`), text styles (`typography.json`) and motion (`motion.json`) for Android, iOS and the web, and says screens use tokens by name, never a raw number. The web used Tailwind's own scales (`rounded-xl`, `p-4`, `text-sm`), whose values differ from the tokens, plus a few one-off sizes.

For the web, motion is decided to be fades only: `motion.json`'s durations, easings, `webPage`, `contentSwap` and `reducedMotion`. Springs, slides and scaling are for the native apps.

## Decision

- `scripts/generate-tokens.mjs` turns the four files into `src/shared/ui/tokens.gen.css`, which is committed: a custom property per token, and a Tailwind theme that **replaces** Tailwind's radius, spacing, text-size, line-height, tracking, weight, easing and animation scales. Classes name tokens: `rounded-card`, `p-card-padding`, `gap-row-gap`, `min-h-touch-target`, `text-title`.
  - Spacing stays in px (like dp); text sizes and line heights are in rem, so they follow the browser's text size (like sp).
  - Finite radii add `corner-shape: squircle` under `@supports` (continuous corners where the browser has them); fully rounded shapes stay round.
  - The spacing scale's `none` becomes Tailwind's `0`, because `*-none` clashes with `max-w-none`.
- `npm run validate` fails when the committed file is stale (`check:tokens`), and `check:raw-values` (which replaces `check:raw-colors`) rejects arbitrary values, non-token radius, text, weight and numeric spacing classes, animation classes, and raw durations, easings and lengths in hand-written CSS.
- Motion lives in `src/shared/ui/motion.css`: route changes are a view-transition fade of the page area (`webPage`), `content-swap` fades in swapped content (`contentSwap.fadeIn`), and `prefers-reduced-motion` turns page changes into the `reducedMotion` cross-fade and switches `content-swap` off.

## Consequences

- Changing a radius, space, size, text style or timing means changing the contract; the web follows with `npm run tokens:design`.
- A value the tokens don't cover can't be written in a class. Content widths (`max-w-page`, `max-w-dialog`) are web-only layout and live in `theme.css`; border, outline and stroke widths, z-index and opacity are still numbers.
- Some screens changed where the tokens differ from the old literals (headings 22, body 15, buttons 48 tall, cards 24, dialog 32, page margin 20); ARCHITECTURE.md lists them.
- `contentSwap.fadeOut` isn't used: outgoing content is removed at once, since fading it out would mean keeping removed elements alive.
