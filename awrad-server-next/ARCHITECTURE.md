# awrad-server-next — architecture

The Awrad JSON API, rebuilt contract-first to replace `awrad_server/` (root ADR-2026-10-14).
- **Stack:** Phoenix 1.8.15 on Elixir 1.20.4 / OTP 29, Ecto with Postgres 18, Bandit.
- **API only:** no HTML, assets, LiveView or static files.
- **Status:** the goal rules and the Hijri calendar (slices 1a and 1b), accounts (slice 2a): registration, email verification and password reset by emailed code, mobile device sessions, browser cookie sessions; and account settings (slice 2b): the session list, password and email changes, account deletion; the built-in dhikr catalog's identity (slice 3a); and the change queue for custom dhikrs and tags (slice 3b). Features arrive in slices (`../docs/rebuild-plan.md`).

## Boundaries

```mermaid
flowchart TD
  app["Awrad.Application<br/>(top-level: wires everything)"]
  web["AwradWeb<br/>router, controllers, plugs, Problem"]
  domain["Awrad<br/>contexts, schemas, Repo, Mailer"]
  goals["Awrad.Goals<br/>goal rules (pure)"]
  hijri["Awrad.Hijri<br/>Hijri calendar (pure)"]
  accounts["Awrad.Accounts<br/>accounts, sessions, codes"]
  idem["Awrad.Idempotency<br/>stored POST results"]
  dhikrs["Awrad.Dhikrs<br/>built-in catalog identity"]
  sync["Awrad.Sync<br/>change queue"]
  secrets["Awrad.Secrets<br/>keys (not re-exported)"]
  app --> web
  app --> domain
  web --> domain
  domain --- goals
  domain --- hijri
  domain --- accounts
  domain --- idem
  domain --- dhikrs
  domain --- sync
  sync --> dhikrs
  goals --> hijri
  accounts --> secrets
  idem --> secrets
```

| Boundary | May use | Exports |
|---|---|---|
| `Awrad.Application` (top level) | `Awrad`, `AwradWeb` | – |
| `AwradWeb` | `Awrad` | `Endpoint`, `Telemetry` |
| `Awrad` | nothing | `ID`, `Mailer`, `Pruner`, `Repo`, `UUIDv7`, and each context sub-boundary with its exports (`{Accounts, []}`, `{Dhikrs, []}`, `{Goals, []}`, `{Hijri, []}`, `{Idempotency, []}`, `{Sync, []}`) |
| `Awrad.Accounts` (sub-boundary) | `Awrad` (`Repo`, `Mailer`, `Gettext`), `Awrad.Secrets` | The `Awrad.Accounts` facade, `DeviceSession`, `EmailInput`, `Grant`, `RateLimiter`, `Scope`, `User` |
| `Awrad.Idempotency` (sub-boundary) | `Awrad`, `Awrad.Secrets` | The facade and `Record` |
| `Awrad.Secrets` (sub-boundary) | nothing | Its root module, to its siblings only: `Awrad` doesn't re-export it, so `AwradWeb` can't read secrets |
| `Awrad.Goals` (sub-boundary of `Awrad`) | `Awrad.Hijri` | `Rules` and the goal-model structs (`Goal`, `ActivePeriod`, `PausedRange`, `CountPolicy`, `Session`, `CountEntry`, `Standing`, `SessionStanding`, `DaysPerPeriodStanding`) |
| `Awrad.Hijri` (sub-boundary of `Awrad`) | nothing | `Corrections`, `HijriDate` (and the `Awrad.Hijri` facade) |
| `Awrad.Dhikrs` (sub-boundary of `Awrad`) | nothing | `Catalog`, `Catalog.Entry` |
| `Awrad.Sync` (sub-boundary of `Awrad`) | `Awrad` (`Repo`, `ID`, `UUIDv7`), `Awrad.Dhikrs` | Only the `Awrad.Sync` facade |

Boundary checks these rules at compile time, and `mix validate` fails on any violation (ADR 0001). Test support (`test/support/`) sits outside the production boundaries.

## Goal rules (slice 1)

