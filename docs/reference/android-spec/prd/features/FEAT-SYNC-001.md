# FEAT-SYNC-001 — Account-bound progress synchronization

**Status:** implemented protocol v1 across Android/API/iOS contracts; this PRD scopes Android behavior.  
**Technical authority:** [`docs/progress-sync-architecture.md`](../../../docs/progress-sync-architecture.md), `contracts/progress-sync/v1/`, `contracts/progress-model/v1/`.

## Goal

Synchronize eligible local goals, custom dhikr, and count progress between a user's authenticated installations while keeping local practice usable offline.

## Requirements

- **SYNC-001 [OBSERVED]** Native UI writes to Room; a local mutation and durable outbox operation commit atomically. UI never writes the product record directly through the API.
- **SYNC-002 [OBSERVED]** Run periodic and immediate WorkManager sync plus foreground coordination when eligible. If offline or unauthenticated, retain local data/outbox and retry under current policy.
- **SYNC-003 [OBSERVED]** Use account-scoped authenticated v1 command, snapshot/delta, transfer-page, and actor-ack routes. The server derives ownership from credentials; clients do not send authority-bearing user IDs.
- **SYNC-004 [OBSERVED]** Preserve UUID identity, actor order, idempotency, revisions, entity versions, tombstones, and stable slot references as defined by contracts.
- **SYNC-005 [OBSERVED]** Treat count increments as idempotent credits. Decrement/reset consume only eligible observed credits; no negative debt.
- **SYNC-006 [OBSERVED]** Apply a snapshot/delta transactionally and advance a cursor only after all canonical state through that revision is durable.
- **SYNC-007 [OBSERVED]** Keep pending optimistic local progress overlaid until an equal/newer canonical effect is installed. Do not double count server acknowledgements.
- **SYNC-008 [OBSERVED]** Preserve whole-document edit conflicts for goals/custom dhikr and expose sync/conflict state in Settings; counts do not require manual merge.
- **SYNC-009 [OBSERVED]** Bind the local dataset to the first account whose import completes successfully. Account switching must follow the contract and must not silently merge account-owned datasets.
- **SYNC-010 [OBSERVED]** Android backup exclusions cover the database/preferences/audio and sync actor/outbox identity is not backup authority; authenticated sync is separate from OS backup.

## Acceptance examples

1. Offline count remains visible and is uploaded once after reconnection/auth eligibility.
2. Retrying the same immutable command does not create duplicate count progress.
3. A failed snapshot apply does not advance the saved cursor.
4. A stale entity edit is retained as a conflict, not silently replacing newer cloud content.
5. Community aggregate totals are not used as the user's canonical personal count.

## Open decisions

Confirm how sync conflicts are presented for each entity and the recovery/export story for guest-only local data.

