# Decision index

Use decision records for choices that must remain understandable after the implementation context is gone. Code and tests remain the final evidence that a decision is implemented.

## Existing decision sources

- Android product and data decisions: [`awrad-android/prd/decisions/`](awrad-android/prd/decisions/)
- Android goal schema decision: [`awrad-android/docs/decisions/goal-schema.md`](awrad-android/docs/decisions/goal-schema.md)
- API architecture decisions: [`awrad_server/memory/decisions/`](awrad_server/memory/decisions/)
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

- `awrad_server/lib/awrad_server/accounts/token.ex`
- `awrad_server/lib/awrad_server_web/controllers/api/auth_controller.ex`
- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/network/TokenAuthenticator.kt`

### Supersedes

The mobile-token portions of `awrad_server/memory/decisions/dual-auth.md` and `refresh-token-rotation.md`; browser sessions remain unchanged.

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
- `scripts/check-mobile-model-parity`
- `awrad-android/app/schemas/app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase/5.json`
- `awrad-ios/awrad/awrad/Core/ProgressContractV1.swift`
- `awrad_server/priv/repo/migrations/20260713125755_align_progress_model_v1.exs`

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
- `awrad_server/priv/asma-ul-husna.json`

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
- `awrad_server/lib/awrad_server/progress_sync.ex`
- `awrad_server/priv/repo/migrations/20260716053734_create_progress_sync_foundation.exs`
- `awrad_server/priv/repo/migrations/20260716055321_create_progress_sync_count_ledger.exs`
- `awrad_server/test/awrad_server/progress_sync_test.exs`
- `awrad_server/test/awrad_server/progress_sync_count_ledger_test.exs`

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
- `awrad_server/lib/awrad_server/progress_sync/document.ex`
- `awrad_server/lib/awrad_server/progress_sync/entity_store.ex`
- `awrad_server/lib/awrad_server/progress_sync/transfer.ex`
- `awrad_server/test/awrad_server/progress_sync_dhikr_tags_test.exs`
- `awrad_server/priv/repo/migrations/20260724065752_expand_progress_sync_entity_types_for_dhikr_tags.exs`

### Supersedes

None.

## ADR-2026-09-04: Browser companion actors use the existing sync ledger

Status: Accepted

### Context

The desktop/tablet web companion needs authenticated count buttons that update
the same canonical ledger as Android and iOS. A browser must not be trusted to
choose a user, actor, sequence, or ownership field, and two accounts may use
the same browser.

### Decision

Use the existing `progress_sync_actors` table with a server-generated UUIDv4
browser installation identifier stored in the signed, host-only, `HttpOnly`
Phoenix session cookie. Resolve actors by `(user_id, installation_id)` so tabs
share one account stream while account switches remain isolated. The
`AwradServer.WebSync` adapter is the only browser mutation boundary; it validates
browser-local date and web-supported slot eligibility, then lets
`AwradServer.ProgressSync` lock the user head and actor, allocate the next
sequence, execute the canonical count command, and return the idempotent
receipt. Canonical reads acknowledge and renew the actor. Expired actors roll
to a new incarnation without changing historical progress. No migration,
IndexedDB outbox, service worker, public JSON route, or mobile contract change
is introduced.

### Consequences

Web counts converge with mobile counts through `CountLedger`, projections, and
the existing mobile-visible delta path. Same-browser account isolation and
duplicate-click safety are server-enforced. The web companion remains
online-first and supports only manual counts for active anytime slots in v1;
prayer-relative and time-window slots stay view-only.

### Evidence

- `awrad_server/lib/awrad_server/web_sync.ex`
- `awrad_server/lib/awrad_server/progress_sync.ex`
- `awrad_server/lib/awrad_server_web/web_installation.ex`
- `awrad_server/test/awrad_server/web_sync_test.exs`
- `awrad_server/test/awrad_server_web/web_installation_test.exs`

### Supersedes

None.

## ADR-2026-09-09: Separate account practice policy from device context

Status: Accepted

### Context

Day-end behavior, prayer calculation method, and madhab should be consistent
for one account, while timezone and location can legitimately differ between a
phone, tablet, and browser. Treating all of these as one shared settings row
would make one device silently change another device's prayer context.

### Decision

Persist one canonical `AccountPracticePolicy` per user for day reset,
calculation method, madhab, and its revision. Persist one `DeviceContext` per
`(user_id, installation_id)` for timezone and optional location metadata. A
browser records its context only after authenticated LiveView initialization,
browser geolocation permission, manual coordinate entry, or a count command;
location never overwrites another installation's context. For a Maghrib day
reset, the browser calculates the boundary locally with the bundled Adhan JS
calculator; the server compares the reported UTC instant with its own clock,
accepts only the matching effective date, and falls back to midnight when this
installation has no usable location. Historical progress keeps its accepted
local date and is not rebucketed when a device context changes.

### Consequences

Account policy is reconciled across native and web clients through an additive
verified API contract, while location remains device-local. Existing progress
sync envelopes remain unchanged. Mobile clients use optimistic policy
revisions; a stale mobile write adopts the current server policy.

### Evidence

- `awrad_server/lib/awrad_server/practice_settings.ex`
- `awrad_server/lib/awrad_server/practice_settings/account_practice_policy.ex`
- `awrad_server/lib/awrad_server/practice_settings/device_context.ex`
- `awrad_server/lib/awrad_server_web/live/practice_live_support.ex`
- `awrad_server/lib/awrad_server/practice_day.ex`
- `awrad_server/assets/js/practice_day.js`
- `awrad_server/test/awrad_server/practice_day_test.exs`
- `awrad_server/test/awrad_server/practice_settings_test.exs`
- `awrad_server/lib/awrad_server_web/controllers/api/practice_settings_controller.ex`
- `awrad_server/test/awrad_server_web/controllers/api/practice_settings_controller_test.exs`
- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/sync/PracticeSettingsRepository.kt`
- `awrad-ios/awrad/awrad/Core/PracticeSettingsSync.swift`

