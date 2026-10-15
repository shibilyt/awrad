# 0003: awrad-android-next replaces awrad-android

Status: Accepted (2026-10-14)

## Context

`awrad-android-next` started as a proof of concept. The goal is now to replace `awrad-android` completely. Neither app has been released, so there are no installs, user data or store listing to carry over.

## Decision

`awrad-android-next` becomes the Android app. `awrad-android` is reference material: its code and tests show current behaviour, but nothing on-device has to stay compatible with it.

Free to design fresh:

- `applicationId`: choose the final one before the first release;
- Room schema, DataStore keys, notification channel and WorkManager names, deep links.

Still binding, because iOS and the server share them:

| Surface | Source of truth |
|---|---|
| API routes and JSON | `CONTRACTS.md`, the Phoenix router |
| Built-in content identity (catalog keys, UUIDv4 IDs) | Root ADR-2026-07-13, `BuiltInDhikrIds` |
| Account and device-session rules | Root ADR-2026-07-12 |
| Domain language and behaviour | `CONTEXT.md` and shared behaviour fixtures (ADR 0002) |

**Room before the first release:** the database stays at version 1. Schema changes edit version 1 and re-export its schema, with no migrations. Forward-only migrations and schema history start with the first public release. This narrows the repo-wide "preserve migration history" rule, which exists to protect installed users, and there aren't any yet.

## Consequences

- No legacy-database baseline. The schema is designed from the real domain model (Goal, Requirement, Schedule, Session, Active period, Streak) instead of inheriting awrad-android's 15 versions of history.
- Behaviour is ported deliberately. Use awrad-android's tests and fixtures as the specification, and record intentional differences in this project's docs.
- awrad-android is frozen as reference: fix in the new project rather than in both.
- Before the first public release, a follow-up ADR fixes the `applicationId` and switches Room to forward migrations.
