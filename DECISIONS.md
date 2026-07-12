# Decision index

Use decision records for choices that must remain understandable after the implementation context is gone. Code and tests remain the final evidence that a decision is implemented.

## Existing decision sources

- Android product and data decisions: [`awrad-android/prd/decisions/`](awrad-android/prd/decisions/)
- Android goal schema decision: [`awrad-android/docs/decisions/goal-schema.md`](awrad-android/docs/decisions/goal-schema.md)
- API architecture decisions: [`awrad_api/memory/decisions/`](awrad_api/memory/decisions/)
- iOS architecture and implementation status: [`awrad-ios/awrad/docs/ios-architecture.md`](awrad-ios/awrad/docs/ios-architecture.md)

Android files under `docs/superpowers/plans/` are historical implementation plans, not accepted cross-project decisions.

## When a root decision is required

Add a dated section to this file when a choice affects more than one project or changes any of these:

- API request/response compatibility;
- identifier or account ownership;
- offline-first synchronization and conflict handling;
- cross-platform product semantics;
- backup/import compatibility;
- authentication or token lifecycle;
- shared content source/versioning;
- release coordination between clients and server.

Platform-local choices should remain in the owning platform's decision system.

## Status vocabulary

- Proposed: under discussion; not authoritative.
- Accepted: implementation may rely on it.
- Superseded: retained for history and linked to its replacement.
- Rejected: considered and deliberately not chosen.

## ADR-2026-07-12: Verified mobile accounts and revocable device sessions

Status: Accepted

### Context

The original mobile flow issued tokens before email verification, rotated refresh tokens with a delete-then-create race, and allowed parallel Android refresh failures to clear valid credentials.

### Decision

Phoenix remains the identity owner. Mobile registration is atomic and verification-first. Access JWTs are short-lived and bound to an active server-side device session. Refresh tokens rotate transactionally with request-id retry support and family replay detection. Android serializes refresh, preserves credentials during transient failures, and stores secrets with a non-exportable Android Keystore key. Protected online routes use the verified-email API pipeline.

### Consequences

Both mobile clients understand verification and session-bearing responses. Legacy refresh calls remain temporarily compatible but lack idempotent retry guarantees. Future MFA or passkeys can raise assurance on the same session model.

### Evidence

- `awrad_api/lib/awrad_api/accounts/token.ex`
- `awrad_api/lib/awrad_api_web/controllers/api/auth_controller.ex`
- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/network/TokenAuthenticator.kt`

### Supersedes

The mobile-token portions of `awrad_api/memory/decisions/dual-auth.md` and `refresh-token-rotation.md`; browser sessions remain unchanged.

## Root ADR template

Copy this section, replace the placeholders, and keep it concise.

```markdown
## ADR-YYYY-MM-DD: Decision title

Status: Proposed | Accepted | Superseded | Rejected

### Context

What concrete problem or incompatibility requires a decision?

### Decision

What is the chosen behavior, ownership boundary, and compatibility rule?

### Consequences

What becomes easier, what tradeoffs remain, and which projects must change?

### Evidence

- `path/to/implementation`
- `path/to/test`

### Supersedes

Link an older decision when applicable; otherwise write `None`.
```