### Supersedes

None.

## ADR-2026-09-09: Merge local and remote practice settings at account binding

Status: Accepted

### Context

Mobile settings can be chosen before sign-in, while the same account may
already have a policy set on the web or another mobile installation. Blindly
uploading local values would let a new device overwrite an established
account, and blindly discarding them would lose intentional first-run choices.

### Decision

Fetch the server policy before applying or uploading mobile values. A local
policy with no account owner may initialize only a revision-one server-default
policy. After binding, a local change uploads with the last server revision;
if the revision has moved, the server snapshot wins. The authenticated user ID
is stored with the local settings metadata so switching accounts in one
installation cannot carry the previous account's policy across. Every sync
also sends timezone and optional location to the installation-specific device
context endpoint.

### Consequences

The account policy is deterministic and conflict-safe without making network
access a prerequisite for native counting. Local settings remain immediately
usable offline; a failed settings request is retried by the existing foreground
and background progress-sync cadence. Location never becomes account-global.

### Evidence

- `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/sync/PracticeSettingsReconciliation.kt`
- `awrad-ios/awrad/awrad/Core/PracticeSettingsSync.swift`
- `awrad_server/lib/awrad_server/practice_settings.ex`
- `CONTRACTS.md`

### Supersedes

None.

## ADR-2026-10-14: Rebuild Awrad as four contract-first projects

Status: Accepted

### Context

Awrad hasn't been released. An architecture review of `awrad-android` found domain rules copied across UI, repositories and notifications, plus very large files. The API contract lives in prose (`CONTRACTS.md`) and can drift from the three consumers. Rather than restructure in place, the platform is being rebuilt while there are still no users to protect.

### Decision

