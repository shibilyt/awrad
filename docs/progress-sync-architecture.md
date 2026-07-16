# Offline-first progress synchronization

Status: Implemented (protocol v1)

This document is the implementation source of truth for synchronizing custom dhikrs, goals, and count progress between authenticated Awrad clients. It complements the canonical native progress model in `contracts/progress-model/v1/` and the wire contract in `contracts/progress-sync/v1/`.

## Implementation status

Phoenix, Android, and iOS implement the v1 engine end to end. This includes
durable native outboxes and canonical shadows, atomic snapshot/delta staging,
per-user revisions, actor recovery, idempotent receipts, the immutable count
ledger, entity OCC/conflicts, tombstones/restoration fences, generation reset,
checksummed transfer sessions, actor acknowledgements, projection repair,
retention, and bounded background compaction. The server feature flag can stop
network synchronization without affecting offline counting.

The next protocol version may add streaming transfers beyond the v1 50,000-row
session bound and more granular conflict presentation. Those are extensions,
not correctness dependencies for v1.

## Guarantees

1. Counting, goals, reminders, history, and widgets remain usable without a network.
2. A native write and its pending sync command commit atomically.
3. Every accepted positive count contributes exactly once despite retries or delivery reordering.
4. Decrement and reset never create negative debt and never remove progress outside the user's observed basis.
5. Mutable aggregate count rows and client timestamps are never synchronization authority.
6. Deleted UUIDs cannot be resurrected by stale devices.
7. A transfer cursor advances only after all canonical state through its materialized revision is durably applied.
8. Automatic completion is projection state; it does not conflict with goal-definition edits.
9. The local dataset is permanently bound to the first account whose import completes successfully.

## System boundary

```text
Native UI / widget
       |
       v
Local transaction
  - update local projection
  - update an open count batch or entity
  - append an ordered outbox command
       |
       v
Background push -----------> Phoenix command transaction
                               - authenticate and derive ownership
                               - validate actor order and idempotency
                               - apply entity OCC or count reducer
                               - update projection and completion
                               - store receipt and user revision
       ^
       |
Materialized bootstrap/delta pages
```

The UI never writes through the API. Android uses Room; iOS synchronized state must have one App Group transactional persistence authority. Phoenix is the durable meeting point between devices, not a runtime dependency for counting.

## Identities and ordering

- `installation_id` identifies an installation for diagnostics and is not restored from product backup.
- Command and acknowledgement installation IDs must match the authenticated
  device session. Delta cursors are signed for one account and cannot be reused
  after an account switch.
- An acknowledgement includes the client's next durable `starting_sequence`.
  If the actor has expired, the client rotates to a new UUIDv4 actor in the same
  installation and retries with the unchanged sequence; the server assigns the
  next incarnation and never guesses the outbox frontier.
- `actor_id` identifies one serialized mutation stream. Phoenix assigns an
  installation incarnation when a new actor appears after reinstall/recovery.
- Every actor allocates a contiguous signed 64-bit `actor_sequence` transactionally.
- Every command has a UUIDv4 and a canonical payload hash computed by the server.
- Repeating the same command UUID and hash returns its stored receipt.
- Reusing a command UUID with different content is `idempotency_collision`.
- Reusing an accepted actor sequence with a different command is `actor_fork`;
  native clients rotate to a fresh actor and retry the still-immutable outbox.
- If the original response was lost before actor recovery, the fresh actor may
  atomically adopt the existing receipt only when command UUID, payload hash,
  actor sequence, account, and installation lineage all match and the sequence
  is next on the fresh actor. The adoption is durable, advances that actor once,
  and returns the original result without reapplying the mutation. Cross-account,
  cross-installation, older-incarnation, and changed-payload adoption is rejected.
- Actor identity, cursor, shadows, receipts, and pending outbox commands are excluded from backup/export.

Phoenix maintains `progress_sync_heads(user_id, revision, generation)`. A bounded command transaction locks only that user's row with `FOR UPDATE`, applies canonical state, advances the revision, and commits. This makes revisions commit ordered for one account while different accounts remain independent.

## Count model

### Local batches

Rapid positive taps accumulate in a durable open batch. Each tap transaction updates the visible `CountEntry`, the open batch amount, and optimistic completion. Before upload or a destructive command, the batch is sealed. A sealed batch is immutable and retries retain the same UUID.

