# 0003: React Aria Components with Tailwind design tokens

Status: Accepted (2026-10-21)

## Context

Awrad ships in English, Arabic (right to left) and Malayalam, and must be fully usable by keyboard and screen reader. The alternatives considered were shadcn/ui (Radix with Tailwind) and hand-written components with CSS modules.

## Decision

- Interactive widgets use **React Aria Components**: focus, keyboard, press, screen-reader semantics and RTL are built in.
- Styling uses **Tailwind 4**, with Awrad's palette as CSS-variable tokens (`--color-primary`, …) that switch for light and dark via `light-dark()`.
- Components use token classes, never raw colours.

## Consequences

- Accessibility and RTL behaviour come from a well-tested library instead of hand-written code.
- The look is Awrad's own, not a stock component theme.
- React Aria accounts for much of the scaffold's initial bundle size (about 140 KB gzipped in total). Watch the size per route as features land.
