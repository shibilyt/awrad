# Architecture decision records

Server-only decisions for `awrad-server-next`. Cross-project decisions live in the root [`DECISIONS.md`](../../../DECISIONS.md). Accepted ADRs aren't re-argued: supersede them with a new one.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-boundaries-enforced-at-compile-time.md) | Context boundaries enforced at compile time | Accepted |
| [0002](0002-contract-tests-against-the-bundled-spec.md) | Contract tests against the bundled OpenAPI spec | Accepted |
| [0003](0003-compiled-in-time-zone-database.md) | A compiled-in IANA time zone database (`tz`) | Accepted |
| [0004](0004-hijri-table-compiled-from-a-priv-copy.md) | The Hijri table, compiled in from a checked copy in `priv/` | Accepted |
| [0005](0005-access-tokens-with-joken.md) | Mobile access tokens are HS256 JWTs signed with Joken | Accepted |
| [0006](0006-rate-limits-in-postgres.md) | Account rate limits are fixed windows in Postgres | Accepted |
| [0007](0007-idempotency-results-in-postgres.md) | Idempotency-Key results are stored in Postgres | Accepted |