`Awrad.Goals` evaluates goals for the web (slice 1 brief, decision 1): pure functions over plain structs, with no Ecto, database or HTTP. The structs mirror `contracts/goal-model/v1/goal-model.schema.json`, using `Date`, `DateTime` and integers.
- **`Awrad.Goals.Rules`** is the only entry point. It has one function per rule: `effective_practice_day/4`, `due?/3`, `standing/5`, `days_per_period/5`, `completed?/3` and `streak/5`. Every rule that can read Hijri dates (Hijri schedules, Hijri-month periods) takes the account's `Awrad.Hijri.Corrections` as its last argument.
- **Invalid goals can't be built.** `Awrad.Goals.Goal.new/1` is the only constructor: it returns `{:ok, goal}`, or `{:error, codes}` with the `goal_validity` error codes sorted alphabetically (`session_target_required`, `streak_threshold_value_required`, `target_required`). The rules assume a valid goal. There's no Ecto goal schema yet; when one arrives, its changeset applies the same check with the same codes.
- **Each rule has one home** under `lib/awrad/goals/rules/`: `EffectiveDay`, `Schedule`, `Requirement`, `DaysPerPeriod`, `Completion` and `Streak`. Two internal helpers, `Periods` (active-period bounds, week, month and Hijri-month windows) and `Counts` (count index, thresholds), are shared. None of these modules is exported.
- **Time zones** come from the compiled-in `tz` database, with no runtime updates (ADR 0003).
- **Schedules** include `{:hijri_month_days, days}` and `{:yearly, :gregorian | :hijri, ranges}` (slice 1b); periods are `:week`, `:month` and `:hijri_month`. Outside the Hijri table, Hijri schedules and Hijri-month periods are never due.
- **The fixtures are the spec.**
  - `test/support/fixtures.ex` (`Awrad.Fixtures.cases!/2`) loads `contracts/<model>/fixtures/<rule>.json`. It raises when the file is missing, is for another rule, or has no cases.
  - `test/support/fixtures/goal_model.ex` maps the fixture JSON to the structs and the results back. Rule fixtures' goals go through `Goal.new/1` (an invalid one raises); only `goal_validity` takes the raw `goal_shape`.
  - `test/awrad/goals/rules/*_test.exs` and `test/awrad/hijri/*_test.exs` generate one test per case, named by the case ID. `test/support/fixtures/hijri_calendar.ex` maps the Hijri fixtures, and the goal-model runners pass each case's optional `hijri_corrections`.
  - `test/awrad/shared_fixtures_test.exs` fails when a rule file in `contracts/goal-model/v1/fixtures/` or `contracts/hijri-calendar/v1/fixtures/` has no runner.

## Hijri calendar (slice 1b)

`Awrad.Hijri` gives the Hijri date of an effective practice day from the shared Umm al-Qura table (1400–1500 AH) and the account's month-start corrections (root ADR-2026-10-26). No Hijri library.
- **API:** `Awrad.Hijri.date/2` (`%HijriDate{year, month, day, month_length}` or `nil` outside the table), `month/2` (the adjusted month's Gregorian days) and `days/1` (the adjusted table's span).
- **Corrections:** `Awrad.Hijri.Corrections.new/1` is the only constructor besides `none/0`. It returns `{:ok, corrections}` or `{:error, codes}` with the `hijri_corrections_validity` codes sorted alphabetically (`duplicate_month`, `month_length_invalid`, `month_out_of_range`, `offset_out_of_range`), like `Goal.new/1`.
- **The table** is compiled into `Awrad.Hijri.Table` from a checked copy, `priv/hijri-calendar/umm-al-qura.json`. The release never reads `contracts/`; `test/awrad/shared_fixtures_test.exs` fails `mix validate` when the copy differs from the contracts file (ADR 0004).

## Built-in dhikr catalog (slice 3a)

`Awrad.Dhikrs.Catalog` holds the identity of the built-in dhikrs (`contracts/dhikr-catalog/v1/catalog.json`, ADR-2026-07-13), so later slices can check that a goal's built-in dhikr exists and know its kind. The change queue uses it to accept a `dhikr_personal` for a built-in dhikr. No API and no table: the apps bundle the content.
- **API:** `fetch_by_id/1` and `fetch_by_key/1` (`{:ok, %Catalog.Entry{id, key, kind, collections}}` or `:error`), `builtin?/1`, `kind/1` (`{:ok, :quran | :dhikr | :dua | :salawat | :name_of_allah}` or `:error`) and `content_revision/0`. IDs match exactly, in lowercase.
- **Compiled in** like the Hijri table (ADR 0004): from the checked copy `priv/dhikr-catalog/catalog.json` (`@external_resource`), keeping only key, id, kind and collection membership. Compilation fails on an unknown kind, a duplicate or non-UUIDv4 id, a duplicate key, or a collection listing an unknown key.
- **Checks:** `test/awrad/shared_fixtures_test.exs` fails when the copy differs from the contracts file (refresh with `cp ../contracts/dhikr-catalog/v1/catalog.json priv/dhikr-catalog/`); `test/awrad/dhikrs/catalog_test.exs` checks every key and id against `contracts/progress-model/v1/builtin-dhikrs.json`. The search fixtures are client-only.

