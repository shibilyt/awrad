# 0004: The API client and the account session live in AwradData

Status: Accepted (2026-10-26)

## Context

Slice 2a adds the first network calls: the account operations of `contracts/api` (root ADR-2026-10-26) and a device session with rotating refresh tokens (ADR-2026-07-12). ARCHITECTURE.md already reserved Keychain and network adapters for `AwradData`. Three questions needed an answer:

- A separate `AwradNetwork` target, or `AwradData`?
- The adapter needs seams of its own for tests: an HTTP transport, secure storage and an installation marker. AGENTS.md says a port is a domain protocol with its fake in `AwradTesting`, but these are infrastructure, not domain concepts.
- The wire types are hand-written (root ADR-2026-10-16). Where do they meet the domain?

## Decision

- **No new target.** `AwradData/Network/` holds the API client and the hand-written `Codable` wire types; `AwradData/Account/` holds `AuthSession`, the Keychain store and the device name. The module graph is unchanged.
- **One domain port:** `AccountService` in `AwradDomain`, with domain values (`Account`, `AccountError`, `AccountFieldIssue`). Features see only it, and its fake (`FakeAccountService`) is in `AwradTesting`.
- **Adapter seams aren't ports.** `HTTPTransport`, `SecureStore` and `InstallationMarker` are public protocols in `AwradData`, so the composition root can pick the production ones. Their test doubles live in `AwradDataTests`, because `AwradTesting` only sees `AwradDomain`.
- **Wire types stay internal** to `AwradData` and keep instants as strings, so a decode/re-encode round trip is exact. `OpenAPIContractTests` checks each used operation against `openapi.bundled.json`: method, path, security, headers, and every request and response example.
- **Errors map by `code` only** (STYLE §7), in one place (`AccountError.init(_: APIFailure)`), never by status or `title`.

## Consequences

- One place for HTTP rules: a bearer token only on operations that take one, `Idempotency-Key` on every `POST`, `Accept-Language` where the spec has it.
- Later API areas (sync, community) add operations and wire types beside these, with the same contract test.
- If the network code grows big enough to slow `AwradData` builds, splitting it into its own target is a mechanical move.
