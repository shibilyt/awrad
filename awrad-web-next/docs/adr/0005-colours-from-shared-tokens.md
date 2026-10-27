# 0005: Colours generated from the shared colour tokens

Status: Accepted (2026-10-26). Supersedes the colour mechanism in [0003](0003-react-aria-and-tailwind.md) (hand-written `light-dark()` values); the rest of 0003 stands.

## Context

The design system defines Awrad's colours once, for Android, iOS and the web, in `contracts/design-tokens/v1/colors.json`: 15 roles, light and dark, values `#RRGGBB` or `#RRGGBBAA`. The web's hand-copied sage palette had already drifted from it.

## Decision

- `scripts/generate-colors.mjs` turns the JSON into `src/shared/ui/colors.gen.css`, which is committed: a custom property per role, light in `:root`, dark under `@media (prefers-color-scheme: dark)`, values copied as written.
- The same file maps every role into Tailwind's theme (`--color-<role>`) and removes Tailwind's default palette, so roles are the only colour classes.
- `npm run validate` fails when the committed file is stale and when a raw colour (hex, colour function, Tailwind palette class) appears anywhere else.

## Consequences

- Changing a colour means changing the contract; the web follows with `npm run tokens:colors`.
- A colour the roles don't cover (a scrim, a shadow) can't be written in the app; it needs a role in the contract first.
- Dark mode follows the system setting only; there is no in-app theme switch.
