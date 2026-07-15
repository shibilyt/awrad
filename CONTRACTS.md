# Cross-project contracts

This document records interfaces that cross project boundaries. It describes implemented behavior only unless a section is explicitly marked planned.

## Mobile authentication API

The authoritative route declarations are in `awrad_api/lib/awrad_api_web/router.ex`.

| Method | Path | Authentication | Current consumer |
|---|---|---|---|
| `POST` | `/api/auth/register` | Public | Android, iOS |
| `POST` | `/api/auth/login` | Public | Android, iOS |
| `POST` | `/api/auth/refresh` | Public; refresh token in JSON body | Android and iOS automatic refresh/retry |
| `POST` | `/api/auth/verify-email` | Public; one-time verification token | Android, iOS |
| `POST` | `/api/auth/verify-email/resend` | Public; generic response | iOS verification flow |
| `POST` | `/api/auth/forgot-password` | Public | Android, iOS |
| `POST` | `/api/auth/reset-password` | Public; reset token and new password | iOS reset-completion flow |
| `DELETE` | `/api/auth/logout` | Bearer access token; refresh token in JSON body | Android, iOS |
| `GET` | `/api/auth/sessions` | Bearer access token | Mobile account security |
| `DELETE` | `/api/auth/sessions/:id` | Bearer access token; owned session only | Mobile account security |
| `DELETE` | `/api/auth/sessions` | Bearer access token | Mobile account security |

Registration returns a generic `202` and never issues credentials. Email verification creates the initial device session. Successful verification, verified-user login, and refresh return a user, device session, access token, and refresh token. JSON uses snake_case fields.

Contract owners:

- Server: `AwradApiWeb.Api.AuthController` and Accounts token modules.
- Android: `AwradApiService`, `AuthRepository`, `TokenAuthenticator`, and token storage.
- iOS: `AuthService` request/response types and storage.

Any request/response or status-code change requires server tests and review of both consumers. Add compatibility behavior before removing or renaming a field used by a released client.

## Token lifecycle

- Browser authentication uses Phoenix session cookies and `current_scope`.
- Mobile authentication uses 15-minute, session-bound bearer JWTs and rotating database-backed refresh tokens.
- Refresh rotation is transactional. Repeating the same request ID briefly returns the same successor; reuse with another request ID revokes the device session.
- Device sessions expire after 30 idle days or 180 absolute days and can be revoked individually or together.
- Password registration uses Argon2id and email verification. Existing bcrypt hashes upgrade after successful password login.
- Logout revokes the bearer token's current session and cannot revoke another user's session.
- Secrets and production token configuration belong in runtime environment configuration, never in clients or committed files.

Android automatically refreshes after an authentication failure through its OkHttp authenticator. iOS uses a single-flight refresh task in `AuthService`: concurrent 401 responses share one rotation, retry once with the successor access token, preserve credentials after transient failures, and clear them after definitive revocation/reuse failures. The focused native auth suites lock both paths.

## API base URLs

- Android debug default: `http://10.0.2.2:4000/` for an emulator talking to the host.
- Android release: explicit `AWRAD_RELEASE_API_BASE_URL`; HTTPS is required.
- iOS development default: `http://127.0.0.1:4000/`; `AuthService` accepts an injected base URL.
- Phoenix local default: `http://localhost:4000`.

Base URLs must retain a trailing-slash-safe shape because clients resolve relative endpoint paths. Physical devices need a reachable LAN or deployed address.

## Local persistence ownership

Android and iOS own their local product state independently:

- Android uses Room entities, DAOs, repositories, and migrations.
- iOS uses an App Group SwiftData store behind repository protocols and `AwradStore`; snapshot v5 is supported as migration/backup input, and widgets use a compact projection plus relational App Intent mutations.
- The API uses Ecto/PostgreSQL for server-owned records.

Dhikr, Goal, GoalSlot, GoalReminder, GoalRecurrence, CountPolicy, and CountEntry have a stable native-model contract in `contracts/progress-model/v1/`. Bundled Wird definitions have a separate content and structural-identity contract in `contracts/wird-model/v1/`; persisted Wird/session records and synchronization remain outside that content contract. Do not serialize persistence records directly; use the versioned Android/iOS DTO mappers and authenticated API context boundary.

## Progress model v1 and UUID identity

`contracts/progress-model/v1/progress-model.schema.json` is the canonical JSON shape. `fixtures/progress-state.json` is the native round-trip golden state, `fixtures/coverage.json` exhausts enum, policy, lifecycle, archived-slot, dhikr, and signed 64-bit edge cases, and `field-ownership.json` classifies shared, local-only, and derived state.

Identity and representation rules:

