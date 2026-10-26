# Slice 02: Accounts

Status: In progress. Scope agreed 2026-10-26; contract and fixtures drafted for review
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 2
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)
Decided already: ADR-2026-07-12 (verified accounts, device sessions, rotating refresh tokens), ADR-2026-10-15 (browser cookie sessions), `contracts/api/STYLE.md` §7, §11, §12

## Goal

A person can create an Awrad account, sign in and sign out on Android, iOS and the web. Every device gets its own revocable session. The apps keep working fully without an account (offline-first); an account only adds online features.

## Scope

Proposed split, so each part finishes in days:

| | In scope |
|---|---|
| **2a** | Sign up and sign in by email, verification-first. Sign out. "Who am I" (`GET /me`). Mobile: device session, access token, rotating refresh. Web: cookie session and CSRF. Screens on Android, iOS and the web: email entry, verification, signed-in account screen with sign out. en, ar, ml |
| **2b** | Device list and revoke one device, sign out everywhere, delete account (an App Store requirement), change email |

| Out of scope | Where it goes |
|---|---|
| Moving local practice data into an account, practice-policy upload on first sign-in | Slice 4 (sync). In this slice, signing in and out never touches local data |
| Display name, avatar | The community slice, when something shows a name |
| Sign in with Apple or Google | A later slice (question 2) |
| Production email delivery and deployment | When `awrad-server-next` is first deployed. Dev uses Swoosh's local mailbox |

Platforms: server ☐ · Android ☐ · iOS ☐ · web ☐

## Decisions (answered 2026-10-26)

1. **Email and password.** No magic links, on any client.
2. **Verification and password reset by a 6-digit emailed code,** typed into the app. It's the same flow on Android, iOS and the web, with no app links or web pages. A code lasts 15 minutes and allows 5 tries; sending a new one cancels the old.
3. **Passwords:** 12 to 128 characters, counted as Unicode code points after NFC normalisation.
   - No composition rules.
   - The server also rejects common passwords from a blocklist.
   - Clients check only the length; the server is the authority.
