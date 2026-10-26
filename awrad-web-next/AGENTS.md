# awrad-web-next — agent instructions

Applies inside `awrad-web-next/` and extends [`../AGENTS.md`](../AGENTS.md). Read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`docs/adr/`](docs/adr/README.md) first.

## Rules the build enforces (`npm run validate`)

- **API types:** `src/shared/api/schema.gen.ts` matches `contracts/api/openapi.bundled.json`. Regenerate with `npm run api:types`.
- **Colours:** `src/shared/ui/colors.gen.css` matches `contracts/design-tokens/v1/colors.json` (regenerate with `npm run tokens:colors`), and no hex colour, colour function or Tailwind palette class appears anywhere else.
- **TypeScript:** maximum strictness (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, …).
- **ESLint** with zero warnings allowed:
  - typescript-eslint strict and stylistic type-checked rules;
  - React Hooks and React Compiler rules;
  - jsx-a11y strict;
  - **no hard-coded UI text** (`i18next/no-literal-string`);
  - no direct `fetch`;
  - 400-line files.
- **Prettier** formatting.
- **Module rules** (dependency-cruiser):
  - features never import each other;
  - `shared` never imports features or routes;
  - only `src/shared/api` uses the network client;
  - routes stay thin;
  - no cycles.
- **Translations:** every key exists in en, ar and ml.

## Working rules

- **Contract first.** A new endpoint goes into `contracts/api/` (then `npm run bundle` there), then `npm run api:types` here. Call it only through `api` from `@/shared/api/client`.
- **Errors arrive as `ApiProblem`.** Branch on `problem.code` and show translated text; never show `detail`.
- **Server state uses TanStack Query.** Route loaders may prefetch through the router's `queryClient`. No hand-rolled caches.
- **Feature layout:** a feature lives in `src/features/<name>/`. Route files in `src/routes/` only map a URL to a feature page.
- **UI:** use `src/shared/ui` components built on React Aria, and Tailwind classes that name colour roles (`bg-surface`, `text-on-surface`, `bg-primary-container`, `text-accent`; ARCHITECTURE.md lists which role goes where) and the `focus-ring` utility. Never raw colours, never `primary` as text, and never logic that depends on the colour scheme. **No outlines:** controls are filled (`useFill()`, and `<OnSurface>` around controls on a card), rows in a card are separated by spacing, and the only lines are the focus ring, a checkbox's box and a field's error border.
- **Strings:** all UI text goes in `src/shared/i18n/locales/{en,ar,ml}.json`. Layout uses logical properties (`ps-*`, `me-*`), so right-to-left layout works automatically.
- **Tests:** mock the API with `specHandler(operationId, status)` or `specProblem(operationId, code)`, which serve the spec's own examples. The test page's origin (`web.awrad.test`) can't resolve, so a missing mock fails instead of reaching a real server.

## Validation

```bash
npm run validate     # types fresh, translations, typecheck, lint, format, module rules, tests, build
npm test             # just the tests (Vitest)
npm run format       # fix formatting
```
