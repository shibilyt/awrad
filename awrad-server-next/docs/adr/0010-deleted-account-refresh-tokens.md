# 0010: A deleted account's live refresh tokens answer `account_deleted`

Status: Accepted (2026-10-28)

## Context

Slice 3b's contract (`contracts/api/paths/device_sessions.yaml`, root ADR-2026-10-28 "The change queue") adds `401 account_deleted` to `refresh_device_session`: a phone whose account was deleted elsewhere learns it on its next refresh and offers to remove that local profile. But deleting an account (`Settings.delete/3`) deletes the `users` row, which cascades to `device_sessions` and `refresh_tokens`. Afterwards a refresh token is simply unknown, which is `refresh_token_invalid`.

## Decision

- **Deletion remembers the account's live refresh tokens, and nothing else.** In the deletion's transaction, before the cascade, `DeletedRefreshToken.remember/2` copies into `deleted_account_refresh_tokens` the SHA-256 (already what `refresh_tokens` stores) of each token that still works: unused, not revoked, not expired, on a live session. Each row expires when the token would have: the earliest of its own expiry and its session's idle and absolute expiries. No account ID, email, device or session is kept.
- **Refresh checks it only for an unknown token.** When `refresh_tokens` has no row for the hash and `deleted_account_refresh_tokens` has an unexpired one, the answer is `401 account_deleted`. Anything else is unchanged: a token that was already signed out, spent or expired at deletion stays `refresh_token_invalid`.
- `Awrad.Pruner` deletes the rows once they expire (at most 180 days, the absolute session lifetime).

## Consequences

- Only the holder of a once-valid token learns the account was deleted; the response reveals nothing to anyone else, as the contract requires.
- The table holds unlinkable hashes of random 32-byte secrets, so keeping it after deletion keeps no personal data.
- Access tokens of a deleted account stay `401 unauthenticated` until they expire (15 minutes); the phone then refreshes and gets `account_deleted`.
