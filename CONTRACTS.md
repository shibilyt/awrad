# Cross-project contracts

This document records interfaces that cross project boundaries. It describes implemented behavior only unless a section is explicitly marked planned.

## Mobile authentication API

The authoritative route declarations are in `awrad_server/lib/awrad_server_web/router.ex`.

| Method | Path | Authentication | Current consumer |
|---|---|---|---|
| `POST` | `/api/auth/register` | Public | Android, iOS |
| `POST` | `/api/auth/login` | Public | Android, iOS |
| `POST` | `/api/auth/refresh` | Public; refresh token in JSON body | Android and iOS automatic refresh/retry |
| `POST` | `/api/auth/verify-email` | Public; one-time verification token | Android, iOS |
| `POST` | `/api/auth/verify-email/resend` | Public; generic response | Android, iOS verification flows |
| `POST` | `/api/auth/forgot-password` | Public | Android, iOS |
| `POST` | `/api/auth/reset-password` | Public; reset token and new password | iOS reset-completion flow |
| `DELETE` | `/api/auth/logout` | Bearer access token; refresh token in JSON body | Android, iOS |
| `GET` | `/api/auth/sessions` | Bearer access token | Mobile account security |
| `DELETE` | `/api/auth/sessions/:id` | Bearer access token; owned session only | Mobile account security |
| `DELETE` | `/api/auth/sessions` | Bearer access token | Mobile account security |

Registration returns a generic `202` and never issues credentials. Email verification creates the initial device session. Successful verification, verified-user login, and refresh return a user, device session, access token, and refresh token. JSON uses snake_case fields.

Unverified password login returns `403` with `error_code: "email_verification_required"`. Both clients treat registration and that structured login response as a pending authentication state: local/offline features remain available, but authentication success, account binding, progress synchronization, and protected API access wait until `POST /api/auth/verify-email` creates a session. Pending state records the normalized email, initiating mode (`signup` or `login`), flow origin (`onboarding` or account/community), and the resend deadline. Duplicate registration and resend responses remain generic to avoid account enumeration.

Confirmed web accounts may be passwordless because magic-link authentication is supported. When such an account attempts mobile password login, the API returns `403` with `error_code: "password_setup_required"`; clients must direct the user to the existing forgot-password flow. The generic `POST /api/auth/forgot-password` response is unchanged, and completing the reset establishes the first password while expiring the account's existing tokens.

## Email verification links and app association

New verification messages link to `GET /auth/mobile/verify-email/:token`. This browser landing is deliberately non-consuming: it attempts `awrad://verify-email?token=...` for installed-app fallback and presents an explicit browser action targeting the legacy `GET /auth/verify-email/:token` route. The legacy route remains consuming for previously issued messages and older clients. Mobile clients also accept configured-host HTTPS links for both paths and submit the token once through `POST /api/auth/verify-email`; invalid, expired, or replayed tokens leave the client unauthenticated and allow resend.