- **Four new projects** replace the current three:

  | New project | Replaces | Notes |
  |---|---|---|
  | `awrad-server-next/` | `awrad_server/` | API only: no LiveView or HTML |
  | `awrad-android-next/` | `awrad-android/` | Scaffold exists |
  | `awrad-ios-next/` | `awrad-ios/` | |
  | `awrad-web-next/` | the LiveView web UI | A React client of the same API |

  The current projects are **frozen as reference**: their code and tests describe current behaviour, and fixes go only into the new projects.
- **Contract first.** A root `contract/` directory becomes the single source of truth shared by all four:
  - an OpenAPI spec for routes, JSON, errors and auth;
  - language-neutral behaviour fixtures that every platform's domain tests must pass;
  - the domain language (`CONTEXT.md`).

  Clients generate or check their network types against the spec; the server validates against it.
- **Vertical slices.** Each slice goes contract → server → Android → iOS → web before the next starts:
  1. domain foundation and contract skeleton;
  2. accounts;
  3. goals;
  4. counting and progress sync;
  5. then onboarding, wird, library, reminders and community.
- **Shared identity still holds:** built-in content identity (ADR-2026-07-13) and the verified-account and device-session model (ADR-2026-07-12) carry over unless a later ADR supersedes them.

### Consequences

- The contract can be redesigned freely now, but once a slice ships across all four projects it is binding for every consumer.
- Each domain rule is implemented on each platform (no Kotlin Multiplatform; see `awrad-android-next/docs/adr/0002`). Shared fixtures are what keep the implementations aligned.
- `CONTRACTS.md` gives way to `contract/` as each slice lands.
- `STRUCTURE.md` and `docs/index.md` gain each new project when it is created.

### Evidence

- `awrad-android-next/ARCHITECTURE.md` and `awrad-android-next/docs/adr/`

### Supersedes

None yet. Platform ADRs and `CONTRACTS.md` sections are superseded slice by slice.

## ADR-2026-10-14: Technology stack for the rebuild

Status: Accepted

### Context

The rebuild is a chance to change stacks. The decisive server requirement is many concurrent users counting on a single shared public counter, with live totals, while the team is one developer plus AI agents today, with more developers later.

### Decision

| Project | Stack |
|---|---|
| Server | Elixir / Phoenix 1.8, Ecto, Postgres, Oban for background jobs. JSON API plus Phoenix Channels for live data. No Redis or Kafka: ETS and PubSub cover caching and fan-out |
| Android | Kotlin, Jetpack Compose, Hilt, Room, DataStore, multi-module with build-enforced rules |
| iOS | Swift, SwiftUI, SwiftData, Observation, minimum iOS 18. The stack is unchanged; the rebuild targets structure and code quality |
| Web | React, TypeScript, Vite, TanStack Query and Router, with a client generated from the OpenAPI spec. Online-only: no offline counting in the browser |

- **Phoenix stays the core.** If a specific heavy-load path ever outgrows it, that path becomes a separate service behind the same contract, in whatever technology fits best, rather than a rewrite of the whole server.
- **Phoenix's long-term risks are managed, not ignored:**
  - Hiring: hire for backend skill; Elixir is learnable in weeks.
  - Agent proficiency and weaker static typing: Credo strict, Dialyzer, warnings as errors, enforced context boundaries, and contract validation at the API edge.

### Consequences

- The shared-counter design (append-only contributions ledger, group commit, in-memory live deltas, throttled PubSub broadcast, periodic rollups) needs its own ADR once its product semantics are settled: scale target, overshoot at targets, late offline contributions, guest participation and rate caps.
- Browser authentication is settled by ADR-2026-10-15: Phoenix cookie sessions.
- The server becomes API-only, so the LiveView, templates and asset pipeline from `awrad_server/` are not carried over.

### Evidence

- `awrad_server/lib/awrad_server/community.ex` (aggregates on every request today; the motivating scaling gap)

### Supersedes

None.

## ADR-2026-10-15: Browser clients use Phoenix cookie sessions

Status: Accepted

### Context

`awrad-web-next` is a React client of the API-only `awrad-server-next`. Browsers shouldn't hold bearer tokens in JavaScript-readable storage, where any XSS can steal them. Mobile clients keep using bearer tokens under ADR-2026-07-12.

