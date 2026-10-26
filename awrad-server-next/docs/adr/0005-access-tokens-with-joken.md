# 0005: Mobile access tokens are HS256 JWTs signed with Joken

Status: Accepted (2026-10-26)

## Context

Mobile clients authenticate with a short-lived bearer access token bound to a device session (ADR-2026-07-12, root ADR-2026-10-26). The frozen server used HS256 JWTs (`sub`, `sid`, `jti`, 15 minutes) via Joken and checked the session in the database on every request. The rebuild needed a JWT library, or none:
- **Joken** (on JOSE): small API, widely used with Phoenix, the frozen server's choice. `Joken.Signer` verifies with JOSE's strict mode, so only the configured algorithm is accepted.
- **JOSE directly:** the same engine with a lower-level API.
- **Hand-rolled HS256** with `:crypto`: no dependency, but JWT parsing and validation are easy to get subtly wrong (`alg: none`, algorithm confusion, claim checks).
- **Opaque random tokens** looked up in the database: also valid, since every request hits the database anyway, but it's a token format change both mobile clients would have to follow, with no gain for this slice.

## Decision

- **Joken 2.6** (`Awrad.Accounts.AccessToken`), HS256 only, with the key from `Awrad.Secrets` (`AWRAD_ACCESS_TOKEN_SECRET` in production).
- Claims: `sub` (account), `sid` (device session), `jti`, `iat`, `nbf`, `exp` (15 minutes), `iss` = `awrad`, `aud` = `awrad-mobile`. Joken validates `exp`, `nbf`, `iss` and `aud`.
- **A valid token is never enough.** `DeviceSessions.identify/1` loads the session and account on every request and rejects revoked or expired sessions and unverified accounts. Revocation is therefore immediate, not "within 15 minutes".

## Consequences

- One small dependency (Joken plus JOSE). Upgrades follow the usual dependency review.
- Rotating `AWRAD_ACCESS_TOKEN_SECRET` invalidates every access token at once; clients recover by refreshing (refresh tokens don't depend on it).
- Tokens stay opaque to clients: they must not parse them. Switching to opaque tokens later wouldn't change the API.