```text
OPEN -> SEALED -> SENT -> ACKNOWLEDGED -> COMPACTABLE
```

### Server credits and consumptions

A sealed increment becomes an immutable credit. Decrement and reset commands consume eligible credit rather than inserting a negative delta.

For bucket `B = (goal_id, slot_id, local_date)`:

```text
remaining(credit) = credit.amount - sum(consumptions for credit)

count(B) = checkpoint.remaining_amount
         + sum(remaining uncompacted credits)
```

A correction carries an observed `basis_revision`, a same-actor frontier, and any explicitly observed local credit UUIDs not yet represented by that server revision. The local frontier also covers exact immutable increment commands durably adopted by a recovery actor. Explicit IDs are therefore only for foreign or otherwise unordered credits beyond the basis. The server validates every supplied UUID while retaining only its intersection with the bounded active ledger tail; it does not impose an arbitrary item-count limit. Snapshot/delta transfer advances the basis for foreign credits instead of copying an unbounded ID history. Eligible credit must belong to the command scope, have remaining value, and have been visible through one of those bases. The server consumes checkpoint credit first, then ordinary credits ordered by accepted revision and UUID. Decrement consumes at most the requested amount; reset consumes all eligible remaining amount.

Concurrent destructive commands are deliberately ordered by server acceptance. Positive credits are commutative. A correction cannot create negative debt, and a later unseen increment cannot be swallowed by an earlier correction.

### Caps

Native clients enforce goal caps against canonical-plus-pending local progress. If disconnected devices independently consume the same apparent capacity, the merged value may exceed the target or maximum. The server preserves every accepted positive credit and clients block further positive counting after convergence. A globally strict quota is intentionally not claimed while offline counting is allowed.

### Projection overlay

Visible local progress is:

```text
canonical server projection
+ open and sealed unacknowledged credits
- pending local corrections
```

An acknowledgement includes its result revision and canonical effect. The client removes a pending overlay only in the same transaction that installs an equal-or-newer canonical effect.

## Goal and custom-dhikr updates

Version one uses whole-document optimistic concurrency. A mutation sends the entity UUID, current `base_version`, and proposed canonical document.

- Matching base: validate and accept.
- Stale but canonically identical: acknowledge as a no-op.
- Stale and different: retain the server document and preserve the local proposal as a conflict.
- Conflict resolution chooses the current cloud document or the preserved device
  proposal against the latest version. Resolution advances the account revision;
  a delta emits the same conflict record with `resolved=true` and `resolved_at`,
  while fresh snapshots omit resolved conflicts.

Counts never require manual conflict resolution. Goal children retain stable UUIDs; referenced slots are archived rather than deleted.

## Completion authority

The shared sync representation includes
`completion_origin = null | manual | automatic | duration`.

- Goal-definition versions cover user-authored configuration, pause state, and explicit manual lifecycle commands.
- Count-driven automatic completion and reopening are derived from canonical count projections.
- A count does not advance the goal-definition version.
- Only automatically completed goals reopen when progress drops below the threshold.
- Manual completion remains until an explicit reopen command.

Phoenix implements the explicit manual-complete and manual-reopen command
semantics. The current Android and iOS clients do not expose those two manual
lifecycle actions yet; their end-to-end path in v1 is count-driven automatic
completion/reopening. This is a native product-surface limitation, not a
different wire representation.

## Deletion and restoration

A goal or custom-dhikr deletion produces a tombstone and entity-incarnation barrier. Payload and concurrent progress remain recoverable for 30 days. Restore retains the public UUID but starts a new internal incarnation; pre-delete mutations cannot silently edit it.

The protocol and Phoenix context implement restore. Current native clients
synchronize deletion and its tombstone/fence but do not expose a restore action;
native deletion is therefore deletion-wins until a future product surface sends
an explicit restore command.

After recovery retention, private payload, conflicts, and count details are purged. A minimal fence containing user, entity type, UUID, terminal revision, and purge state remains until account deletion. Recreating the concept after terminal purge requires a new UUID.

Deletion wins over old-incarnation count commands in protocol v1. A count
uploaded after its goal was deleted receives a durable `gone` recovery item,
remains visible in sync health for explicit user handling, and is never
silently replayed into a restored incarnation. Final custom-dhikr deletion is
blocked while an active or recoverable goal references it.

