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

## ADR-2026-07-15: Data-preserving iOS relational migration

Status: Accepted

### Context

iOS stored the complete offline product graph in one App Group JSON snapshot. That made relational uniqueness, atomic aggregate updates, forward schema evolution, and safe main-app/widget coordination fragile. Existing snapshot-v5 installs still contain user-created content and devotional history that cannot be discarded.

### Decision

iOS keeps `AwradStore` as its observable facade but moves production data to an App Group SwiftData store behind repository protocols, a `VersionedSchema`, and a `SchemaMigrationPlan`. Snapshot v5 is imported once through validation, an immutable backup, an atomic replace, reload verification, and a canonical semantic checksum. Corrupt or future data is never reseeded; the app exposes retry/export recovery, and a valid snapshot may remain available through a protected working fallback. Preferences move to App Group `UserDefaults`, credentials remain in Keychain, and widgets render a compact projection while interactive mutations use the relational repository after migration.

### Consequences

Existing UUIDs, definitions, counts, history, and preferences survive the storage transition. Future iOS schema changes use forward migrations. App and widget transactions share Android-equivalent uniqueness and cap semantics without making Room and SwiftData byte-identical. The legacy JSON writer remains only for migration recovery and explicitly gated pre-migration widget compatibility.

### Evidence

- `awrad-ios/awrad/awrad/Core/Persistence/AwradPersistenceSchema.swift`
- `awrad-ios/awrad/awrad/Core/Persistence/LegacySnapshotMigration.swift`
- `awrad-ios/awrad/Shared/AwradRelationalWidgetMutation.swift`
- `awrad-ios/awrad/awradTests/AwradPersistenceTests.swift`

### Supersedes

The iOS snapshot file as the normal persistence and widget mutation boundary. Snapshot v5 remains supported migration and backup input.

## ADR-2026-07-15: Canonical cross-platform Wird model

Status: Accepted

### Context

Android shipped version 5 with eight weekday-assigned parts, while iOS shipped a seven-part version 2 with unstable nested UUIDs. Updating each native asset independently could attach existing progress to the wrong devotional text or keep the two clients permanently divergent.

### Decision

`contracts/wird-model/v1` owns the reviewed bundled Wird content, eight-part structure, weekday/cadence fixture, deterministic structural IDs, identity manifest, and content hash. A generator emits both native assets. iOS maps legacy nested IDs only when a normalized content signature has one complete unambiguous canonical match. Otherwise, an in-progress session stays pinned to a hidden legacy definition until its cycle is complete.

### Consequences

Android and iOS use matching content, ordering, IDs, and cadence for new sessions. Generated assets cannot drift silently. Migrated progress is preserved without guessing; a legacy definition may temporarily coexist with the canonical one as an intentional safety tradeoff.

### Evidence

- `contracts/wird-model/v1/`
- `scripts/generate_wird_model.py`
- `awrad-ios/awrad/awrad/Core/WirdContentMigration.swift`
- `awrad-ios/awrad/awradTests/WirdContentMigrationTests.swift`

### Supersedes

Platform-maintained bundled Wird copies and random nested identifiers.

## ADR-2026-07-15: Native iOS presentation for Android behavior parity

Status: Accepted

### Context

Pixel-copying Material surfaces would conflict with iOS navigation, accessibility, and system design behavior. At the same time, redesigning page hierarchy independently would make workflows and state visibility diverge from the frozen Android product.

### Decision

Android commit `2f56aa4` defines page membership, section order, state transitions, actions, and persisted outcomes. iOS implements those contracts with native SwiftUI navigation, sheets, toolbars, controls, and gestures. On iOS 26 and later, standard chrome receives system Liquid Glass and custom glass is restricted to interactive controls. iOS 18–25 and Reduce Transparency use readable material or opaque fallbacks; devotional text and primary content remain on high-contrast surfaces.

### Consequences

Users receive equivalent product behavior without Android-shaped iOS controls. Platform differences must be explicit in the parity ledger, and visual acceptance covers iOS 26, iOS 18, RTL, Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency.

### Evidence

- `docs/ios-android-parity-ledger.md`
- `awrad-ios/awrad/awrad/DesignSystem/AwradDesign.swift`
- `docs/ios-parity-debugger-review.md`

### Supersedes

None.

## ADR-2026-07-15: Universal confirmation before unavailable goal counting

Status: Accepted

### Context

Android and iOS previously interpreted `slot_counting_policy` differently and only guarded some outside-slot actions. Future-start and off-recurrence counting could also bypass the timing prompts, while counter, Quran, audio, and widget entry points did not share a daily authorization.

### Decision

Every positive native count action uses a platform-local availability calculator. Future-start, off-recurrence, upcoming, ended, and unresolved-slot reasons require one combined confirmation; paused, completed, expired, and duration-ended goals hard-block. A confirmation is keyed by goal, slot, effective day, and the complete reason set. iOS shares keys through App Group defaults and Android uses DataStore. Legacy `slot_counting_policy` values remain persisted and wire-compatible but no longer control runtime counting and are hidden from goal editors.