### Decision

- The browser authenticates with **Phoenix's default `phx.gen.auth` session**:
  - an httpOnly, Secure session cookie and the remember-me cookie;
  - tokens stored in `users_tokens`.

  The generated `Accounts`, `UserToken` and `UserAuth` session plugs are kept as generated, apart from deliberate security changes.
- Because the server is API-only, the generated HTML/LiveView pages are replaced by **JSON endpoints** for log in, log out, register, confirm and reset. They use the same `Accounts` functions and session plugs.
- The router keeps **two separate pipelines** that resolve to the same accounts: browser (session cookie and CSRF protection) and mobile (bearer token and device session). Neither accepts the other's credential.
- **Same site, not cross-origin:** the web app is served from the same site as the API, so `SameSite=Lax` cookies work without credentialed CORS. That means either Phoenix serves the built app, or a proxy puts both under one origin.
- **CSRF:** state-changing browser requests send Phoenix's CSRF token in a request header. The web app gets the token from a small endpoint that is only available to session-cookie requests.

### Consequences

- No tokens in `localStorage` or JavaScript memory on the web; XSS can't read the session.
- The OpenAPI contract describes both security schemes: `cookieAuth` plus the CSRF header for the web, `bearerAuth` for mobile.
- Hosting must keep the web app and the API on the same site. Splitting them across sites later would need a new ADR covering credentialed CORS and `SameSite=None`.
- Server tests cover each pipeline rejecting the other's credentials.

### Evidence

- To be added with the accounts slice (`awrad-server-next` router and `UserAuth`).

### Supersedes

The open "browser authentication" item in ADR-2026-10-14 (technology stack).

## ADR-2026-10-16: API style guide for the rebuild

Status: Accepted

### Context

The frozen API has four error shapes (in some, `error` holds a human message, in others a machine code), three versioning patterns, and both snake_case and camelCase schemas. The rebuild's API will serve three clients (Android, iOS, web), so a single set of rules is needed before the first endpoint is specified.

### Decision

Adopt [`contracts/api/STYLE.md`](contracts/api/STYLE.md) for every `awrad-server-next` endpoint. Its four contested choices:

1. **One write path for user progress.** The web calls resource endpoints that the server turns into the same command-ledger commands mobile sends (continuing ADR-2026-09-04). Nothing writes progress tables directly.
2. **Errors are RFC 9457 `application/problem+json`**, with a required stable `code`. Clients switch only on `code` and localize it; `title` and `detail` are English and never shown to users.
3. **Optimistic concurrency uses `expected_revision`** in the body, with `409 revision_conflict` returning the current resource. This is the same model as the sync protocol.
4. **One `/api/v1` prefix** for the whole API (plus `/socket/v1` for Channels). Optional features are negotiated with capability flags.

### Consequences

- Clients get one error parser and one conflict path. The UI never displays server English.
- Server code can't take shortcuts around the ledger for web writes. The web pays a small cost in server-side translation.
- The style guide is enforced by a Spectral ruleset in CI (rebuild plan 0.4). Until then, it's enforced in review.
- The wird model moves to snake_case when it's exposed through the API.
- Counts are whole numbers everywhere. Counts, revisions and sequences are plain JSON integers, bounded by 2⁵³ − 1. This replaces the integer strings of the frozen sync contract.

### Evidence

- `contracts/api/STYLE.md`
- Frozen inconsistencies: `awrad_server/lib/awrad_server_web/controllers/api/auth_controller.ex`, `practice_settings_controller.ex`, `progress_sync_controller.ex`, `error_json.ex`

### Supersedes

None. Applies only to `awrad-server-next`; the frozen API keeps its shapes.

## ADR-2026-10-16: How clients get API types

Status: Accepted

### Context

