# 0002: TypeScript 6.0 until the tooling supports TypeScript 7

Status: Accepted (2026-10-21)

## Context

npm's latest TypeScript is 7.0, the native compiler. On 2026-10-21:

- `typescript-eslint` (type-aware lint rules) supports only TypeScript below 6.1;
- `openapi-typescript` declares only TypeScript 5.

## Decision

- Pin TypeScript **6.0.3**.
- `openapi-typescript`'s outdated declaration is overridden for that one package only (`overrides` in `package.json`), instead of `--force` or `--legacy-peer-deps`, which would hide every other conflict. Its output is checked by `check:api-types` and type-checked on every run.
- `baseUrl` isn't used; it's deprecated in 6.0 and removed in 7.

## Consequences

- Type-aware linting keeps working.
- Revisit when `typescript-eslint` supports 7: bump, drop the override, re-run `npm run validate`.
