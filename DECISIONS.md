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

## ADR-2026-07-13: UUIDv4 progress identity and native model parity

Status: Accepted

### Context

Android used database-generated numeric IDs while iOS and Phoenix used UUIDs, built-in dhikrs were matched through mutable text, and goal/count semantics had diverged. Cross-device progress synchronization cannot safely build on identities or payloads that change by platform.

### Decision

Dhikr, Goal, GoalSlot, GoalReminder, and CountEntry use client-created UUIDv4 identities. The initial 13 built-in dhikrs have immutable catalog-key/UUID pairs. Android and iOS retain native models and persistence, but both map through the versioned progress-model v1 schema and golden fixtures. Phoenix aligns its persistence and accepts validated client UUIDv4 IDs only through an authenticated context that derives ownership. Local-only and derived fields are explicitly classified. This decision does not add synchronization routes or conflict rules.

### Consequences

Android Room v5 and iOS snapshot v5 reset pre-v5 development product data because legacy numeric/text-matched identity cannot be migrated without guessing; authentication state is untouched. Pre-v5 iOS backup imports are rejected clearly. Phoenix uses forward migrations. Any cross-platform progress change now requires one root change covering contract, fixtures, both native implementations, API representation, and tests.

### Evidence

- `contracts/progress-model/v1/`
- `check-mobile-model-parity`
- `awrad-android/app/schemas/app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase/5.json`
- `awrad-ios/awrad/awrad/Core/ProgressContractV1.swift`
- `awrad_api/priv/repo/migrations/20260713125755_align_progress_model_v1.exs`

### Supersedes

The numeric-ID and transliteration/title-based identity assumptions in pre-v5 mobile product storage. Synchronization ownership and conflict policy remain undecided.

## ADR-2026-07-13: Canonical Asma-ul Husna built-in collection

Status: Accepted

### Context

Adding the Asma-ul Husna names independently to Android, iOS, and Phoenix would create three opportunities for names, invocation wording, ordering, categories, and stable identities to diverge. Audio is not yet available for the full collection.

### Decision

`contracts/progress-model/v1/asma-ul-husna.json` owns the ordered 100-name content (Allah followed by the traditional 99-name sequence) and UUIDv4/catalog-key identity. Generated native seeds expose the invocation variant (`Ya Allah`, `Ya Rahman`, and so on) as built-in dhikrs in the `asma_ul_husna` category with positions 1 through 100, a count-per-tap of one, and no initial audio metadata. The canonical built-in registry now contains 113 identities in total. Canonical names remain separate from generated invocation text so another collection variant can reuse the same reviewed source without changing identity. Future audio additions update metadata without changing identity.

### Consequences

Android and iOS automatically merge the collection into existing local product state through their current built-in reconciliation paths. Phoenix seeds the same identities and category idempotently. Changes to the collection require regeneration plus the root parity check.

### Evidence

- `contracts/progress-model/v1/asma-ul-husna.json`
- `scripts/generate_asma_ul_husna.py`
- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AsmaUlHusnaSeed.kt`
- `awrad-ios/awrad/awrad/Core/AsmaUlHusnaSeed.swift`
- `awrad_api/priv/asma-ul-husna.json`

### Supersedes

None. This extends ADR-2026-07-13 UUIDv4 progress identity and native model parity.

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
