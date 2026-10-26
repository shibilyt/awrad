# 0007: Idempotency-Key results are stored in Postgres

Status: Accepted (2026-10-26)

## Context

`contracts/api/STYLE.md` §10: every non-idempotent `POST` accepts an `Idempotency-Key`; the server stores the result for 24 hours and replays it for the same key and body, and the same key with another body is `422 idempotency_key_reused`. `refresh_device_session` requires the key and gives it stricter semantics (root ADR-2026-10-26). Some results carry secrets: `create_device_session` returns an access and a refresh token.

## Decision

- **A generic plug, `AwradWeb.Plugs.Idempotency`, over one Postgres table, `idempotency_records`** (`Awrad.Idempotency`). One row per operation (method and path) and key, unique, kept 24 hours.
- A row holds the response status and content type, the response body **encrypted** (`Awrad.Secrets.encrypt/2`, AES-GCM), and an **HMAC fingerprint** of the parsed body, so a stored password can't be recovered or guessed offline from the table.
- **Only successful (2xx) results are stored.** After an error, the same key runs again: a client retrying a validation or rate-limit failure isn't stuck with it.
- **The first stored result wins** (`ON CONFLICT DO NOTHING`). Two concurrent first requests with the same key may both run; that's harmless for these operations (a second code cancels the first; a second sign-in replaces the first session).
- **Browser sign-in re-runs** (`mode: :rerun`): its result is a session cookie, which can't be replayed from storage. The same key and body sign in again; another body is still `idempotency_key_reused`.
- **Refresh doesn't use the plug.** `DeviceSessions.refresh/2` keeps the key on the spent refresh token (`rotation_key`, unique) with the encrypted successor grant: the same key within 60 seconds gets the same tokens, any other reuse of the spent token revokes the session (`refresh_reuse_detected`), and a key that already rotated another token is `idempotency_key_reused`.
- **Sign-out stores nothing.** It's idempotent by nature (always `204`), so the key is only checked for shape.
- `Awrad.Pruner` deletes expired rows hourly; lookups ignore them anyway.

## Consequences

- One mechanism for every future `POST`: add the route under the `:idempotent` pipeline.
- Replays are byte-for-byte the first response, including tokens; they're as sensitive as the original and only go to a client that knows the key and the exact body.
- Rotating `AWRAD_ENCRYPTION_SECRET` makes stored results unreadable; the plug then runs the request again instead of failing.