## Bootstrap and deltas

Bootstrap and normal delta responses are immutable short-lived transfer sessions, not pages over moving live tables and not a permanent event log.

1. Start a PostgreSQL `REPEATABLE READ` transaction.
2. Read the authenticated user's sync-head revision `T`.
3. Read canonical rows and tombstones from that same MVCC snapshot.
4. Materialize compressed pages with counts and checksums.
5. Commit and mark the transfer ready.
6. Serve immutable pages outside the transaction.
7. Expire incomplete sessions after 30 minutes.

A bootstrap contains all canonical state. A delta contains current state changed after the client's cursor. The client stages and verifies every bootstrap page before atomic installation. Delta pages enter a durable inbox and are applied in dependency order. The cursor advances to `T` only after every page has been durably applied. Expiry or generation reset never discards local outbox commands or open credits.

## Account binding and first import

The local dataset begins unbound and is permanently bound to the first account
that synchronizes. Authentication is revoked immediately if the device is
already bound to another account. Logout suspends networking while retaining
offline progress; changing accounts requires explicit local product-data erase.

First import uses a deterministic conservative union:

- A local custom dhikr or goal UUID absent from cloud is uploaded with its
  local counts.
- A UUID already present in cloud uses the cloud entity lineage and exact cloud
  count projection. Unknown local aggregates for that UUID are not added,
  because they may be a restored copy of the same taps.
- The import marker, staged cloud snapshot, and resulting outbox are durable;
  a crash at any point resumes without losing unique local entities or adding
  an overlapping aggregate twice.

Legacy iOS cumulative `all-time` rows use the stable protocol-valid migration
bucket `1970-01-01`. This preserves cumulative totals across retries without
pretending the value belongs to the day on which it was last edited. All new
progress uses its real ISO local date.

## Retention and compaction

Actors have a 90-day active lease. Each reports a safe compaction revision equal to the minimum of its applied revision and the oldest basis of any pending destructive command. Checkpoints advance only through the minimum safe revision of active actors and unresolved corrections.

One account may have at most 32 simultaneously leased actors. Expired actor IDs
cannot be resurrected; the client rotates to a fresh actor. Expired leases are
retired by bounded maintenance passes and no longer hold the compaction frontier.

The Phoenix compactor is deliberately conservative: it folds a bucket only when
every active actor's safe frontier equals the current account head. Maintenance
runs in bounded batches, uses row/advisory locks safely across nodes, removes
expired transfers, compacts large credit tails, purges due private payloads,
redacts retained receipts, and keeps minimal deletion fences.

If an old positive credit returns after rebootstrap while the same entity
incarnation is still active, it remains uploadable. A decrement or reset older
than the bucket checkpoint returns `stale_basis`; the client refreshes and asks
the user to reissue or discard it. An API request never scans unbounded history.
If the active tail exceeds the configured bound, return retryable
`checkpoint_required` and coalesce maintenance onto one timer chain.

## API surface

All routes belong under `/api/sync/v1/progress` and the existing `api_auth_verified` pipeline:

```text
POST /commands
POST /snapshots
GET  /snapshots/:id/pages/:page
POST /deltas
GET  /deltas/:id/pages/:page
POST /actors/ack
```

Protocol envelopes carry protocol version, progress-model version, and client capabilities. Ownership comes only from authenticated scope. Routes and body/batch/decompressed response work are bounded before public rollout.

## Operations and rollout

`PROGRESS_SYNC_ENABLED` is the network kill switch.
`PROGRESS_SYNC_MAINTENANCE_ENABLED` independently controls retention and
compaction work. Transfer sessions expire after 30 minutes, are limited to eight
active sessions per account, contain at most 50,000 records, and have 200 records
per page. Fetching the final page marks a session completed so it no longer uses
active quota, but its immutable pages remain retryable until expiry for
crash/resume safety. The 50,000-record ceiling is an operational v1 guard: an
account that reaches it requires support/operator escalation and a generation
reset after reducing or migrating canonical history; v1 does not pretend that a
truncated snapshot is complete. Clients expose last success, pending work,
conflicts, failed commands, and a manual retry in Settings. Server startup
validates/seeds the immutable built-in registry before serving traffic.