The landing response is browser-facing HTML in the public `:browser` pipeline. It is served with `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, a restrictive Content Security Policy, and no third-party resources. The public `:api` pipeline serves OS association JSON at:

- `GET /.well-known/apple-app-site-association`, claiming both verification paths for `<IOS_APP_TEAM_ID>.app.awrad.awrad`.
- `GET /.well-known/assetlinks.json`, claiming both paths for `app.awrad.awrad_dhikrgoalstracker` and every configured release signing SHA-256 fingerprint.

Production API startup requires `PHX_HOST` and `WEB_HOST`. `IOS_APP_TEAM_ID` and `ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS` are optional until the corresponding signed mobile builds are ready; omitting either produces an empty association file for that platform without affecting API access. `PHX_HOST` is the API/mobile host (`api.example.com`); `WEB_HOST` is the browser host (`example.com`). The iOS release build must supply `AWRAD_APP_LINK_HOST` with the same API host; Android derives its app-link host from `AWRAD_RELEASE_API_BASE_URL`. Local and test environments use explicit non-production association fixtures. Universal/app-link validation still requires a signed release build and deployed HTTPS host.

Contract owners:

- Server: `AwradServerWeb.Api.AuthController` and Accounts token modules.
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

## Healthcheck route

`GET /up` is public in the plain `:api` pipeline, performs no database access, and returns `{"status":"ok"}` with `Cache-Control: no-store`. It exists for the container healthcheck and reverse proxy; mobile clients must not depend on it. `config/prod.exs` excludes the path from `force_ssl` so plain-HTTP probes are not redirected.

## Community statistics API

`GET /api/community/stats` is public in the plain `:api` pipeline and returns cached, aggregate Community progress without user-identifying fields. Responses include `Cache-Control: public, max-age=300, stale-while-revalidate=600` and have this shape:

```json
{
  "as_of": "2026-07-19T16:00:00Z",
  "count_semantics": "current_canonical_net",
  "total_tracked_goals": 12,
  "approximate_total_counts": "34567",
  "approximate_dhikr_hours": 9.6,
  "seconds_per_count": 1,
  "daily_counts": [
    {"date": "2026-07-13", "approximate_count": "0"},
    {"date": "2026-07-14", "approximate_count": "1200"},
    {"date": "2026-07-15", "approximate_count": "4300"},
    {"date": "2026-07-16", "approximate_count": "5100"},
    {"date": "2026-07-17", "approximate_count": "7000"},
    {"date": "2026-07-18", "approximate_count": "8100"},
    {"date": "2026-07-19", "approximate_count": "8867"}
  ]
}
```

- `as_of` is a UTC RFC3339 timestamp. Count values are decimal integer strings so totals remain exact across JSON clients; hours are a JSON number rounded to one decimal.
- `total_tracked_goals` counts active canonical goal entity records, including goals whose goal document is paused or completed. Deleted and purged entities are omitted.
- Counts are current canonical net projections whose user, goal ID, and current entity incarnation all match. They are not lifetime gross activity and do not sum credits, consumptions, or count entries.
- Only progress synchronized to the API is represented; offline and not-yet-synced mobile activity is omitted.
- `daily_counts` always contains seven local-date buckets ending on the server's current UTC date, ordered oldest to newest and zero-filled. The trend uses client-recorded local dates; the all-time total also includes older and migrated historical buckets.
- `approximate_dhikr_hours` assumes exactly one second per count, exposed as `seconds_per_count: 1`; it is an estimate rather than measured session duration.

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

Progress synchronization v1 is implemented under `/api/sync/v1/progress` for
verified authenticated users. It includes command batches, snapshot/delta
transfer sessions and pages, actor acknowledgements, native durable outboxes,
tombstones, conservative first import, generation reconciliation, and entity
conflict resolution. Ownership is always derived from authenticated scope.

Run `./check-mobile-model-parity` at the root for schema/fixture validation, exact persisted-field classification, three-way built-in registry comparison, and the Android and iOS contract suites. A progress-model change is incomplete unless its schema, fixtures, native mappers, API representation, and tests change together.

## Bundled Wird model v1

`contracts/wird-model/v1/fixtures/dalail-al-khayrat.json` is the reviewed canonical devotional-content source. The generated Android and iOS assets must be byte-identical to it. `fixtures/behavior.json` locks the version-5 eight-part `PARTS_BY_WEEKDAY` schedule, 60-minute estimate, content hash, counts, and representative identities; `manifest.json` enumerates every generated structural identity.

Built-in Wird, part, and segment IDs use UUIDv3 with the same result as Java `UUID.nameUUIDFromBytes`, over UTF-8 `awrad-wird:<structural-path>`. Structural paths use the slug, `/part/<zero-based-index>`, and `/seg/<zero-based-index>`. Reordering reviewed content is therefore an identity migration, not a cosmetic edit.

Run `./scripts/generate_wird_model.py --check` to validate the source and reject stale platform assets. The contract governs bundled content and selection semantics only; it does not add API routes. iOS remaps an old random part/segment ID only when the complete normalized content signature has one unambiguous canonical match and the destination session identity remains unique. A partial, ambiguous, malformed, or conflicting in-progress session retains a hidden pinned legacy definition rather than guessing.

## Behavior model v1

`contracts/behavior-model/v1/fixtures/behavior-cases.json` is a deterministic cross-platform acceptance fixture. Its case families cover recurrence, effective-day resolution, count limits, slot selection, streaks, reminder plans, notification obligations, and Wird cadence. Notification-obligation cases lock target-policy continuity, deadline formulas, suppression, lifecycle separation, cumulative bounds, slot conjunction, and the global urgency toggle. Optional `tag_normalization` and `tag_filter` families lock baseline user-tag display/normalized uniqueness rules and AND filter composition for the custom-dhikr expansion; the exact Unicode White_Space / full Default Case Fold contract (ß↔SS, dotted capital I, NNBSP/figure space) lives in `contracts/behavior-model/v1/fixtures/tag-normalization-contract.json`. Native calculators adopt those sections when tag UI ships. It is product-behavior evidence rather than a persistence or network wire format.

`scripts/validate_behavior_fixtures.py` validates the fixture structure. Android `BehaviorFixtureParityTest` and iOS `BehaviorParityTests` consume it alongside platform-specific edge cases and execute native production semantics for every notification-obligation case. The root `./check-mobile-model-parity` command runs all three checks; a behavior change is incomplete when only one native calculator changes. See [`docs/notification-obligation-engine.md`](docs/notification-obligation-engine.md) for the runtime architecture and platform constraints.

## Product parity

Parity means equivalent user-visible rules, not identical source structure. When changing shared product semantics:

1. Identify the current behavior and tests on both mobile platforms.
2. Choose whether one platform is intentionally leading or both must change together.
3. Preserve platform-specific lifecycle and persistence constraints.
4. Record intentional differences in `MEMORY.md` or a decision entry.

High-risk parity areas include count caps, streak eligibility, day boundaries, recurring goals, reminder timing, prayer-relative slots, wird part selection, backup schema, deep links, and widget mutations.

## Progress synchronization v1

Account-bound synchronization is implemented end to end. The architecture and
operational bounds are documented in [`docs/progress-sync-architecture.md`](docs/progress-sync-architecture.md), and the executable transport/count fixtures live in `contracts/progress-sync/v1/`.

The accepted direction is local-first: native records remain usable offline, local writes create durable outbox commands, server revisions are commit ordered per account, positive progress synchronizes as idempotent credits, and decrement/reset consume only observed credit. Bootstrap and delta responses are immutable materialized transfer sessions. Custom dhikrs and goal definitions use whole-document optimistic concurrency; aggregate counts and automatic completion are projections rather than mutation authority.

Phoenix exposes the verified-auth `/api/sync/v1/progress` routes for ordered
commands, materialized snapshots/deltas, immutable transfer pages, and actor
acknowledgements. Android and iOS consume those routes through durable native
outboxes, canonical shadows, inbox staging, account binding, first import,
conflict retention, and cursor-safe apply transactions. The server owns entity
versions/incarnations, tombstones and purge fences, the immutable count ledger,
derived projections, transfer quotas, retention, and bounded maintenance.

Custom-dhikr documents may include an ordered, unique `categories` array. The
existing singular `category` remains the primary category and must equal the
first array item. New clients send both fields; the server defaults an omitted
array to `[category]` on create and preserves additional categories when an
older client updates only the singular field. This keeps older clients and
materialized API rows compatible while Android and iOS persist and expose the
full synchronized selection.

Authenticated foreground clients debounce mutation-triggered sync by two
seconds, poll with jitter at roughly 10 seconds on the counter and 60 seconds on
other screens, and apply bounded exponential backoff after failures. Clients
advertising `unchanged_delta` may receive a cursor-bearing `status: unchanged`
delta response without a materialized transfer; clients without the capability
continue to receive the original transfer-session representation.

Capability `dhikr_tags_v1` extends progress-sync v1 with `user_tag` and
`dhikr_tag_assignment` whole-document entities. Server validation owns tag-name
normalization (see
`contracts/behavior-model/v1/fixtures/tag-normalization-contract.json` for the
exact NFC display + Unicode Default Case Fold + White_Space contract), duplicate
normalized-name coalescing via accepted receipts whose
`canonical_effect.entity_id` is the surviving tag id, immutable assignment
`tag_id`/`dhikr_id` after create, restore-time ownership revalidation,
built-in/custom assignment targets, per-account/per-dhikr limits, and cascade
tombstones when a tag or custom dhikr is deleted. Transfer pages omit those
record kinds unless the client advertises `dhikr_tags_v1`, and non-capable
transfers exclude tag/assignment rows before the shared record limit so they
cannot crowd out non-tag progress. Documented dependency order is
`custom_dhikr`/`user_tag` (0), `dhikr_tag_assignment` (1), `goal` (2),
`count_projection` (3), `conflict` (4), tombstone/fence (5). Owned audio bytes
remain outside the sync contract. Clients that newly gain the capability must take one
capability-aware snapshot before resuming delta sync so earlier tag revisions
are not missed.

Protocol/server support for entity restore and explicit manual goal completion
or reopening is reserved for clients that expose those actions. The current
native apps synchronize deletion and automatic count-driven lifecycle state but
do not yet expose restore or manual lifecycle controls as end-to-end user
actions. Audio cache state and Wird synchronization remain outside
progress-sync v1.
