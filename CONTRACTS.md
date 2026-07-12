# Cross-project contracts

This document records interfaces that cross project boundaries. It describes implemented behavior only unless a section is explicitly marked planned.

## Mobile authentication API

The authoritative route declarations are in `awrad_api/lib/awrad_api_web/router.ex`.

| Method | Path | Authentication | Current consumer |
|---|---|---|---|
| `POST` | `/api/auth/register` | Public | Android, iOS |
| `POST` | `/api/auth/login` | Public | Android, iOS |
| `POST` | `/api/auth/refresh` | Public; refresh token in JSON body | Android automatic token authenticator |
| `POST` | `/api/auth/forgot-password` | Public | Android, iOS |
| `POST` | `/api/auth/reset-password` | Public; reset token and new password | Reset flow/API surface |
| `DELETE` | `/api/auth/logout` | Bearer access token; refresh token in JSON body | Android, iOS |

Registration and login return a user object plus `access_token` and `refresh_token`. Refresh returns a replacement token pair. JSON uses snake_case fields, which is reflected in both mobile DTO sets.

Contract owners:

- Server: `AwradApiWeb.Api.AuthController` and Accounts token modules.
- Android: `AwradApiService`, `AuthRepository`, `TokenAuthenticator`, and token storage.
- iOS: `AuthService` request/response types and storage.

Any request/response or status-code change requires server tests and review of both consumers. Add compatibility behavior before removing or renaming a field used by a released client.

## Token lifecycle

- Browser authentication uses Phoenix session cookies and `current_scope`.
- Mobile authentication uses short-lived bearer JWT access tokens and rotating database-backed refresh tokens.
- Refresh rotation invalidates the consumed refresh token and returns a new pair.
- Logout revokes the supplied refresh token; the API may also revoke all refresh tokens for the authenticated user when no token is supplied.
- Secrets and production token configuration belong in runtime environment configuration, never in clients or committed files.

Android automatically refreshes after an authentication failure through its OkHttp authenticator. iOS currently stores and sends tokens but does not implement the same automatic refresh retry path; do not claim parity until code and tests establish it.

## API base URLs

- Android debug default: `http://10.0.2.2:4000/` for an emulator talking to the host.
- Android release: explicit `AWRAD_RELEASE_API_BASE_URL`; HTTPS is required.
- iOS development default: `http://127.0.0.1:4000/`; `AuthService` accepts an injected base URL.
- Phoenix local default: `http://localhost:4000`.

Base URLs must retain a trailing-slash-safe shape because clients resolve relative endpoint paths. Physical devices need a reachable LAN or deployed address.

## Local persistence ownership

Android and iOS own their local product state independently:

- Android uses Room entities, DAOs, repositories, and migrations.
- iOS uses Codable domain snapshots coordinated by `AwradStore`, with selected shared widget state/mutations.
- The API uses Ecto/PostgreSQL for server-owned records.

Matching names such as Goal, CountEntry, Dhikr, or Wird do not imply a stable wire format. Do not serialize local models directly into an API contract without defining ownership, IDs, versions, timestamps, and conflict behavior.

## Product parity

Parity means equivalent user-visible rules, not identical source structure. When changing shared product semantics:

1. Identify the current behavior and tests on both mobile platforms.
2. Choose whether one platform is intentionally leading or both must change together.
3. Preserve platform-specific lifecycle and persistence constraints.
4. Record intentional differences in `MEMORY.md` or a decision entry.

High-risk parity areas include count caps, streak eligibility, day boundaries, recurring goals, reminder timing, prayer-relative slots, wird part selection, backup schema, deep links, and widget mutations.

## Planned: offline-first synchronization

General account-bound synchronization and online-library imports are not implemented end to end. The intended direction is local-first: local records remain usable offline, server association is explicit, imported library content is a snapshot, and audio download/cache state is separate from logical content state.

Before implementing sync, create a cross-project decision that locks identifier ownership, immutable account binding, revisions, tombstones/deletion, conflict policy, initial upload/download behavior, and compatibility with existing local data. Do not infer those rules from the current Ecto schemas alone.