The OpenAPI 3.1 spec (`contracts/api/`) is the API source of truth for three clients. Code generators fit unevenly:
- Android's main generator supports OpenAPI 3.1 only partially, and produces verbose Kotlin that clashes with `awrad-android-next`'s strict lint and explicit-API rules.
- Generators handle the sync protocol's many-variant payloads poorly on both mobile platforms.
- The API is small, probably 30–50 operations.

### Decision

- **Web:** generated TypeScript types with `openapi-typescript` (types only, no runtime code).
- **Android and iOS:** hand-written request/response classes in each app's network module, mapped to domain types there. Kotlin uses `@Serializable` data classes; Swift uses `Codable` structs.
- **Drift protection on mobile:** a contract test decodes and re-encodes every example in `openapi.bundled.json`, and fails on any difference, or on an operation the app uses that has no example. `STYLE.md` §15 already requires examples on every operation.
- **Server:** validates requests and responses against the same bundled spec in contract tests.

### Consequences

- No generator machinery in the mobile builds, and mobile network code follows each project's normal standards.
- Mobile classes take a little hand-writing. Contract tests catch drift in CI rather than at compile time.
- Revisit if the API grows well past about 50 operations, or if drift bugs get past the contract tests.

### Evidence

- `contracts/api/README.md`
- `contracts/api/STYLE.md` §15

### Supersedes

None.

## ADR-2026-10-26: Hijri dates from one shared table, with month-start corrections

Status: Accepted

### Context

Hijri goals (white days, Ramadan, Arafah, six days of Shawwal) must be due on the same day on every device and on the server. In the frozen apps:
- Android uses two Umm al-Qura engines (`HijrahDate` for goals, ICU for wirds), and iOS uses Foundation's.
- The server has no Hijri calendar, so it treats Hijri goals as never due.
- Elixir has no Umm al-Qura library.
- No platform lets users follow local moon sighting, which can differ from Umm al-Qura by a day or two, and not by the same amount every month.

### Decision

- **One table:** `contracts/hijri-calendar/v1/umm-al-qura.json` holds the Gregorian start of every Umm al-Qura month from 1400 to 1500 AH. It was generated from `java.time` and Foundation, which agree on all 1,213 month starts. Every platform reads this table; none uses a Hijri library for rules.
- **Month-start corrections, not a fixed offset:** a correction `{year, month, offset_days}` moves that month's start, and every later month's until the next correction.
  - It may be at most 2 days from the table.
  - Every adjusted month must still have 29 or 30 days.
  - At most one correction per month.
  - Invalid sets are rejected with the `hijri_corrections_validity` codes.
- **Ownership:**
  - The account's own corrections belong to the account practice policy, so all devices agree. They're stored and synced in the practice-settings slice.
  - Regional corrections published by the server (a sighting authority) are a later option. They merge before the rules run, and the account's own corrections win for the months they cover.
- **Day boundary:** the Hijri date is the date of the effective practice day, so it changes at Maghrib only with the Maghrib reset.
- **Outside the table** there's no Hijri date: Hijri schedules and Hijri-month periods are never due there.

### Consequences

- Parity comes from data rather than from libraries agreeing, and the server needs no dependency.
- The table must be extended before 1500 AH (2077).
- Changing a correction changes which past days of that month were due. Counts stay on their Gregorian dates, so nothing is rewritten.

### Evidence

- `contracts/hijri-calendar/v1/` (table, schema, fixtures)
- `docs/slices/01b-domain-hijri.md`

### Supersedes

None. It replaces the frozen apps' platform Hijri calendars (`awrad-android/prd/decisions/015-dual-calendar-system.md` accepted sighting differences without an adjustment).

## ADR-2026-10-26: Accounts use passwords and emailed codes

Status: Accepted

### Context

The frozen apps verified emails and reset passwords with links, and the web also offered magic-link sign-in. The study for slice 2 found that:
- Password reset only worked on the web, and didn't revoke mobile sessions.
- The apps and the server enforced different password rules.
- Links needed app links, universal links and fallback web pages on every platform.

### Decision

