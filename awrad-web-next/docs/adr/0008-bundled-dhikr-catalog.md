# 0008: The dhikr catalog is a generated, typed module in a lazy chunk

Status: Accepted (2026-10-27).

## Context

Slice 3a gives every app the built-in dhikrs from one shared file, `contracts/dhikr-catalog/v1/catalog.json` (113 dhikrs, 5 collections, about 90 kB), generated at build time with a drift check. The web is online-only, but the slice keeps the catalog bundled: there's no catalog API. The first page (Home) should stay small, yet Home shows the collections.

## Decision

- **Generated TypeScript, not a JSON import.** `scripts/generate-catalog.mjs` writes `src/shared/dhikr-catalog/catalog.gen.ts`, the JSON as a `Catalog` literal (`types.ts`), formatted and committed like the token and icon files. The generator knows every key of the schema's shapes and fails on an unknown key, kind, audio style, reference type or version, or a missing required key; `check:catalog` fails `validate` when the file is stale. TypeScript checks the literal against the types as well. No schema validator is added: the contract's own checker (`contracts/tools/check-dhikr-catalog.mjs`) validates the schema and the cross-references.
- **Its own chunk.** Only `load.ts` imports `catalog.gen.ts`, with a dynamic `import()`. Library route loaders await `loadCatalog()`; components read it with React's `use`. The resolved promise is marked `status: "fulfilled"` (the thenable fields React reads), so a page whose loader already has the catalog renders at once instead of suspending again. Home's tiles suspend in a placeholder of the tile height.
- **Read-only.** The types are `readonly` throughout, and nothing writes to the catalog; there's no API and no TanStack Query cache for it, since it isn't server state.

## Consequences

- The first page doesn't carry the catalog; the chunk (about 15 kB gzipped) loads on Home or the Library.
- A contract change that adds a field fails the build until the generator and `types.ts` learn it.
- `catalog.gen.ts` is exempt from `check:raw-values` and the 400-line limit, as generated data.
