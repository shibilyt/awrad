# 0002: SwiftData: one schema, recreated on incompatibility, until the first release

Status: Accepted (2026-10-17)

## Context

Nothing is released, so there's no user data to preserve (root ADR-2026-10-14). Android keeps Room at version 1 until release (Android ADR 0003). The frozen iOS app's `VersionedSchema` and snapshot migrations carried a lot of ceremony.

## Decision

- Until the first release there's one SwiftData schema, edited in place.
- `AwradStore.persistent()` deletes and recreates the store if it can't be opened.
- At the first release, a follow-up ADR removes that fallback and starts `VersionedSchema` / `SchemaMigrationPlan` migrations.

## Consequences

- Schema iteration is free during development, at the cost of local dev data after an incompatible change.
- The fallback is a release blocker. It's flagged in code and in the rebuild plan's "before the first release" list.