### Consequences

Manual counts, positive adjustments, Quran counting, audio start/resume, and iOS widget/App Intent mutations now agree. Negative corrections remain available, existing caps still run after authorization, and bypassed counts stay on the current effective day rather than advancing a future occurrence.

### Evidence

- `contracts/behavior-model/v1/fixtures/behavior-cases.json`
- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingAvailability.kt`
- `awrad-ios/awrad/Shared/CountingAvailability.swift`

### Supersedes

Runtime behavior implied by the legacy slot-counting policy selector; the persistence and wire representation remain compatible.

## ADR-2026-07-16: Offline-first progress synchronization

Status: Accepted

### Context

Stable UUIDs and the progress-model contract removed identity divergence, but mutable count totals cannot safely synchronize across disconnected devices. Timestamp replacement loses taps, signed deltas can create negative debt, live paginated tables can skip moving rows, and the current clients need an explicit account, retry, deletion, and legacy-import contract before public routes are added.

### Decision

Native state remains authoritative for immediate offline use. Every synchronized write creates an ordered UUID-keyed outbox command atomically with local product state. Phoenix assigns commit-ordered per-user revisions and idempotent receipts. Positive count batches become immutable credits; decrement and reset consume only eligible observed credit under server order. Custom dhikrs and goal definitions use whole-document optimistic concurrency. Automatic completion is projection state. Bootstrap and delta responses are immutable short-lived materializations from one PostgreSQL snapshot. Deleted entities use recoverable tombstones, incarnation barriers, and permanent minimal anti-resurrection fences.

Local data binds immutably to the first account whose import completes. Ambiguous legacy aggregate counts require explicit reconciliation rather than guessed arithmetic. Count ledgers compact through actor-safe checkpoints, while stale destructive commands are rejected for refresh and re-confirmation.

### Consequences

Counting never depends on connectivity, retries cannot duplicate accepted progress, concurrent increments converge, and destructive operations cannot erase unseen progress or create negative debt. The server stores additional command/credit metadata and serializes bounded writes per account. Android requires a Room sync migration; iOS synchronized state requires one transactional App Group persistence authority and background-safe token refresh before sync rollout.

### Evidence

- `docs/progress-sync-architecture.md`
- `contracts/progress-sync/v1/`
- `scripts/validate_progress_sync.py`
- `awrad_api/lib/awrad_api/progress_sync.ex`
- `awrad_api/priv/repo/migrations/20260716053734_create_progress_sync_foundation.exs`
- `awrad_api/priv/repo/migrations/20260716055321_create_progress_sync_count_ledger.exs`
- `awrad_api/test/awrad_api/progress_sync_test.exs`
- `awrad_api/test/awrad_api/progress_sync_count_ledger_test.exs`

### Supersedes

The previously undecided synchronization portions of ADR-2026-07-13 UUIDv4 progress identity and native model parity.

## ADR-2026-07-24: Capability-gated dhikr tags in progress sync v1

Status: Accepted

### Context

Custom-dhikr expansion needs user-defined tags that sync for authenticated users, without exposing unknown transfer record kinds to older clients and without syncing owned audio bytes.

### Decision

Extend progress-sync protocol v1 with capability `dhikr_tags_v1` and entity types `user_tag` and `dhikr_tag_assignment`. Keep progress-model version 1 and the existing `custom_dhikr` document shape unchanged. The server owns tag-name normalization (NFC display + Unicode Default Case Fold + White_Space collapse), duplicate normalized-name coalescing via accepted `canonical_effect.entity_id` identity swap, immutable assignment references after create, restore-time ownership revalidation, built-in/custom assignment targets, limits, and cascade tombstones. Transfer pages omit tag records unless the client advertises `dhikr_tags_v1`, and non-capable transfers exclude those rows before the shared record limit. Newly capable clients take one capability-aware snapshot bootstrap before resuming deltas. Owned audio remains device-local outside the sync contract. The Ecto CHECK expansion for tag entity types is irreversible once deployed.

### Consequences

Server and contracts can roll out ahead of native tag UI/sync. Older clients remain compatible. Native clients must implement the durable bootstrap flag and coalescing apply path when they adopt the capability (re-point local assignments when `command.entity_id != canonical_effect.entity_id`). Native normalizers must adopt the shared full-casefold/White_Space contract in `tag-normalization-contract.json`.

### Evidence

- `contracts/progress-sync/v1/progress-sync.schema.json`
- `contracts/progress-sync/v1/README.md`
- `contracts/behavior-model/v1/fixtures/tag-normalization-contract.json`
- `awrad_api/lib/awrad_api/progress_sync/document.ex`
- `awrad_api/lib/awrad_api/progress_sync/entity_store.ex`
- `awrad_api/lib/awrad_api/progress_sync/transfer.ex`
- `awrad_api/test/awrad_api/progress_sync_dhikr_tags_test.exs`
- `awrad_api/priv/repo/migrations/20260724065752_expand_progress_sync_entity_types_for_dhikr_tags.exs`

### Supersedes

None.

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
