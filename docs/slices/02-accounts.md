# Slice 02: Accounts

Status: 2a done 2026-10-26, CI green on `main`. 2b: contract drafted for review
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

Platforms: server ☑ · Android ☑ · iOS ☑ · web ☑ (2a)

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
  - `email_code_input`, 15 cases: Arabic-Indic, Eastern Arabic-Indic and fullwidth digits, spaces, hyphens.
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
| awrad-server-next | `Awrad.Accounts` (users, email codes, device sessions, refresh tokens, rate limits), `Awrad.Idempotency`, browser session JSON endpoints, emails in en/ar/ml; server ADRs 0005–0007 | `mix validate` (413 tests) | ☑ 2026-10-26 |
| awrad-android-next | Input rules + fixtures in `:core:domain`; new `:core:network` (OkHttp, hand-written classes, spec-example round trip); Keystore credential storage; `:feature:account`; ADRs 0005–0006 | Gradle validation | ☑ 2026-10-26 |
| awrad-ios-next | Input rules + fixtures in `AwradDomain`; network and session in `AwradData`; Keychain credentials; `FeatureAccount`; ADRs 0004–0005 | `scripts/validate` | ☑ 2026-10-26 |
| awrad-web-next | Input rules + fixtures; cookie session and CSRF in the API client; `src/features/account` and routes | `npm run validate` | ☑ 2026-10-26 |

## Integration evidence (step 6)

Run 2026-10-26 against `mix phx.server` on port 4100 (4000 was taken by an unrelated local app), with the emails read from the dev mailbox.

| Flow | Android (Pixel 8, API 36) | iOS (iPhone 16 Pro, 18.4) | Web (dev server + proxy) |
|---|---|---|---|
| Register, emailed code, automatic sign-in (en) | ☑ code typed with a space; 8-character password stopped on the client | – (system strong-password autofill blocks automation; covered by the Arabic run below) | ☑ code typed in Arabic-Indic digits |
| Sign in with a wrong password, then the right one (ar, RTL) | ☑ localized error, mirrored back arrow | – | ☑ `dir="rtl"`, localized error |
| Sign in to an unverified account → code screen → verify → signed in (ar) | – | ☑ Arabic email received (`Accept-Language`) | – |
| Sign in with an account made on another client | ☑ (web account) | ☑ (web account), device name "iPhone 16 Pro" | ☑ |
| Sign out revokes the server session | ☑ **after an app restart** (`signed_out`) | ☑ (`signed_out`) | ☑ |
| Password reset revokes every session | ☑ the Android session became `password_reset`, and the app showed "signed out" | – | ☑ reset on the web, then signed in with the new password |

Bugs found and fixed during integration (iOS, commit "iOS: fix two bugs found running slice 2a on the simulator"):
- **Crash on opening Account.** `AwradColors`' dynamic colour provider was inferred main-actor isolated, and SwiftUI resolves it off the main thread.
- **Dropped keystrokes.** Every edit went through `Task { await send }`. Edits now apply synchronously, and iOS `AGENTS.md` records the rule.

Follow-ups, not blocking:
- **Translations:** the ar and ml strings (app screens and server emails) were written by agents and need a native speaker's review.
- **iOS verify screen:** the email inside the Arabic sentence is shown as a blue link and broken across lines; it needs bidi isolation and no link detection. Digits mix Western and Arabic-Indic in the same screen.
- **iOS:** the navigation back button uses the system blue instead of the app's sage.
- **Web:** the language choice doesn't survive a full page reload.
- **Contract notes from the server agent:**
  - `create_browser_session` re-signs in rather than replaying a stored response for a repeated `Idempotency-Key`;
  - only successful results are stored for `Idempotency-Key`;
  - field codes `installation_id_invalid`, `device_name_invalid` and `platform_invalid` exist but aren't listed in the spec.

  STYLE §10 and the spec should say these.
- **Rate limits by IP** need a trusted proxy header before deployment (server `ARCHITECTURE.md`).

## Definition of done

