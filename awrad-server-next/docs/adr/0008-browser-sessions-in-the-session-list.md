# 0008: Browser sessions in the account's session list, and per-account idempotency results

Status: Accepted (2026-10-26). Amends 0007 (uniqueness of stored results).

## Context

Slice 2b lists every place an account is signed in, phones and browsers together (`list_account_sessions`, `AccountSession`), and lets any one be revoked. Browser sessions are `phx.gen.auth` session tokens (`users_tokens`, ADR-2026-10-15), which had no name and no `last_seen_at`. Worse, `phx.gen.auth` reissues a token older than 7 days by **inserting a new row** and leaving the old one valid until it expires: a browser would show up twice after a week, and revoking the listed row would leave the older token working.

The signed-in account operations (`change_password`, `confirm_email_change`, …) also take an `Idempotency-Key`. ADR 0007 keyed stored results by operation and key only, so another account sending the same key would get the first account's stored response (for `confirm_email_change`, its email).

## Decision

- **A browser session is its `users_tokens` row.** Its ID is the `AccountSession` ID; it gets `name` and `last_seen_at` columns.
  - `name` is a short "Browser on System" summary parsed from `User-Agent` at sign-in by a small hand-written parser (`AwradWeb.BrowserName`), `null` when the browser can't be told. No user-agent library: the label is cosmetic and never used for a decision.
  - `last_seen_at` is updated on authenticated requests at most every 5 minutes, like device sessions.
  - `created_at` is the sign-in time (`authenticated_at`), which survives reissues.
- **Reissue replaces the token in place.** The row keeps its ID, name and sign-in time; `token` and `inserted_at` are renewed; the replaced token moves to `previous_token` and is accepted for 60 seconds (`previous_token_valid_until`), so requests already in flight with the old cookie don't sign the browser out. A request that arrives with the replaced token is moved onto the current one (its session cookie is rewritten). Two concurrent reissues both end up with the first one's token.
- **Changing the password doesn't rotate the caller's browser token.** The contract answers `204` with no cookie semantics; rotating would sign the browser out whenever the response is lost, and a replayed `204` couldn't carry the new cookie. The caller's session, cookie and CSRF token stay as they are; every other session ends.
- **Stored idempotency results belong to the account.** `idempotency_records.user_id` references `users` (`ON DELETE CASCADE`); the unique key is operation, key and account (`NULLS NOT DISTINCT`). The plug runs after `AccountAuth` on signed-in routes. `delete_account` checks the key's shape only: there's no account left to store a result for, and a repeat after success is `401`.

## Consequences

- One list query per kind, merged in memory by `(last_seen_at, id)` descending, with an opaque cursor of the last item's position. An account rarely has more than a page.
- Sign-out and revocation delete the row, so both the current and the replaced token stop working at once.
- Deleting an account removes its idempotency results with it; public operations' results (no account) are unchanged.