- **Sign-in is by email and password on every client.** There are no magic links. Sign in with Apple and Google come later, together.
- **Codes, not links:**
  - Verification and password reset use a **6-digit emailed code**, typed into the app. It lasts 15 minutes and allows 5 tries, and a new code cancels the old one.
  - A reset revokes every session of the account, and also verifies the email.
- **Passwords:** 12 to 128 Unicode code points after NFC, with no composition rules. The server also rejects common passwords. Clients check only the length, using the shared fixtures in `contracts/account-model/v1/`.
- **Verifying doesn't sign in.** The client signs in afterwards with the password it already has. One verify operation then serves mobile and the web.
- **Mobile token handling** (this refines ADR-2026-07-12):
  - Refresh uses a **required `Idempotency-Key`**, replacing the optional `request_id`.
  - Sign-out takes the refresh token, so it works without an access token.
  - Public operations never receive a bearer token.

### Consequences

- The same flow on three clients, with no deep-link setup and no web-only pages.
- The generated `phx.gen.auth` magic-link and confirmation-link code is replaced by code-based functions on the same tables.
- Account recovery depends on email access, as before.

### Evidence

- `contracts/api/paths/accounts.yaml`, `device_sessions.yaml`, `browser.yaml`
- `contracts/account-model/v1/`
- `docs/slices/02-accounts.md`

### Supersedes

The verification-link and request-id parts of the frozen implementation. ADR-2026-07-12 and ADR-2026-10-15 otherwise stand.

## ADR-2026-10-28: The change queue

Status: Proposed

### Context

The rebuild needs custom dhikrs, tags, goals and counts to reach every device of an account while phones stay offline-first. The frozen progress sync v1 (ADR-2026-07-16, ADR-2026-07-24) works, but it carries actors, contiguous sequences, transfer sessions, checksums, generations, incarnations, restore fences and a double write to JSONB plus legacy tables. Its tag coalescing also broke the old iOS client when a merge and the tag's use arrived in one batch. Nothing is released, so the rebuild can start from a smaller protocol. Slice 3b (`docs/slices/03b-custom-dhikrs-sync.md`) is its first user.

### Decision

- **The change queue replaces progress sync v1 for the rebuild.** Its contract is `contracts/sync/v1/` (schema, README, fixtures) and `contracts/api/paths/sync.yaml`:
  - `POST /api/v1/sync/commands` applies 1–100 commands in order;
  - `GET /api/v1/sync/changes?after&limit` returns each entity changed after a revision.