4. **Sign in with Apple and Google:** a later slice, together.
5. **Split:** 2a (this brief's first part), then 2b.

## Behaviour inventory (step 2)

Studied 2026-10-26 from the frozen server, Android and iOS.

Abbreviations:
- `S:` = `awrad_server/lib/`
- `A:` = `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/`
- `I:` = `awrad-ios/awrad/awrad/`

| # | Behaviour | Today | Proposed decision | Evidence |
|---|---|---|---|---|
| 1 | Registration | Mobile: email and password; generic `202`; no tokens until verified. Web: email-only magic link | **Keep** verification-first and the generic response; method per question 1 | `S:awrad_server_web/controllers/api/auth_controller.ex:11-31` |
| 2 | Password rules | Server: 15–128 characters and a blocklist. Clients: 10+ with mixed character classes. They contradict each other | **Fix:** one rule, enforced only by the server (or none, per question 1) | `S:awrad_server/accounts/user.ex:91-108`, `A:ui/screens/auth/SignupScreen.kt:52-56` |
| 3 | Verification | Link (30 min) to an HTTPS page that redirects to `awrad://verify-email`; resend deletes older tokens; 60 s client cooldown | Per questions 1 and 4 | `S:…/email_verification_controller.ex:7-51` |
| 4 | Password reset | Email links to the **web** only. iOS has an unused handler; Android has no screen. Reset **doesn't revoke mobile sessions** | **Fix** or drop, per question 1. Any credential reset revokes every session | `S:awrad_server/accounts.ex:373-399` |
| 5 | Access token | HS256 JWT, 15 min, `sub`, `sid`, `jti`; the session is checked in the database on every request | **Keep** (ADR-2026-07-12) | `S:awrad_server/accounts/token.ex:16-43` |
| 6 | Refresh token | 32 random bytes, SHA-256 stored; transactional rotation; a retry with the same `request_id` within 60 s gets the same successor; other reuse revokes the session. A missing `request_id` silently disables retry protection | **Keep**; **fix:** `request_id` required | `token.ex:170-230, 296-303` |
| 7 | Device session | Installation-id hash (HMAC, peppered), device name, platform, `last_seen_at` (updated only on refresh), 30-day idle, 180-day absolute. Signing in again from the same installation replaces its session | **Keep**; `last_seen_at` on each authenticated request, throttled | `token.ex:45-77, 247-258` |
| 8 | Device name | Android `Build.MODEL`; iOS always "Apple device" | **Fix:** a real model name on both | `I:Core/AuthService.swift:613-615` |
| 9 | Token storage | Android: refresh token AES-GCM with a Keystore key, access token in memory only. iOS: Keychain, `AfterFirstUnlockThisDeviceOnly` | **Keep** | `A:data/preferences/EncryptedAuthTokenStorage.kt:59-78` |
| 10 | Sign out | Best-effort server call, then local tokens cleared; local data kept. **Android skips the server call after a restart** (no access token in memory) | **Fix:** sign out refreshes if needed, or revokes with the refresh token | `A:data/repository/AuthRepository.kt:188-199` |
| 11 | Refresh concurrency | Android: mutex in an OkHttp `Authenticator`. iOS: single-flight task. Both keep tokens on transient errors and clear them on 401/403 | **Keep** | `A:data/network/TokenAuthenticator.kt:21-58`, `I:Core/AuthService.swift:403-479` |
| 12 | Bearer token on public routes | Android attaches it to verify, forgot and reset | **Fix:** public operations never get a token | `A:data/network/AuthInterceptor.kt:34-40` |
| 13 | Error shapes | Four different JSON shapes in auth alone | **Fix:** RFC 9457 with `code` (STYLE.md §7) | `S:awrad_server_web/plugs/api_auth.ex:35-39` |
| 14 | Rate limits | Database fixed windows per IP and per account, on every auth action | **Keep** the limits, as `429` + `Retry-After` | `S:…/auth_rate_limiter.ex` |
| 15 | Password hashing | Argon2, legacy bcrypt rehash | **Keep** Argon2 if passwords stay; **drop** bcrypt (no legacy users) | `S:awrad_server/accounts/user.ex:110-155` |
| 16 | Browser session | `phx.gen.auth` cookie, 14 days, remember-me, `SameSite=Lax`, CSRF | **Keep** (ADR-2026-10-15) | `S:awrad_server_web/user_auth.ex:10-27` |
| 17 | Sessions list and revoke | `GET /sessions`, `DELETE /sessions/:id`, `DELETE /sessions` | **Keep**, in 2b | `auth_controller.ex:131-149` |
| 18 | Account deletion | Not implemented | **New**, in 2b (App Store guideline 5.1.1(v)) | – |
| 19 | Email change | Web only | **New** for every client, in 2b | `S:awrad_server_web/controllers/user_settings_controller.ex:12` |
| 20 | Guest use | "Continue as guest": everything works locally | **Keep**: an account is optional | `A:…/strings.xml:979-980` |
| 21 | Claiming local data at first sign-in | Android binds before saving tokens and can re-bind while nothing has synced; iOS saves tokens first and logs out on a mismatch | **Defer** to slice 4, with one rule for both | `A:data/sync/ProgressSyncRepository.kt:54-69`, `I:Core/ProgressSyncEngine.swift:278-360` |

## Domain and fixtures (step 3)

Drafted 2026-10-26, for review.
- **`CONTEXT.md`:** Account, Email code, Installation, Device session, Browser session.
- **`contracts/account-model/v1/`:** client-side input rules, run by every client and the server.
  - `email_input`, 21 cases: trimming and a basic shape check.
  - `password_policy`, 12 cases: code points after NFC, so emoji, combining marks and Arabic all count the same.
  - `email_code_input`, 14 cases: Arabic-Indic, Eastern Arabic-Indic and fullwidth digits, spaces, hyphens.
- **Root ADR-2026-10-26** (accounts): passwords plus emailed codes; refresh with a required `Idempotency-Key`; sign-out by refresh token.

## Contract (step 4)

Drafted 2026-10-26, for review. The spec bundles and lints clean.

| Operation | Path | Credential | Result |
|---|---|---|---|
| `register_account` | `POST /api/v1/accounts` | none | `202`, always (doesn't reveal existing emails) |
| `verify_account_email` | `POST /api/v1/accounts/verify_email` | none | `204`; doesn't sign in |
| `resend_verification_code` | `POST /api/v1/accounts/resend_verification_code` | none | `202`, always |
| `request_password_reset` | `POST /api/v1/accounts/request_password_reset` | none | `202`, always |
| `reset_password` | `POST /api/v1/accounts/reset_password` | none | `204`; revokes every session; verifies the email |
| `get_current_account` | `GET /api/v1/account` | bearer **or** cookie | `Account` |
| `create_device_session` | `POST /api/v1/device_sessions` | none | `201` grant: account, session, access token (15 min), refresh token |
| `refresh_device_session` | `POST /api/v1/device_sessions/refresh` | none (refresh token); `Idempotency-Key` required | `200` grant |
| `sign_out_device_session` | `POST /api/v1/device_sessions/sign_out` | none (refresh token) | `204`, always |
| `create_browser_session` | `POST /api/v1/browser/session` | anonymous cookie + CSRF | `200` account + new CSRF token |
| `delete_browser_session` | `DELETE /api/v1/browser/session` | cookie + CSRF | `204` |

Error codes clients handle:
- `validation_failed`, with field codes `email_invalid`, `password_too_short`, `password_too_long` and `password_too_common`;
- `verification_code_invalid` and `reset_code_invalid`;
- `invalid_credentials`;
- `email_verification_required`: the server also emails a fresh code, so the client goes to the code screen;
- `refresh_token_invalid` and `refresh_reuse_detected`;
- `csrf_token_invalid`, `unauthenticated` and `rate_limited`.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | `Awrad.Accounts`, mobile pipeline, JSON browser endpoints, migrations | `mix validate` | ☐ |
| awrad-android-next | `:core:network` auth, token storage, `:feature:account` | Gradle validation | ☐ |
| awrad-ios-next | The same in `AwradKit` | `scripts/validate` | ☐ |
| awrad-web-next | `src/features/account`, session handling | `npm run validate` | ☐ |

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| Sign up, verify, signed in (en) | ☐ | ☐ | ☐ | |
| Sign in, sign out (ar, RTL) | ☐ | ☐ | ☐ | |

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
