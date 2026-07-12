# Decision: Refresh Token Rotation

## Status

Accepted

## Date

2026-04-07

## Context

The mobile app needs long-lived credentials so active users aren't forced to re-login. A static refresh token with a fixed expiry would mean:

- 180-day expiry: a user who opens the app daily still gets logged out after 180 days
- Shorter expiry: better security but worse UX for a daily-use app
- No expiry: unacceptable security risk

We also need to handle the case where a refresh token is stolen.

## Decision

We use **refresh token rotation**: every time a refresh token is used, the old one is deleted and a new one is issued. The new token gets a fresh 180-day expiry.

### Flow

1. Client sends old refresh token to `POST /api/auth/refresh`
2. Server verifies token exists in DB, is not expired, and has `context = "refresh"`
3. Server deletes the old token
4. Server generates a new refresh token + new JWT access token
5. Server inserts the new refresh token (hashed) into DB
6. Server returns both new tokens to the client

### Security Properties

- **Active users never get logged out**: each refresh resets the 180-day clock
- **Stolen token detection**: if an attacker uses a stolen refresh token first, the legitimate user's next refresh fails (token already consumed). This signals a compromise.
- **Single use**: each refresh token can only be used once. Replay attacks fail.
- **Revocable**: logout deletes refresh tokens from DB, immediately invalidating them.

## Alternatives Considered

### Static refresh tokens (no rotation)

Rejected. Fixed expiry forces re-login even for active users. No way to detect token theft.

### Sliding window without rotation

Rejected. Extending expiry without replacing the token means a stolen token remains valid for the full window.

### Refresh token families

Considered. If a rotated-out token is reused, invalidate the entire family (all tokens for that user). Added complexity, deferred for now. Current single-deletion approach is sufficient for the app's threat model.

## Consequences

### Benefits

- Active users stay logged in indefinitely
- Each token use is single-shot — harder to exploit stolen tokens
- 180-day window only applies to truly inactive users

### Tradeoffs

- Client must store the new refresh token after every refresh call
- If the client crashes between receiving the new token and storing it, the user is logged out (acceptable for mobile — rare edge case)
- Slightly more DB writes (delete + insert per refresh vs. just a read)