- [x] In-scope 2a items built on the server, Android, iOS and the web.
- [x] Shared input rules have fixtures (48 cases), run by every client and the server (the server runs `email_input` and `password_policy`; `email_code_input` is client-only by design).
- [x] Every operation has spec examples, `assert_conforms` server tests, and client round-trip tests (mobile) or spec-example mocks (web).
- [x] `ci_ok` green on `main`: every job passed ([run 40342184662](https://github.com/shibilyt/awrad/actions/runs/40342184662)).
- [x] Main flows checked on running builds in English and Arabic (above).
- [x] All user-facing text in en, ar and ml, with translation checks passing (native review pending).
- [x] Decisions recorded: root ADR-2026-10-26 (accounts), server ADRs 0005–0007, Android ADRs 0005–0006, iOS ADRs 0004–0005.
- [x] Docs updated: `CONTEXT.md`, `COMMANDS.md`, each project's `ARCHITECTURE.md`.
- [x] Nothing changed in the frozen projects.

# Slice 2b

## Scope

- Device list (phones and browsers) and revoking one session.
- Signing out of all other devices.
- Changing the password while signed in.
- Changing the email.
- Deleting the account.

Screens on Android, iOS and the web. Out of scope: Sign in with Apple or Google (later), and data export (later, when there is synced data).

## Decisions (answered 2026-10-26)

1. **Deleting an account is immediate:**
   - The user re-enters the password.
   - The account and everything the server keeps for it are deleted, and every session ends.
   - Practice data on devices stays, and the apps keep working offline.
   - A confirmation email goes to the address. There's no undo. This meets App Store guideline 5.1.1(v).
2. **Changing the email:**
   - The user enters the password and the new address, and a 6-digit code goes to the **new** address. The switch happens only after the code.
   - The **old** address gets a notice.
   - Sessions stay signed in.
   - If the new address belongs to another account, it gets a notice instead of a code, so the response reveals nothing.
3. **The session list shows phones and browsers together,** with the current one marked. Any one can be revoked. "Sign out of all other devices" keeps the one in use.
4. **Password change is added:**
   - It needs the current password, and the account's email gets a notice.
   - It signs out every other device and browser, and keeps this one.

## Behaviour inventory

From slice 2a's study (rows 17–19): the frozen apps listed and revoked mobile sessions only, and revoke-all included the caller. Account deletion, password change and email change didn't exist for mobile; email change existed on the web only.

## Contract (step 4)

Drafted 2026-10-26, for review. All of these accept the mobile bearer token **or** the browser cookie (plus `X-CSRF-Token` for changes).

| Operation | Path | Result |
|---|---|---|
| `list_account_sessions` | `GET /api/v1/account/sessions` | `{items, next_cursor}` of `AccountSession` (`kind` device or browser, `name`, `platform`, `created_at`, `last_seen_at`, `is_current`) |
| `revoke_account_session` | `DELETE /api/v1/account/sessions/{session_id}` | `204`; `404` if not the account's or already ended |
| `revoke_other_account_sessions` | `POST /api/v1/account/sessions/revoke_others` | `204`; keeps the caller |
| `change_password` | `POST /api/v1/account/change_password` | `204`; other sessions end; email notice |
| `request_email_change` | `POST /api/v1/account/request_email_change` | `202`; code to the new address |
| `confirm_email_change` | `POST /api/v1/account/confirm_email_change` | `200` account with the new email; notice to the old one; `409 email_taken` if it was taken meanwhile |
| `delete_account` | `POST /api/v1/account/delete` | `204`; everything deleted, every session ended |

New error codes:
- `current_password_incorrect`, a field code on `/current_password`;
- `email_unchanged`, a field code on `/new_email`;
- `email_change_code_invalid`;
- `email_taken`.

Also documented now (2a follow-ups):
- **Idempotency** (STYLE §10): only successful results are stored, and browser sign-in runs again instead of replaying.
- **Device field codes:** `installation_id_invalid`, `device_name_invalid` and `platform_invalid`.

No new shared input rules: the forms reuse `email_input` and `password_policy`.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | Session listing across `device_sessions` and browser tokens (with a browser summary saved at sign-in), the account operations, the emails | `mix validate` | ☐ |
| awrad-android-next | Account screen: devices, change password, change email, delete | Gradle validation | ☐ |
| awrad-ios-next | The same | `scripts/validate` | ☐ |
| awrad-web-next | The same | `npm run validate` | ☐ |

