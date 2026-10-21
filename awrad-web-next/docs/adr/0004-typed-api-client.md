# 0004: Typed API client: openapi-typescript + openapi-fetch

Status: Accepted (2026-10-21)

## Context

The web app calls the API described by `contracts/api/openapi.bundled.json` and must not drift from it (root ADR-2026-10-16). Options compared:

| Option                                          | Runtime cost                                         | Generated code                         |
| ----------------------------------------------- | ---------------------------------------------------- | -------------------------------------- |
| A. `openapi-typescript` types + `openapi-fetch` | ~4 KB gzipped                                        | One types file; nothing ships          |
| B. Hey API, Orval or Kubb generators            | Client runtime plus a function or hook per operation | Many files, growing with the API       |
| C. Runtime validation (Zod schemas)             | +13 KB or more, plus parsing on every response       | Many files                             |
| D. Plain `fetch` plus a hand-written helper     | ~0 KB                                                | One types file, plus a helper we'd own |

## Decision

**Option A.** It's the lightest choice with full compile-time safety:

- only paths in the spec compile;
- parameters, request bodies and success and error responses are typed per operation and status;
- middleware handles CSRF.

No per-endpoint code ships, and the tools are two small packages from one project. Runtime response validation isn't used: `awrad-server-next` already contract-tests its responses against the same spec.

## Consequences

- Each feature writes small TanStack Query hooks around `api` (for example `useBrowserSession`).
- If hand-written hooks become repetitive, `openapi-react-query` (same project) or a generator (option B) can be reconsidered in a new ADR. Only `src/shared/api` and the feature hooks would change.
- `openapi-fetch` must look up `fetch` per call (see `src/shared/api/client.ts`), so mocks and instrumentation see every request.
