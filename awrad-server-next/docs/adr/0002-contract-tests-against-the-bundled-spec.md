# 0002: Contract tests against the bundled OpenAPI spec

Status: Accepted (2026-10-17)

## Context

The OpenAPI 3.1 spec in `contracts/api/` is the API source of truth (root ADR-2026-10-16). The server must not drift from it, and the Elixir OpenAPI libraries centre on specs written in Elixir code, with partial support for 3.1.

## Decision

- Keep the spec as the source, in `contracts/`. Tests read the committed `openapi.bundled.json`.
- Validate each response body with **JSV** (JSON Schema 2020-12, which OpenAPI 3.1 uses), resolving `#/components/...` references against the spec.
- `AwradWeb.Contract.assert_conforms/2` also checks the documented status, headers and content type.
- `ContractCoverageTest` requires the router and the spec to list exactly the same `/api/v1` operations.

## Consequences

- An endpoint whose shape doesn't match the spec, or a route without a spec entry, fails `mix validate`.
- CI runs the server job whenever `contracts/api/` changes, so a spec edit that breaks the server is caught immediately.
- Request validation (rejecting unknown fields, STYLE.md §12) is done per endpoint, with Ecto changesets or embedded schemas. If that turns out repetitive, a spec-driven request validator can be added later.