- **Entities** are whole JSON documents with a per-entity version and a final tombstone on delete. In 3b they are `custom_dhikr`, `user_tag` and `dhikr_personal` (a user's per-dhikr record, for now its tag IDs).
- **Commands** carry a UUIDv7 `command_id`, `put` or `delete`, and the `base_version` they were made on.
  - Each command gets one stored receipt: `applied`, `duplicate`, `conflict`, `merged`, `gone` or `rejected`.
  - Only a malformed envelope fails the whole batch; a bad command never blocks the queue.
- **Ordering.** The server serializes each account's batches on its revision row. Every applied command takes the next revision, and its cascades share it.
- **Tags.** Duplicate tag names merge: the server keeps the merged ID as an alias and rewrites later references itself.
- **Phones.** Each edit is queued with its command in one local transaction. Only a never-sent command may be replaced; a sent one is followed by a new command chained on `base_version + 1`.
- **Local profiles.** A phone keeps each account's data in its own local profile and never mixes two accounts.
  - Before the first sign-in there is one anonymous profile, which the first sign-in adds to the account or erases.
  - Signing out keeps the active profile; signing in as another account switches profiles and leaves the others, unsent commands included, untouched.
  - The engine sends only when the signed-in account owns the active profile, and every request names its account in `X-Awrad-Account` (`409 account_mismatch` otherwise).
- **The web** sends each edit as a one-command batch through the same endpoint, with its cookie session and CSRF. It has no queue.

What is kept from progress sync v1 and what is dropped:

| Old | New |
|---|---|
| Per-account revision under a row lock | **Keep** |
| Command IDs with idempotent receipts and a payload hash | **Keep** (IDs are UUIDv7) |
| Whole-document version checks | **Keep** |
| Tombstones | **Keep**. A delete is final; no restore, purge or fences |
| Actors, contiguous sequences, fork and adoption, incarnations | **Drop**. Receipts plus in-order batches are enough |
| Transfer sessions, checksums, generations | **Drop**. One "changes after revision N" feed |
| JSONB entities plus legacy tables (written twice) | **Drop**. One entity table |
| Separate tag-assignment entities, coalesced on receipt | **Change**. A per-dhikr personal record holds `tag_ids`; the server remembers merged tag IDs and rewrites references itself |
| Rewriting a command after it was sent | **Drop**. Only a never-sent command may be replaced |
| iOS diffing the whole database on every write | **Drop**. Each edit records its own command |
| Local data bound forever to the first account | **Change**. One local profile per account, plus the anonymous one before the first sign-in |

### Consequences

- **Simpler state.** The server keeps four things per account: a head revision, one entity table, receipts for 90 days, and tag aliases. Phones keep an outbox, known versions and a feed position per profile.
- **Reuse.** Goals (slice 4) and counts (slice 5) add entity types to the same queue. Counts will need their own merge rule on top of it, because whole-document versions would lose concurrent taps.
- **Behaviour is fixed by fixtures.** The server runs `sync_receipts` and `sync_changes_feed`; Android and iOS run `outbox_enqueue`, `apply_changes` and `profile_switch`; all four run `tag_name_normalization` and `custom_dhikr_validity`.
- **Stale references.** API STYLE §2, §8 and §9 still describe the frozen sync (resource endpoints for web writes, its transfer protocol, `basis_revision`). Once this ADR is accepted, they read as this queue.
- **Wire naming.** Custom dhikr references keep the catalog's camelCase `ayahStart` and `ayahEnd` until the catalog shape is migrated to snake_case.

### Evidence

- `docs/slices/03b-custom-dhikrs-sync.md`
- `contracts/sync/v1/` (README, `sync.schema.json`, fixtures)
- `contracts/api/paths/sync.yaml`
- `contracts/tools/check-sync-contract.mjs`

### Supersedes

ADR-2026-07-16 (Offline-first progress synchronization), ADR-2026-07-24 (Capability-gated dhikr tags in progress sync v1) and ADR-2026-09-04 (Browser companion actors) for the rebuild, once accepted. They stay accepted for the frozen apps.

## ADR-2026-10-28: Every generated ID is a UUIDv7

Status: Accepted

### Context

All IDs were random UUIDv4 (ADR-2026-07-13). Random keys scatter inserts across PostgreSQL indexes, which bloats them and slows writes as tables grow, and the tables that will grow most (count commands and progress, once sync lands) are still to be built. Nothing is released, so the generators can change now at no migration cost.

### Decision

- Every ID a project generates is a UUIDv7 (RFC 9562): entities created on clients or the server, installation IDs and `Idempotency-Key`s. The layout is fixed by `contracts/identity/v1/fixtures/uuid_v7_layout.json`, and each platform's generator takes its clock and random source as inputs so that fixture drives it.
- Validation accepts any lowercase, hyphenated UUID except nil and max (`uuid_format.json`). Ownership, not the version digit, protects data.
- Built-in content keeps its fixed IDs: the 113 built-in dhikr UUIDv4 constants and the deterministic wird IDs.
- An ID's timestamp is never used to order, expire or authorize anything; device clocks can be wrong, and sync orders by server revisions.

### Consequences

- Server indexes stay compact and IDs sort roughly by creation.
- Each platform carries a small generator, because java.util.UUID, Foundation's UUID and Ecto only generate v4.
- IDs reveal when they were made, which is acceptable because they aren't public.

### Evidence

- `contracts/identity/v1/` (README and fixtures)
- `contracts/api/STYLE.md` §4

### Supersedes

The UUIDv4 generation rule of ADR-2026-07-13. Its built-in identity pairs stay.

## ADR-2026-10-27: A dhikr is one foundational entity, from one shared catalog

Status: Proposed

### Context

Built-in dhikrs were hand-copied into Android, iOS and the server and drifted: the server text was truncated and untitled, Android's translations repeated titles, and only iOS had Arabic and Malayalam. Collections were code over eleven categories and grouped differently per platform. Benefits often had no source.

### Decision

- **One entity.** A dhikr is a single text with `kind` (`quran`, `dhikr`, `dua`, `salawat`, `name_of_allah`), Arabic, per-language title, transliteration and translation, optional search aliases, curated catalog tags, at most one audio recording, typed references (`quran`, `hadith`, `book`, `shaykh`, `other`) and virtues that must cite references. Sequences, occasions and recommended counts belong to wirds, practices and goals, never to the dhikr.
- **One catalog.** Built-ins live only in `contracts/dhikr-catalog/v1/catalog.json`. Each app generates its content from it at build time and fails on drift. Keys and UUIDs stay as in ADR-2026-07-13.
- **Collections are data.** A collection is an ordered list of dhikr keys, and a dhikr can be in several. Categories are dropped.
- **Naming.** A dhikr without an established name is titled by its opening words, never a number; local names are aliases.
- **Display language.** The app language selects the localized fields, falling back to English.
- **Custom dhikrs.** They use the same `$defs/dhikr` shape (slice 3b).

### Consequences

- A content fix is one catalog change and a rebuild; a later server-updatable catalog can reuse `contentRevision`.
- Unsourced benefits stay out until sourced.
- The frozen `progress-model` Asma-ul Husna file is superseded as a content source.

### Evidence

- `contracts/dhikr-catalog/v1/` (catalog, schema, `SOURCES.md`)
- `contracts/tools/check-dhikr-catalog.mjs`
- `docs/slices/03a-dhikr-catalog.md`

### Supersedes

None. Extends ADR-2026-07-13 (identity) and the canonical Asma-ul Husna collection ADR.

## ADR-2026-10-28: The mobile apps are complete without an account

Status: Accepted

### Context

The invariants already say the mobile apps work offline, and `CONTEXT.md` calls an account optional. But no decision said so outright. Each slice that adds accounts or sync could quietly add a sign-in gate, an onboarding step or a network call to a core flow.

### Decision

- **No sign-in gate.** A fresh mobile install opens straight into the app. No first-run step, core screen or core action needs an account, and nothing nags the user to create one.
- **Everything about practice works signed out and offline:** the dhikr library, custom dhikrs and tags, counting, goals, wird, history, practice settings and reminders. Built-in content ships in the app (ADR-2026-10-27).
- **Accounts and sync are opt-in.** Sign-in lives in settings, and features that need it may offer it where they're used. Signing in is the opt-in to sync: a signed-in account always syncs, and there's no separate sync switch. A feature may require an account only if it needs the server or other people, such as sync, the web companion or shared counters. Its brief says why.
- **Signed out means no server contact.** The app creates no anonymous or guest account and makes no API calls for core features.
- **Opting in or out never costs local data.** Signing in binds local data as ADR-2026-07-16 and ADR-2026-09-09 describe. Signing out leaves the app fully usable offline.
- The web app stays online-only and account-based (ADR-2026-10-15). It's a companion to an account, not a signed-out client.

### Consequences

- Mobile local storage is the primary store, and its data has no account owner until the user signs in. Sync layers on top and is never needed to read or write.
- Every mobile slice checks its main flows signed out with the network off.
- Without an account, data lives on one installation: uninstalling or losing the phone loses it. Backup to a file is a separate, later decision.

### Evidence

- `PRODUCT.md` (design principle 4)
- `CONTEXT.md` (Account)
- `docs/slice-playbook.md` (definition of done)

### Supersedes

None. Makes explicit the offline-first rule of ADR-2026-07-16 and the rebuild invariants.

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
