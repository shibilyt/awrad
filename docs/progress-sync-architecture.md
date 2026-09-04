# Offline-first progress synchronization

Status: Implemented (protocol v1)

This document is the implementation source of truth for synchronizing custom dhikrs, goals, and count progress between authenticated Awrad clients. It complements the canonical native progress model in `contracts/progress-model/v1/` and the wire contract in `contracts/progress-sync/v1/`.

## Implementation status

Phoenix, Android, iOS, and the authenticated web companion implement the v1
engine end to end. This includes
durable native outboxes and canonical shadows, atomic snapshot/delta staging,
per-user revisions, actor recovery, idempotent receipts, the immutable count
ledger, entity OCC/conflicts, tombstones/restoration fences, generation reset,
checksummed transfer sessions, actor acknowledgements, projection repair,
retention, bounded background compaction, and browser-scoped actors. The server
feature flag can stop network synchronization without affecting offline counting.

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

Native UI never writes through the API directly: Android uses Room and iOS
synchronized state must have one App Group transactional persistence authority.
The web companion is intentionally online-first and writes only through its
LiveView `WebSync` adapter. Phoenix is the durable meeting point between
devices, not a runtime dependency for native offline counting.

## Browser companion actors

The authenticated web companion reuses the existing `progress_sync_actors`
table and does not add a migration or a public JSON route. The browser pipeline
creates a server-generated UUIDv4 `web_installation_id` in the signed,
host-only, `HttpOnly` Phoenix session cookie. The value is never read from or
accepted from browser JavaScript as an ownership field.

`WebSync.increment/3` is the only browser write boundary. It derives ownership
from the authenticated scope, validates the browser-local ISO date and the
supported goal/slot policy, resolves an actor by `(user_id, installation_id)`,
and delegates sequence allocation and idempotent execution to
`ProgressSync`. A stable command UUID per click means retries return the
original receipt without creating another count. The user head and actor are
locked in the same transaction before the next sequence is allocated.

Tabs in one account share the same actor. Signing into a second account in the
same browser resolves a separate actor because the user ID is part of the
lookup. An expired actor is never resurrected; the next request receives a new
incarnation while historical credits remain attached to the old one. Canonical
reads acknowledge the actor at the current head and renew its lease so browser
activity does not hold back compaction.

The web UI sends the browser's local calendar date and IANA timezone on socket
initialization and at midnight rollover. V1 has no IndexedDB, service worker,
or browser outbox. Daily, one-time, and advanced goals expose manual counting
only for active anytime slots; prayer-relative and time-window slots remain
read-only. Mobile clients continue using the existing API and native sync
contract unchanged.

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

### Remote count feedback

When a committed delta changes the visible count, native clients aggregate the
signed change by goal and publish a transient in-process feedback event. The
event is calculated from the canonical projection installed by sync, after
accounting for open and pending local overlays; it is never inferred from the
screen's before/after total. A local tap whose receipt merely replaces its own
optimistic overlay therefore produces a zero feedback delta.

While that goal's counter is open, Android and iOS temporarily replace the
normal counting hint with a styled, non-interactive cloud message such as
`+12 synced from another device`. Closely spaced changes accumulate and the
message clears after four seconds without pausing counting, stealing focus, or
adding haptic/audio feedback. Initial snapshot restoration and generation-reset
reconciliation remain silent so opening an account does not replay historical
activity as live device changes.

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

### Reinstall and installation recovery

Secure credential storage may outlive an app installation, while the
installation identity and product database do not. Mobile credentials are
therefore bound to both their user and the installation UUID that created them.
If those credentials survive but their installation marker does not, the client
must not present authenticated UI or silently reuse the old session.

The app instead shows a blocking, account-specific sign-in recovery screen. It
may display a masked email hint, but it exposes no cloud data before the user
authenticates again. A server `installation_mismatch` response enters the same
path for credentials created before installation markers existed. Pending and
in-flight commands are quarantined immediately so a partial fresh database
cannot be interpreted as intentional deletion.