## Change queue (slice 3b)

`Awrad.Sync` is the only entry point (`docs/slices/03b-custom-dhikrs-sync.md`, root ADR-2026-10-28 "The change queue", `contracts/sync/v1/`, server ADR 0009). It's how custom dhikrs, tags and per-dhikr records (`custom_dhikr`, `user_tag`, `dhikr_personal`) are written and read, by phones and the web alike; no other endpoint writes them.

- **API** (`AwradWeb.SyncController`, `contracts/api/paths/sync.yaml`):
  - `post_sync_commands` (`POST /api/v1/sync/commands`) and `list_sync_changes` (`GET /api/v1/sync/changes?after&limit`), behind `AccountAuth` (bearer, or cookie plus CSRF on the POST).
  - `X-Awrad-Account` must be the signed-in account: missing or not an ID is `400 malformed_request`, another account `409 account_mismatch`, before anything is read or written. `Idempotency-Key` is accepted and ignored.
  - The body must be `{"commands": [...]}` (`AwradWeb.Params`, `400` otherwise). `Awrad.Sync.Batch` checks the envelope: `422 validation_failed` with `batch_size_invalid` on `/commands` or `command_malformed` on `/commands/{i}[/member]`, nothing applied. `after` (0 to 2^53 - 1, default 0) and `limit` (1–500, default 200) are decimal integers, `400` otherwise.
  - Receipts and changes are built in their wire shape (string keys) and sent as they are (`AwradWeb.SyncJSON`); receipts are stored that way, so a duplicate replays its original exactly.
- **Applying a batch** (`Sync.Commands`, `Sync.Rules`): one transaction holding the account's `sync_heads` row `FOR UPDATE`. Each command, in order, is checked as the contract orders it (receipt store and payload hash; `dhikr_personal` delete; document; entity state; entity rules) and is either applied at `head + 1` with its cascades at the same revision, or answered without touching any entity. The `applied` receipt of a `user_tag` or `custom_dhikr` delete lists its cascades in `cascaded` (`{entity_type, entity_id, state, version, revision}`, ordered by type, then ID; `[]` when nothing cascaded); every other `applied` receipt has `cascaded: null`. Every receipt but `command_id_reused` is stored, `cascaded` included, so a duplicate replays it.
- **Documents** (`Sync.Documents`): 64 KB of compact JSON first (`document_too_large`), then the shape, by hand: `CustomDhikrDocument` (the `custom_dhikr_validity` codes, including `range` on `/references/N/ayah_end` for a Qur'an reference that ends before it starts), `TagName` (trim and collapse `White_Space`, NFC, full case folding with `:string.casefold/1`, 40 graphemes, 128 bytes; `normalized_name` must equal the server's fold, `mismatch`), and `{tag_ids}` (at most 20 distinct UUIDs). Field pointers get `/document` in front in a receipt.
- **Entity rules:** a tag create whose normalized name is taken merges (an alias row, no revision); a rename onto a taken name is `tag_name_taken`; at most 100 active tags and 1,000 active custom dhikrs; a `dhikr_personal` needs a built-in (`Catalog.builtin?/1`) or an active custom dhikr of the account (`dhikr_not_found`), and its tag IDs are rewritten (alias to tag, deleted dropped, repeats removed; never seen is `tag_not_found` at its index). Deleting a tag removes it from every `dhikr_personal`; deleting a custom dhikr deletes its `dhikr_personal`.
- **Feed** (`Sync.Feed`): one SQL statement per page (one snapshot): matching changes (revision above `after`, active only when `after` is 0) ordered by revision, `entity_type` (`COLLATE "C"`) and `entity_id`, up to the revision of the `limit`-th one; `has_more` when any match lies beyond it, `next_after` that revision or else the head.
- **Housekeeping:** `Awrad.Pruner` deletes receipts older than 90 days.
- **No rate limit yet.** The contract allows `429` on both operations, but no limit has been agreed; `RateLimiter` holds account-action limits only.
- **The fixtures are the spec** (`test/awrad/sync/`): `sync_receipts_test.exs` puts each case's state into the database for a fresh account (`test/support/fixtures/sync.ex`), runs the batch through `Awrad.Sync.apply_batch/2` and compares receipts, head, changes, aliases and stored receipts; `sync_changes_feed_test.exs`, `tag_name_normalization_test.exs` and `custom_dhikr_validity_test.exs` run the other server-side files. `server_limits_test.exs` covers what the fixtures leave out (1,000 custom dhikrs, 64 KB, 90 days). `test/awrad/shared_fixtures_test.exs` fails when a `sync/v1` fixture file has no runner; `outbox_enqueue`, `apply_changes` and `profile_switch` are exempt as phone-only.