- Dhikr, Goal, GoalSlot, GoalReminder, and CountEntry IDs are UUIDv4. Mobile clients assign IDs before persistence; the API validates client UUIDv4 IDs at its context boundary.
- The 113 built-ins use the immutable catalog-key/UUID pairs in `builtin-dhikrs.json`: the original 13 dhikrs plus Allah and the traditional 99-name Asma-ul Husna sequence. Content is reconciled only by UUID or catalog key. Titles, Arabic, transliteration, sort order, and audio URLs are not identity. Retired keys and UUIDs remain reserved.
- `asma-ul-husna.json` is the canonical ordered content source for the `asma_ul_husna` category. Its 100 native seeds are generated for Android and iOS, copied into Phoenix `priv`, and currently use the invocation variant (`Ya Allah`, `Ya Rahman`, and so on). `sort_order` is shared progress data and fixes category order independently of localized or alphabetical display. The seeds ship without audio metadata until audio is uploaded. Audio or collection-variant changes must retain the same catalog keys and UUIDs.
- GoalSlot ownership and CountEntry slot ownership are non-null. GoalReminder slot ownership is optional.
- A paused goal has `is_active=false` and no `completed_at`. A goal is completed only when `completed_at` is present.
- Archived slots remain in the single `slots` collection with `is_active=false`; active and archived collections are derived views.
- `total_completed_count` is derived from CountEntry records. The native apps may retain a transactionally refreshed cache, but it is local-only and never synchronization authority.
- Dates use `YYYY-MM-DD`. Timestamps use UTC RFC3339. Counts use Android `Long`, iOS `Int64`, and PostgreSQL `bigint`.
- Enum wire values are canonical snake_case. Threshold selectors are `any_positive`, `minimum`, `target`, `maximum`, or `{ "type": "custom", "count": n }`.
- Canonical defaults are declared in the schema and `fixtures/coverage.json`: goals default to per-due-date, active, incomplete, `never` completion; recurrence defaults to daily Gregorian; count thresholds default to target with allow-over-target caps.

Android stores UUIDs as Room `TEXT`; schema version 5 deliberately resets identity-dependent development product tables before reseeding canonical dhikrs, and version 6 adds persisted dhikr ordering. The former iOS snapshot version 5 reset pre-v5 development snapshots and decodes missing dhikr sort order as zero. Current iOS installs migrate a validated version-5 snapshot into SwiftData without changing semantic IDs or values; pre-v5 imports remain unsupported and Keychain credentials are unaffected. Phoenix retains `:binary_id` storage and advances through a forward migration; authenticated scope, not payload ownership fields, supplies `user_id`.

There are no progress synchronization routes in v1. Outboxes, operation IDs, tombstones, ownership binding, reconciliation, and conflict resolution remain deferred.

Run `./check-mobile-model-parity` at the root for schema/fixture validation, exact persisted-field classification, three-way built-in registry comparison, and the Android and iOS contract suites. A progress-model change is incomplete unless its schema, fixtures, native mappers, API representation, and tests change together.

## Bundled Wird model v1

`contracts/wird-model/v1/fixtures/dalail-al-khayrat.json` is the reviewed canonical devotional-content source. The generated Android and iOS assets must be byte-identical to it. `fixtures/behavior.json` locks the version-5 eight-part `PARTS_BY_WEEKDAY` schedule, 60-minute estimate, content hash, counts, and representative identities; `manifest.json` enumerates every generated structural identity.

Built-in Wird, part, and segment IDs use UUIDv3 with the same result as Java `UUID.nameUUIDFromBytes`, over UTF-8 `awrad-wird:<structural-path>`. Structural paths use the slug, `/part/<zero-based-index>`, and `/seg/<zero-based-index>`. Reordering reviewed content is therefore an identity migration, not a cosmetic edit.

Run `./scripts/generate_wird_model.py --check` to validate the source and reject stale platform assets. The contract governs bundled content and selection semantics only; it does not add API routes. iOS remaps an old random part/segment ID only when the complete normalized content signature has one unambiguous canonical match and the destination session identity remains unique. A partial, ambiguous, malformed, or conflicting in-progress session retains a hidden pinned legacy definition rather than guessing.

## Behavior model v1

`contracts/behavior-model/v1/fixtures/behavior-cases.json` is a deterministic cross-platform acceptance fixture. Its case families cover recurrence, effective-day resolution, count limits, slot selection, streaks, reminder plans, and Wird cadence. It is product-behavior evidence rather than a persistence or network wire format.

`scripts/validate_behavior_fixtures.py` validates the fixture structure. Android `BehaviorFixtureParityTest` and iOS `BehaviorParityTests` consume it alongside platform-specific edge cases. The root `./check-mobile-model-parity` command runs all three checks; a behavior change is incomplete when only one native calculator changes.

## Product parity

Parity means equivalent user-visible rules, not identical source structure. When changing shared product semantics:

1. Identify the current behavior and tests on both mobile platforms.
2. Choose whether one platform is intentionally leading or both must change together.
3. Preserve platform-specific lifecycle and persistence constraints.
4. Record intentional differences in `MEMORY.md` or a decision entry.

High-risk parity areas include count caps, streak eligibility, day boundaries, recurring goals, reminder timing, prayer-relative slots, wird part selection, backup schema, deep links, and widget mutations.

## Planned: offline-first synchronization

General account-bound synchronization and online-library imports are not implemented end to end. The intended direction is local-first: local records remain usable offline, server association is explicit, imported library content is a snapshot, and audio download/cache state is separate from logical content state.

Stable UUIDv4 identity and the native progress model are now locked by ADR-2026-07-13. Before implementing routes, add a follow-up decision for immutable account binding, revisions, tombstones/deletion, conflict policy, initial upload/download behavior, and compatibility with existing local data. Do not infer those rules from the current Ecto schemas alone.
