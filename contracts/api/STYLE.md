# Awrad API style guide

Rules for every HTTP and real-time endpoint of `awrad-server-next`, consumed by Android, iOS and web. The OpenAPI spec in this folder follows them, and a Spectral ruleset will enforce them in CI (rebuild plan 0.4).

Status: Accepted (2026-10-16), root ADR-2026-10-16. Choices this guide doesn't make are open: propose them in a pull request before anyone implements one.

The keywords **must**, **must not**, **should** and **may** are used in their RFC 2119 sense.

## 1. Versioning and paths

- All HTTP endpoints live under one prefix: **`/api/v1/`**. The whole API shares one major version.
- Real-time traffic uses Phoenix Channels at **`/socket/v1`** (§13).
- Paths use lowercase, plural nouns for collections, and snake_case for multi-word segments: `/api/v1/goals/{goal_id}/count_sessions`.
- Path parameters are named after the field they carry: `{goal_id}`, not `{id}`.
- Optional features a client may or may not support are negotiated with **capability flags** the client sends, as the sync protocol does today. They are not a reason for a new version.
- **Before the first public release**, v1 may change freely, with every consumer updated in the same slice. **After release**, changes to v1 must be additive (§14).

## 2. Resources and actions

- Standard methods on resources:

  | Method | Use |
  |---|---|
  | `GET` | Read; never changes state |
  | `POST` | Create in a collection, or run an action |
  | `PUT` | Replace a whole resource |
  | `DELETE` | Remove |

  `PATCH` is not used: writes replace whole documents and carry `expected_revision` (§9).
- A non-CRUD action is `POST /api/v1/{collection}/{id}/{action_name}`, with a verb in snake_case: `POST /api/v1/sessions/{session_id}/revoke`.
- **One write path for user progress.** Goals, counts, custom dhikr and tags change only through the progress command ledger:
  - Mobile sends batched commands from its offline outbox.
  - The online-only web app calls resource endpoints (for example `POST /api/v1/goals`). The server turns each call into the same ledger commands, as browser actors do today (ADR-2026-09-04).
  - No endpoint writes progress tables directly.
- Reads: the web uses resource read views; mobile uses sync snapshots and deltas. Both are projections of the same ledger.

## 3. JSON naming and shape

- Field names are **snake_case**. This includes the wird model, which currently uses camelCase and is migrated when it moves into the API.
- Enum values are **lowercase snake_case strings**: `"day_reset": "maghrib"`. Clients must tolerate unknown enum values by treating them as unsupported, not crashing.
- **No envelope** around a single resource: `GET /api/v1/goals/{goal_id}` returns the goal object itself.
- Collections return `{"items": [...], "next_cursor": "…"}` (§8).
- Response fields are **always present**. A missing value is `null`, never an omitted key, so generated clients get stable types.
- Requests may omit optional fields; the spec states each one's default.
- Booleans are named as statements: `is_archived`, `has_audio`. Avoid negatives like `not_hidden`.
- Don't send internal storage details: database row IDs, Ecto metadata, `inserted_at` for anything that isn't product data.

## 4. Identifiers

- Every ID is a lowercase, hyphenated UUID string.
- **User-owned entities** (goals, custom dhikr, tags, count commands) get **client-generated UUIDv4s**, so they can be created offline. The server validates the format and ownership, and never trusts an ID to decide who owns something.
- **Server-owned entities** (accounts, device sessions, browser installations) get **server-generated UUIDv4s**.
- **Built-in content** keeps its deterministic IDs from `contracts/` (ADR-2026-07-13): catalog keys plus UUIDs for built-in dhikr, and UUIDv3 structural IDs for wird parts and segments.
- Ownership always comes from the authenticated scope. Requests must not carry `user_id`.

## 5. Numbers

- **Counts are always whole numbers.** There are no partial counts, so no schema or client may represent a count as a fraction or float.
  - Totals and targets are non-negative integers.
  - Signed integers are used only for count deltas and corrections (for example `-3` to undo three taps).
- Counts, revisions and sequences are **plain JSON integers**: `"count": 34567`.
  - Schemas declare them `type: integer`, with `minimum: 0` unless signed, and `maximum: 9007199254740991` (2⁵³ − 1). That's the largest integer every client, including JavaScript, represents exactly, and it's far beyond any realistic total.
  - Clients store them as 64-bit integers (Kotlin `Long`, Swift `Int64`). The server rejects anything outside the declared range.
- Small bounded values (minutes, page sizes, `limit`) are plain JSON integers with tighter declared ranges.
- Coordinates (latitude, longitude) are the only fractional numbers.
- This replaces the integer-string encoding of the frozen sync contract (`contracts/progress-sync/v1`). The new progress-sync contract uses JSON integers.

## 6. Time

| Kind | Format | Name suffix | Example |
|---|---|---|---|
| Instant | RFC 3339 in UTC with `Z` | `_at` | `"created_at": "2026-10-16T08:00:00Z"` |
| Calendar day | `YYYY-MM-DD` | `_date` (`local_date` for practice days) | `"local_date": "2026-10-16"` |
| Time of day | `HH:MM`, 24-hour, local | `_time` | `"reminder_time": "06:15"` |
| Duration | Integer with the unit in the name | `_seconds`, `_minutes`, `_days` | `"lead_minutes": 30` |
| Timezone | IANA name | `timezone` | `"Asia/Kolkata"` |

- The **effective practice day** (`CONTEXT.md`) is computed by the client from the account practice policy and its device context. It's sent explicitly as `local_date`. The server checks that it's plausible for the device's timezone and policy, and never re-derives it from the server clock.

## 7. Errors (RFC 9457)

Every error response uses `Content-Type: application/problem+json`:

```json
{
  "type": "urn:awrad:problem:validation_failed",
  "title": "Request validation failed",
  "status": 422,
  "code": "validation_failed",
  "detail": "daily_target must be between 1 and 100000",
  "errors": [
    { "field": "/daily_target", "code": "out_of_range", "detail": "must be between 1 and 100000" }
  ]
}
```

| Member | Rule |
|---|---|
| `code` | **Required.** Stable snake_case. **Clients switch on this, and only this.** Listed per operation in the spec |
| `type` | `urn:awrad:problem:{code}`. A URN, so it doesn't depend on a domain that hasn't been chosen yet |
| `title`, `detail` | English, for logs and developers. **Never shown to users.** Clients map `code` to localized text in en, ar and ml |
| `status` | Same as the HTTP status |
| `errors` | Present for field validation: each entry has a `field` (a JSON Pointer into the request), a `code` and a `detail` |
| Extra members | Allowed when documented, for example `current` on a revision conflict (§9) |

Status codes:

| Status | Meaning |
|---|---|
| `400` | Malformed request (bad JSON, wrong types) |
| `401` | Not authenticated, or credential expired |
| `403` | Authenticated but not allowed, including unverified email (`email_verification_required`) |
| `404` | Doesn't exist, or isn't visible to this caller (don't reveal which) |
| `409` | Revision conflict or duplicate |
| `422` | Well-formed but fails validation |
| `429` | Rate limited |
| `5xx` | Server fault; never carries internal details |

Existing codes such as `email_verification_required`, `password_setup_required`, `refresh_reuse_detected` and `rate_limited` keep their meaning.

## 8. Pagination

- Lists are **cursor-paginated**: `?limit=50&cursor=…`. Responses carry `next_cursor`, which is `null` on the last page.
- Cursors are opaque strings. Clients must not parse or build them. Cursors may be signed and tied to the account.
- Every list documents its default and maximum `limit`. Offsets aren't supported.
- Sync snapshots and deltas keep their own paged transfer protocol (`contracts/progress-sync/`).

## 9. Concurrency

- Mutable shared resources carry `revision` (a JSON integer).
- A write sends `expected_revision`. If it's stale, the server returns `409` with `code: "revision_conflict"` and the current resource in `current`. The client applies it, and doesn't retry the stale write blindly.
- This is the same model the sync protocol uses (`basis_revision`), so there's one concurrency model across the API.

## 10. Idempotency

- Every non-idempotent `POST` accepts an **`Idempotency-Key`** header (a UUIDv4).
  - The server stores the result for 24 hours and replays it for a repeat with the same key and the same body.
  - The same key with a different body returns `422` with `code: "idempotency_key_reused"`.
- Clients must send a key on every retryable `POST`.
- `PUT` and `DELETE` are naturally idempotent.
- Sync commands keep their own `command_id`.

## 11. Authentication

- **Browsers:** Phoenix cookie session (`cookieAuth`, ADR-2026-10-15).
  - Every state-changing request sends the CSRF token in **`X-CSRF-Token`**.
  - The token comes from `GET /api/v1/browser/csrf_token`, which is only available to cookie sessions.
- **Mobile:** `Authorization: Bearer <access_token>` (`bearerAuth`), bound to a device session (ADR-2026-07-12).
- Each operation declares which schemes it accepts. A request presenting the wrong scheme for its pipeline is rejected with `401`.
- Account endpoints that could reveal whether an email exists (register, resend, forgot password) return the same generic response either way.

## 12. Rate limits, caching and headers

- Rate-limited responses are `429` with `Retry-After` (seconds) and `code: "rate_limited"`.
- **Every response sets `Cache-Control`:**
  - Authenticated responses default to `no-store`.
  - Public aggregates state their `max-age`.
- Request bodies are `application/json` (UTF-8). Unknown request fields are rejected with `400`, so client typos fail loudly.
- Every response carries `x-request-id`, and clients include it in bug reports.

## 13. Real time (Phoenix Channels)

- Socket: `/socket/v1`, authenticated the same way as HTTP: a cookie session for browsers, a token parameter for mobile.
- Topics: `{resource}:{id}` in snake_case, for example `collective_counter:{counter_id}`.
- Event names are snake_case nouns or past-tense verbs: `total_updated`, `counter_closed`.
- Payloads follow §3–§6. Counts are JSON integers.
- Clients join with their last known state, and must cope with missed or duplicate events by treating each payload as the latest snapshot, not as an increment.

## 14. Evolution after release

- **Allowed in v1:**
  - new endpoints;
  - new optional request fields;
  - new response fields;
  - new error codes on existing operations, which clients must handle generically;
  - new enum values, which clients treat as unsupported.
- **Breaking** (needs `/api/v2` or a coordinated, ADR-recorded change):
  - removing or renaming anything;
  - changing a type or meaning;
  - making an optional field required;
  - tightening validation on existing input.
- Deprecations use the `Deprecation` and `Sunset` response headers and are listed in the spec's operation description.

## 15. The spec

- **OpenAPI 3.1**, under `contracts/api/`, one file per area, with shared components (problem schema, ID, timestamp, cursor) defined once.
- The new API defines **its own schemas**, following this guide. The existing `contracts/*/v1/` folders describe the frozen apps (string counts, camelCase wird fields) and stay unchanged as reference. When a slice needs a shared model, it adds a new version (for example `contracts/progress-model/v2/`) that follows this guide. The API spec then references it instead of restating it.
- Every operation documents:
  - its auth schemes;
  - its error codes;
  - `Idempotency-Key` support where relevant;
  - its `Cache-Control` behaviour;
  - at least one request and response example.
- The spec is the source for generated clients (web) and contract tests (server, mobile). When the spec and the code disagree, the code is wrong.