## IDs

Root ADR-2026-10-28, `contracts/identity/v1/`. Every ID the server generates is a UUIDv7; the built-in dhikr IDs stay the catalog's UUIDv4 constants.
- **Generation** (`Awrad.UUIDv7`): `from_parts/2` lays out a Unix millisecond time and 10 random bytes as `uuid_v7_layout.json` fixes; `generate/0` feeds it `System.os_time(:millisecond)` and `:crypto.strong_rand_bytes(10)`.
- **Primary keys:** `Awrad.UUIDv7` is also an Ecto type (`:uuid`), and every schema declares `@primary_key {:id, Awrad.UUIDv7, autogenerate: true}`. Code that builds rows itself (registration's `insert_all`) calls `Awrad.UUIDv7.generate/0`. There are no database defaults. Foreign keys stay `:binary_id`, and casting or loading accepts any UUID.
- **Validation** (`Awrad.ID.valid?/1`): lowercase, hyphenated, any version, not nil or max, nothing trimmed (`uuid_format.json`). It's the one check for `Idempotency-Key` (`AwradWeb.Plugs.Idempotency`), installation IDs (`Input`), the `session_id` path parameter, session-list cursors and access-token claims. Never `Ecto.UUID.cast/1`, which accepts upper case and raw bytes.
- **Not IDs:** refresh tokens, browser session tokens and email codes are random secrets (`:crypto.strong_rand_bytes/1`), and `Idempotency-Key`s and installation IDs are the client's.
- **Never read the timestamp:** nothing orders, expires or authorizes by an ID's time.
- **Checks** (`test/awrad/identity/`): `uuid_v7_layout_test.exs` and `uuid_format_test.exs` run the fixture files case by case from `contracts/` (and `test/awrad/shared_fixtures_test.exs` fails when an identity rule has no runner); `generated_ids_test.exs` creates an account, a device session, a browser session and an idempotency record through the API, checks every row's stored ID has version nibble 7, and checks every schema's primary key is an autogenerated `Awrad.UUIDv7`.

## Accounts (slice 2a)

`Awrad.Accounts` is the only entry point (`docs/slices/02-accounts.md`, ADR-2026-07-12, ADR-2026-10-15, root ADR-2026-10-26). It takes request values as given, validates them, and returns `{:error, {:validation, [{field, code}]}}` with every field error.

- **Accounts** (`users`): `citext` email (≤ 160, case kept as typed, compared case-insensitively), Argon2id hash of the NFC-normalised password, `confirmed_at`.
  - Registering an email that's verified changes nothing and sends nothing.
  - Registering one that isn't verified yet replaces its password and sends a new code, so the inbox owner's latest registration wins (no pre-registration hijack).
  - Every path hashes the password first, so they cost the same.
- **Input rules** run the shared fixtures (`contracts/account-model/v1/`): `EmailInput` (trim the explicit whitespace set, shape check) and `PasswordPolicy` (12–128 code points after NFC, plus the server-only list `priv/accounts/common-passwords.txt` → `password_too_common`). A code must be six ASCII digits; clients normalise other scripts, so `email_code_input` is client-only (`test/awrad/shared_fixtures_test.exs` records why).
- **Email codes** (`email_codes`, `EmailCode`): 6 digits, stored as an HMAC bound to account and purpose (`verify_email`, `reset_password`), 15 minutes, 5 tries (a wrong try is kept even though the request fails), one live code per account and purpose. Verifying doesn't sign in.
- **Password reset** (`PasswordReset`), in one transaction: new password, email verified, every device session and refresh token revoked (`password_reset`), every browser session token deleted, other codes deleted.
- **Sign-in** (`Accounts.authenticate/3`): a wrong email or password is `invalid_credentials` with the same Argon2 work (`Argon2.no_user_verify/0`). A right password on an unverified account is `403 email_verification_required` and emails a fresh code (at most 5 an hour per account).
- **Device sessions** (`device_sessions`, `DeviceSessions`):
  - installation ID stored as an HMAC, device name, platform;
  - `last_seen_at` on refresh, and on authenticated requests at most every 5 minutes;
  - 30-day idle and 180-day absolute expiry, `revoked_at`/`revoke_reason` (`replaced`, `signed_out`, `password_reset`, `refresh_reuse`);
  - signing in again from the same installation replaces the account's session there (a partial unique index keeps one live session per account and installation).
- **Access tokens** (`AccessToken`, ADR 0005): HS256 JWTs, 15 minutes, `sub` + `sid`; every request re-checks the session and account in the database.
- **Refresh tokens** (`refresh_tokens`): 32 random bytes, SHA-256 stored, single use, rotated under a `FOR UPDATE` row lock. `Idempotency-Key` is required:
  - the same key within 60 seconds returns the same tokens (the successor grant is stored encrypted);
  - any other reuse of a spent token revokes the session (`refresh_reuse_detected`);
  - a key that already rotated another token is `idempotency_key_reused`;
  - a token that still worked when its account was deleted is `401 account_deleted` (ADR 0010).

  Sign-out takes the refresh token and always answers `204`.
- **Browser sessions** (`users_tokens`, `UserToken`, `BrowserSessions`, `AwradWeb.UserAuth`): `phx.gen.auth`'s session tokens and plugs, minus magic links and confirmation links. 14 days, remember-me (default on), session renewal on sign-in (new session ID and CSRF token). Cookies are `HttpOnly`, `SameSite=Lax`, and `Secure` in production. Changed for the session list (ADR 0008):
  - each row is one browser session, with a `name` parsed from `User-Agent` at sign-in (`AwradWeb.BrowserName`, "Firefox on Windows", `nil` when unknown) and `last_seen_at` (updated at most every 5 minutes);
  - reissue after 7 days replaces the token **in place**; the replaced token works for 60 more seconds (`previous_token`), and a request carrying it is moved onto the current one.
- **Emails** (`UserNotifier`): Swoosh, sent from a supervised task (`Awrad.TaskSupervisor`) so a response's timing doesn't reveal whether an email has an account. Localized from `Accept-Language` (en, ar, ml; default en) with `Awrad.Gettext` and key-based messages in `priv/gettext/<locale>/LC_MESSAGES/emails.po`: codes (`verify_email`, `reset_password`, `change_email`) and notices (`password_changed`, `email_taken`, `email_changed`, `account_deleted`). In development they land in the Swoosh mailbox at `/dev/mailbox` (JSON at `/dev/mailbox/json`).
- **Rate limits** (`RateLimiter`, ADR 0006): fixed windows in Postgres, per IP and per account, on every account action; `429` with `Retry-After`. Signed-in actions are limited by account ID: `password_check` (10 per account and 30 per IP in 15 minutes, shared by change password, request email change and delete), `request_email_change` (5 per account an hour), `confirm_email_change` (10 an hour).
- **Secrets** (`Awrad.Secrets`): `access_token_secret`, `hmac_pepper` and `encryption_secret`. Dev and test values are in `config/`. Production reads `AWRAD_ACCESS_TOKEN_SECRET`, `AWRAD_HMAC_PEPPER` and `AWRAD_ENCRYPTION_SECRET` (`config/runtime.exs` raises when one is missing); `AWRAD_MAIL_FROM` sets the sender.
- **Housekeeping:** `Awrad.Pruner` deletes expired idempotency results, email codes, rate-limit windows and deleted accounts' refresh-token hashes hourly (off in tests).

## Account settings (slice 2b)

`docs/slices/02-accounts.md` (slice 2b), `contracts/api/paths/account_settings.yaml`. Every operation takes either credential through `AccountAuth`, and ownership comes from the `Scope`, which names the caller's own session (`device_session` for a bearer token, `browser_session_id` for the cookie).

- **Session list** (`AccountSessions.list/3`): live device sessions (not revoked, within both expiries) and live browser sessions (`users_tokens` younger than 14 days), most recently used first by `(last_seen_at, id)` descending; `is_current` for the caller's own. A device session's ID is its `DeviceSession.id`; a browser's is its `users_tokens` row ID. Cursor: base64url of the last item's position, opaque to clients (`400 malformed_request` when it doesn't parse); default 50, maximum 100.
- **Revoke one** (`AccountSessions.revoke/2`): a live session of the account, of either kind, else `404 not_found` (another account's, ended, or not an ID by `Awrad.ID.valid?/1`). A device session is revoked (`revoked`, or `signed_out` for the caller's own); a browser session's row is deleted, and for the caller's own the cookies are cleared too.
- **Revoke others** (`revoke_others/1`): every session but the caller's, in one transaction.
- **Change password** (`Settings.change_password/4`): the current password (Argon2; out-of-bounds input costs a dummy verify and is `current_password_incorrect`), `PasswordPolicy` for the new one, both errors reported together. In one transaction: new hash, every other device session revoked (`password_changed`), every other browser token deleted, pending reset code deleted. The caller's device session or browser token is untouched, so its cookie and CSRF token keep working (ADR 0008). Then a `password_changed` notice.
- **Email change** (`Settings.request_email_change/4`, `confirm_email_change/3`):
  - request: current password, `EmailInput` (`email_invalid`), not the current email ignoring case (`email_unchanged`); the earlier `change_email` code is cancelled; if the address has an account (verified or not), that address gets an `email_taken` notice, otherwise a `change_email` code (`email_codes.new_email`, part of the HMAC). Same `202` either way.
  - confirm: the code (15 minutes, 5 tries) switches the email; `409 email_taken` if the address got an account meanwhile (checked, and the unique index as backstop; the code then stays usable); pending reset codes are deleted; the old address gets an `email_changed` notice naming the new one. Sessions stay.
- **Delete account** (`Settings.delete/3`): current password, then in one transaction the account's ID-keyed rate-limit windows, the hashes of its still-working refresh tokens into `deleted_account_refresh_tokens` (ADR 0010), and the `users` row, which cascades to `users_tokens`, `email_codes`, `device_sessions` (→ `refresh_tokens`), the account's `idempotency_records` and its `sync_*` rows. IP- and email-keyed windows stay until pruned (anti-abuse). A cookie caller's cookies are cleared; an `account_deleted` email goes to the address.
- **Idempotency:** `revoke_others`, `change_password`, `request_email_change` and `confirm_email_change` run the `:idempotent` pipeline after `AccountAuth`, so stored results are per account (ADR 0008). `delete_account` checks the key's shape only; a repeat after success is `401`.

### Client IP and proxies

Per-IP rate limits use `conn.remote_ip`, the TCP peer. That's correct when Bandit faces clients directly. **Behind a reverse proxy or load balancer, every client shares the proxy's address.** The deployment must then rewrite `remote_ip` from the proxy's trusted forwarding header before the router (for example the `remote_ip` plug, configured with the proxy's addresses), and never trust a forwarding header a client can set. There's no deployment yet; this is a prerequisite for the first one.

## Request path

`Endpoint`: `Plug.RequestId` (`x-request-id`) → `ApiResponseHeaders` (`Cache-Control: no-store` by default; `application/problem+json` on errors) → parsers → session → `Router`. The pipelines:

| Pipeline | Used by | Plugs |
|---|---|---|
| `:api` | Every `/api/v1` route | JSON only |
| `:idempotent` | Public account `POST`s, `create_device_session`, and the account settings `POST`s (after `:any_account`, so results are per account) | `Idempotency` (`mode: :replay`; ADR 0007, 0008) |
| `:any_account` | `get_current_account`, the account settings (`/api/v1/account/...`) and the change queue (`/api/v1/sync/...`) | `AccountAuth`: with an `Authorization` header, **only** the bearer token is checked; without one, **only** the cookie session, after the CSRF check on state-changing methods (`403 csrf_token_invalid`) |
| `:browser_session` | Browser routes | Cookie session (`_awrad_session`), CSRF check on state-changing methods (`X-CSRF-Token`, `403 csrf_token_invalid`), current user from the cookie only (ADR-2026-10-15) |
| `:idempotent_browser_sign_in` | `create_browser_session` | `Idempotency` (`mode: :rerun`: a cookie can't be replayed) |
| `:require_browser_user` | `delete_browser_session` | `401 unauthenticated` without a signed-in cookie session |

`refresh_device_session` and `sign_out_device_session` handle `Idempotency-Key` themselves.

**Neither credential crosses pipelines.** `BearerAuth` reads only the `Authorization` header; `UserAuth` reads only the session and remember-me cookies. `test/awrad_web/auth_pipeline_separation_test.exs` proves both directions: a valid cookie doesn't satisfy the bearer plug, a valid bearer token doesn't satisfy the cookie plug or sign a browser out, and a bad bearer token never falls back to a valid cookie.

`get_browser_csrf_token` works for any browser: a signed-out one gets an anonymous session cookie with its token, which `create_browser_session` then needs.

**Request bodies** (`AwradWeb.Params`) must be an `application/json` object with only the declared fields and JSON types. Anything else (an unknown or missing field, a wrong type, another content type) is `400 malformed_request`. Content checks are the domain's (`422 validation_failed`).

## Errors

Every error is an RFC 9457 problem (`contracts/api/STYLE.md` §7):

| Source | Shape | Sent by |
|---|---|---|
| Controllers | Problem with a stable `code` | `AwradWeb.Problem` (`send_code/2` for the catalogued codes, `validation_failed/2`, `validation_failed_at/2` for errors that carry their own JSON Pointer, `malformed/2`, `rate_limited/2`), mostly through `AwradWeb.FallbackController` |
| Phoenix itself (unmatched routes, parse errors, crashes) | Problem (`not_found`, `malformed_request`, `internal_error`), never internal details | `AwradWeb.ErrorJSON` |

## Contract tests (ADR 0002)

`test/support/contract.ex` loads `../contracts/api/openapi.bundled.json`.
- **`assert_conforms(conn, operation_id)`** checks:
  - the status is documented;
  - each declared header is present;
  - the content type matches;
  - the body validates against the response schema (JSON Schema 2020-12, via JSV).
- **`ContractCoverageTest`** fails when the router and the spec disagree in either direction.

## Data

Every table's primary key is a Postgres `uuid` that the server generates as a UUIDv7 (root ADR-2026-10-28; see [IDs](#ids)). The databases are `awrad_next_dev` and `awrad_next_test`, on the machine's Postgres 18 by default (`AWRAD_POSTGRES_PORT`, default 5432).

| Table | Holds |
|---|---|
| `users` | Accounts (`citext` email, unique) |
| `users_tokens` | Browser sessions (`phx.gen.auth` tokens), with name, `last_seen_at` and the token a reissue replaced |
| `email_codes` | One live code per account and purpose (HMAC); `new_email` for an email change |
| `device_sessions` | Mobile sessions; one live per account and installation |
| `refresh_tokens` | Single-use refresh tokens (SHA-256), rotation key and encrypted retry grant |
| `auth_rate_limits` | Fixed-window counters (HMAC subjects) |
| `idempotency_records` | Stored `Idempotency-Key` results (encrypted bodies), with the account for signed-in operations |
| `deleted_account_refresh_tokens` | SHA-256 of a deleted account's still-working refresh tokens, until they'd have expired (ADR 0010); no account reference |
| `sync_heads` | One per account: its head revision, locked for each batch |
| `sync_entities` | Every synced entity's latest state (`jsonb` document; tombstones kept), unique per account, type and ID |
| `sync_receipts` | Each command's first receipt and payload hash, 90 days |
| `sync_tag_aliases` | Merged tag IDs and the tag each became |

Every table holding account data references `users` with `ON DELETE CASCADE` (directly, or through `device_sessions` for `refresh_tokens`); `auth_rate_limits` holds only HMACs and is cleared by account ID on deletion, and `deleted_account_refresh_tokens` holds only hashes of random secrets.

API JSON is mapped field by field (`AwradWeb.AccountJSON`), never straight from schemas.

## Decisions

See [`docs/adr/`](docs/adr/README.md). Cross-project decisions are in the root [`DECISIONS.md`](../DECISIONS.md).
