# 0005: A `:core:network` module on OkHttp, without Retrofit

Status: Accepted (2026-10-26)

## Context

Slice 2a (accounts) is the first API code in this project. Root ADR-2026-10-16 already decided that mobile clients hand-write their request and response classes and protect them with a contract test against `contracts/api/openapi.bundled.json`. That leaves two Android choices:

- where API code lives in the module graph;
- which HTTP client to use.

awrad-android uses Retrofit with OkHttp, and attaches the bearer token in an interceptor. That interceptor put the token on public routes too (brief inventory row 12).

## Decision

- **`:core:network`** (`awrad.android.library` + Hilt + kotlinx.serialization) holds the API classes, the HTTP client and the device session. It's a leaf: it depends on no other project module. `:core:data` depends on it and adapts it to domain ports (`NetworkAccountRepository` for `AccountRepository`). Features never see it.
- **OkHttp 4.12.0** (the version awrad-android uses), **without Retrofit or interceptors**. OkHttp sits behind a one-method `HttpTransport` interface; tests use a fake transport.
- **Operations are listed once**, in the `ApiOperation` enum: operation id, method, path, whether it's public, and whether it takes `Accept-Language` and `Idempotency-Key`. `AccountsApi` builds every header from that entry. A public operation can't be called with a token (it fails fast), and `ApiContractTest` checks every entry against the spec.
- Responses decode with `ignoreUnknownKeys` (STYLE §14 allows new fields); the contract test decodes strictly.

## Consequences

- No annotation processing or reflection for HTTP. The whole client is small hand-written Kotlin that follows the project's lint and explicit-API rules.
- Headers are visible per operation, not hidden in interceptors, so "no bearer token on public operations" is a property of the enum and is tested.
- Adding an operation means adding an `ApiOperation` entry, its body classes and a call in the API class. The contract test fails until the entry matches the spec and its examples round-trip.
- Revisit Retrofit if the operation count grows enough that the hand-written calls become repetitive (root ADR-2026-10-16 puts the review point near 50 operations).
