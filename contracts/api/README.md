# Awrad API contract

The OpenAPI 3.1 spec for `awrad-server-next`, consumed by Android, iOS and web.

| File | Role |
|---|---|
| [`STYLE.md`](STYLE.md) | The rules every endpoint follows (ADR-2026-10-16) |
| `openapi.yaml` | Root of the spec: info, auth schemes, shared components. **Edit this and `paths/`** |
| `paths/*.yaml` | Operations, one file per area (`browser.yaml`, later `accounts.yaml`, `goals.yaml`, …) |
| `openapi.bundled.json` | **Generated** single-file spec. Committed, because clients and contract tests read it. Never edit by hand |
| `spectral.mjs` | `STYLE.md` as lint rules (17 custom rules plus Spectral's OpenAPI rules) |
| `tests/` | `violations.yaml` breaks every custom rule once; `check-rules.mjs` proves each one fires; `check-bundle.mjs` rejects a stale bundle |

## Workflow

```bash
cd contracts
npm ci            # once: installs the pinned tools
npm run bundle    # after editing openapi.yaml or paths/*.yaml
npm test          # bundle fresh, spec lint clean, every rule fires, fixtures valid
```

The bundle is what gets linted, because Spectral can't follow cross-file path references in OpenAPI 3.1. Redocly bundles the files first.

## How each project uses the spec (ADR-2026-10-16, client types)

| Project | Uses `openapi.bundled.json` for |
|---|---|
| `awrad-server-next` | Request and response validation plus contract tests (for example `open_api_spex`) |
| `awrad-web-next` | Generated TypeScript types (`openapi-typescript`): types only, no runtime code |
| `awrad-android-next` | **Hand-written** request/response classes in its network module, plus a contract test that decodes and re-encodes every example in the spec |
| `awrad-ios-next` | Same as Android, with `Codable` structs |

The mobile contract test fails if an example doesn't survive the round trip unchanged, or if the app uses an operation that has no example. So drift between the spec and a client breaks that client's build.

## Adding an endpoint

1. Add the operation to the right `paths/<area>.yaml`, and reference it from `openapi.yaml`.
2. Follow `STYLE.md`:
   - snake_case operation IDs and fields;
   - `security` declared;
   - `x-error-codes` listed;
   - examples on every body;
   - `Cache-Control` and `x-request-id` on every response;
   - `Idempotency-Key` on POSTs.
3. Reuse `components` (Count, Uuid, Instant, Problem responses…) instead of redefining them.
4. Run `npm run bundle && npm test`.

## Known dependency advisory

`npm audit` reports a `braces` / `micromatch` advisory through `@stoplight/spectral-cli`'s file-glob handling. It's a slowdown triggered by malicious glob patterns, in a dev-only tool that only ever sees this repo's own paths. Re-check it when bumping Spectral.
