# 0006: Account rate limits are fixed windows in Postgres

Status: Accepted (2026-10-26)

## Context

Every account action needs rate limits per client IP and per account, answered as `429` with `Retry-After` (`contracts/api/STYLE.md` §12, slice 2a inventory item 14). The options:
- **In-memory (ETS, Hammer's ETS backend):** fast, but per node. Limits reset on deploy and multiply with every node.
- **Redis (Hammer's Redis backend):** shared and fast, but a new piece of infrastructure the deployment doesn't have.
- **Postgres:** shared by every node, survives restarts, and is already there. The frozen server used fixed windows in Postgres (`auth_rate_limits`) with these limits.

The traffic is small (account actions, not every request), so one upsert per check is cheap.

## Decision

- **A Postgres table, `auth_rate_limits`**, one row per action scope, subject and window, counted with `INSERT … ON CONFLICT DO UPDATE SET count = count + 1` (`Awrad.Accounts.RateLimiter`).
- **Fixed windows**, the frozen server's limits:

  | Action | Per IP | Per account |
  |---|---|---|
  | `register` | 5 / hour | 5 / hour |
  | `verify_email` | 10 / hour | 10 / hour |
  | `resend_verification_code` | 5 / hour | 5 / hour |
  | `request_password_reset` | 5 / hour | 5 / hour |
  | `reset_password` | 10 / hour | 10 / hour |
  | `sign_in` (mobile and browser together) | 30 / 15 min | 10 / 15 min |
  | `refresh` | 60 / 15 min | – |
  | Fresh code on sign-in to an unverified account | – | 5 / hour, silently skipped |

  The account subject is the trimmed, lowercased email (or the account ID). `sign_out_device_session`, `get_current_account` and `delete_browser_session` aren't limited; their contracts document no `429`.
- **Subjects are stored as HMACs** (`Awrad.Secrets.hmac/2`), never as plain emails or IPs.
- **The client IP is `conn.remote_ip`.** Behind a reverse proxy the deployment must first rewrite it from the proxy's trusted forwarding header (see `ARCHITECTURE.md`).
- `Awrad.Pruner` deletes windows older than two hours, hourly.

## Consequences

- No new infrastructure, and limits hold across nodes and deploys.
- Fixed windows allow a burst of up to twice the limit across a window boundary. That's acceptable for these limits; a sliding window can replace the counting without changing the API.
- Each limited request costs one or two upserts. If that ever matters, the counting can move to ETS or Redis behind the same `RateLimiter.check/3`.