After the same user signs in, the client rotates its installation identity and
clears only synchronization metadata: cursors, shadows, inbox pages, conflicts,
batches, and quarantined commands. Native goals, dhikrs, and counts remain
intact. The next run performs a full conservative snapshot merge, restores
cloud records, and uploads genuinely local records under the new installation.
Signing in as another user is rejected while recovery is pending. This local
recovery flow never deletes cloud progress.

The recovery screen also offers an explicitly confirmed local reset. That path
clears product rows, sync cursors, shadows, inbox/outbox work, conflicts,
preferences, widget projections, reminder schedules, and legacy local snapshots;
then it reseeds the built-in offline library and returns to onboarding while
signed out. It uses a persistence transaction that bypasses sync diff generation,
so erasing the installation cannot enqueue entity deletions or change the
account's cloud backup.

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

## Foreground synchronization cadence

Synchronization is event-driven first and periodic second. A successful local
mutation schedules a debounced attempt after two seconds. While an authenticated
app is visible, Android and iOS also pull on a jittered interval: approximately
every 10 seconds while the counting screen is active and every 60 seconds on
other screens. Entering the foreground, opening the counter, and regaining the
network trigger an immediate attempt. Leaving the foreground permits one
best-effort bounded flush; the operating-system background scheduler remains the
durability fallback and offline writes never wait for the network.

Only one engine run may execute at a time. Failures use exponential backoff from
five seconds to five minutes, and all regular intervals include plus-or-minus
20 percent jitter so a fleet does not wake in lockstep. A later local mutation
is durable even when an attempt is delayed by backoff.

Delta requests advertising the `unchanged_delta` capability may receive a
lightweight `status: unchanged` response when their cursor already equals the
account head. That response carries a replacement signed cursor but creates no
transfer session or pages. Older clients retain the materialized empty-delta
behavior. If a command commits immediately after the head check, its revision is
simply returned by the next delta; correctness never depends on the fast path.

### Dhikr tags capability (`dhikr_tags_v1`)

Progress-sync v1 can carry user-defined dhikr tags as whole-document entities:

- `user_tag`: `id`, display `name`, `normalized_name`, `created_at`, `updated_at`
- `dhikr_tag_assignment`: `id`, `tag_id`, `dhikr_id`, `created_at`

Normalization is server-owned and locked by
`contracts/behavior-model/v1/fixtures/tag-normalization-contract.json`: trim and
collapse Unicode White_Space (including NNBSP/figure space), NFC-normalize
display text, and apply Unicode Default Case Folding for `normalized_name`
without stripping diacritics or Arabic marks. Duplicate normalized creates
coalesce: the accepted receipt's `canonical_effect.entity_id` (and
`document.id`) is the surviving canonical tag UUID, even when the command
proposed a different create id; capable clients must re-point local assignments
and drop the losing tag. Assignment `tag_id`/`dhikr_id` are immutable on update;
`entity_restore` revalidates ownership/limits. Assignments may reference
built-in or caller-owned custom dhikrs. Tag delete and custom-dhikr delete
cascade assignment tombstones at the deleting command's revision.

Transfer materialization emits tag records only when the client advertises
`dhikr_tags_v1`, ordered as `custom_dhikr`/`user_tag` (0),
`dhikr_tag_assignment` (1), `goal` (2), then projections/conflicts/tombstones.
Older clients continue to receive the pre-tag record surface — tag/assignment
rows are excluded from the entity query before the shared transfer limit — and
the server still cascades assignment tombstones for capable peers when an older
client deletes a custom dhikr. Custom-dhikr documents remain unchanged and never
carry owned audio bytes or device paths.

Native clients that newly advertise `dhikr_tags_v1` perform one capability-aware
snapshot bootstrap, then mark a durable local bootstrap flag complete before
resuming ordinary deltas. This prevents tag revisions that predate an older
cursor from being skipped.

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
