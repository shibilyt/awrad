# awrad-web-next — agent instructions

Applies inside `awrad-web-next/` and extends [`../AGENTS.md`](../AGENTS.md). Read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`docs/adr/`](docs/adr/README.md) first.

## Rules the build enforces (`npm run validate`)

- **API types:** `src/shared/api/schema.gen.ts` matches `contracts/api/openapi.bundled.json`. Regenerate with `npm run api:types`.
- **Colours:** `src/shared/ui/colors.gen.css` matches `contracts/design-tokens/v1/colors.json` (regenerate with `npm run tokens:colors`), and no hex colour, colour function or Tailwind palette class appears anywhere else. Its `states` (disabled) become `opacity-disabled`, the only disabled style.
- **Shapes, spacing, type, motion:** `src/shared/ui/tokens.gen.css` matches `contracts/design-tokens/v1/{shape,spacing,typography,motion}.json` (regenerate with `npm run tokens:design`). Classes name tokens (`rounded-card`, `p-card-padding`, `gap-row-gap`, `min-h-control`, `max-w-content`, `border-checkbox`, `outline-focus-ring`, `text-title`); `check:raw-values` rejects arbitrary values (`p-[13px]`), `text-sm`, `rounded`, numeric spacing (`p-4`, `h-12`), unknown max widths, border/outline/ring widths (`border-2`), shadows other than `shadow-floating`, numeric disabled opacity, `leading-*`, animation classes, and raw durations, easings, line widths and lengths in hand-written CSS.
- **Icons:** `src/shared/ui/icons.gen.tsx` matches `contracts/design-tokens/v1/icons.json` and its SVGs (regenerate with `npm run icons`); use its components (`BackIcon`, `AddIcon`, …), never a hand-drawn SVG or an icon library.
- **Dhikr catalog:** `src/shared/dhikr-catalog/catalog.gen.ts` matches `contracts/dhikr-catalog/v1/catalog.json` (regenerate with `npm run catalog`; it fails on keys `types.ts` doesn't know). Only `load.ts` imports it, lazily; read it with `useCatalog()`.
- **Fonts:** every file in `public/fonts/` is byte-identical to `contracts/design-tokens/v1/fonts/` (checked against its `SHA256SUMS`). Copy fonts from there; never edit them here.
- **TypeScript:** maximum strictness (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, …).
- **ESLint** with zero warnings allowed:
  - typescript-eslint strict and stylistic type-checked rules;
  - React Hooks and React Compiler rules;
  - jsx-a11y strict;
  - **no hard-coded UI text** (`i18next/no-literal-string`);
  - no direct `fetch`;
  - no `crypto.randomUUID`: new IDs come from `newUuidV7()` in `src/shared/identity` (UUIDv7);
  - 400-line files.
- **Prettier** formatting.
- **Module rules** (dependency-cruiser):
  - features never import each other;
  - `shared` never imports features or routes;
  - only `src/shared/api` uses the network client;
  - routes stay thin;
  - no cycles.
- **Translations:** every key exists in en, ar and ml (the app's locales and the dev gallery's).

## Working rules

- **Contract first.** A new endpoint goes into `contracts/api/` (then `npm run bundle` there), then `npm run api:types` here. Call it only through `api` from `@/shared/api/client`.
- **Errors arrive as `ApiProblem`.** Branch on `problem.code` and show translated text; never show `detail`.
- **Server state uses TanStack Query.** Route loaders may prefetch through the router's `queryClient`. No hand-rolled caches.
- **Feature layout:** a feature lives in `src/features/<name>/`. Route files in `src/routes/` only map a URL to a feature page.
- **UI:** use `src/shared/ui` components built on React Aria, and Tailwind classes that name colour roles (`bg-surface`, `text-on-surface`, `bg-primary-container`, `text-accent`; ARCHITECTURE.md lists which role goes where) and the `focus-ring` utility, with shapes, spacing and text styles named by token (ARCHITECTURE.md lists them; prefer a role such as `rounded-card` or `px-page-margin` to a scale step). Build screens from the key components (`Button`, `Card`, `TextField`, `OptionRow`, `SegmentedPills`, `TopBar`, `BottomBar`, …; ARCHITECTURE.md lists them, `contracts/design-system/v1/components.md` specifies them) and check new states in the dev gallery (`npm run dev`, then `/dev/components`). **Motion is fades and colour cross-fades only** (`motion.css`: page fades, `content-swap`, `select-fade`, `overlay-fade`); nothing moves or scales. Never raw colours, never `primary` as text (except where components.md pairs it), and never logic that depends on the colour scheme. **No outlines:** controls are filled (`useFill()` / `useSecondaryFill()`; `Card` sets the context for its content), rows in a card are separated by spacing, and the only lines are the focus ring, a checkbox's box and a field's error border, each a `shape.json` stroke. The only shadow is `shadow-floating`.
- **Dev-only code** lives in `src/dev/` and is loaded only by `main.tsx` behind `import.meta.env.DEV`; check that `dist` doesn't contain it after a build.
- **Strings:** all UI text goes in `src/shared/i18n/locales/{en,ar,ml}.json`. Layout uses logical properties (`ps-*`, `me-*`), so right-to-left layout works automatically.
- **Tests:** mock the API with `specHandler(operationId, status)` or `specProblem(operationId, code)`, which serve the spec's own examples. The test page's origin (`web.awrad.test`) can't resolve, so a missing mock fails instead of reaching a real server.

## Validation

```bash
npm run validate     # types, tokens and icons fresh, no raw values, fonts match contracts, translations, typecheck, lint, format, module rules, tests, build
npm test             # just the tests (Vitest)
npm run format       # fix formatting
```
