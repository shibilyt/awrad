# Progress sync v1

This directory defines the transport-neutral offline progress synchronization contract described in `docs/progress-sync-architecture.md`.

`progress-sync.schema.json` owns request/response envelopes and command wire values. Counts and revisions are decimal strings so a future JavaScript client does not lose signed 64-bit precision. `fixtures/protocol-examples.json` contains representative API payloads. `fixtures/count-scenarios.json` is executable input for the reference credit/consumption reducer.

Count corrections in v1 target one goal/slot/local-date bucket. A goal-wide or
account-wide reset is represented as an atomic command batch containing one
`reset_bucket_observed` command per affected bucket; this keeps every observed
credit explicit and replayable.

`local_frontier_sequence` implicitly observes credits from the current actor
and exact earlier commands durably adopted by that recovery actor. Therefore
`observed_local_credit_ids` is normally empty and is needed only for foreign or
otherwise unordered credits that are newer than `basis_revision`. There is no
arbitrary list-count limit: the server validates the wire UUIDs while retaining
only their intersection with its bounded active ledger tail. A device transfer
should install foreign canonical state and advance `basis_revision` instead of
copying an unbounded history of credit IDs.

Delta cursors are signed for one authenticated account. Conflict creation and
resolution are both revisioned: an unresolved `conflict` transfer record carries
`resolved=false` and the proposed document; its resolution is emitted at a later
revision with `resolved=true` and `resolved_at`, and resolved conflicts are
omitted from fresh snapshots.

Clients advertising `unchanged_delta` receive a lightweight
`status=unchanged` delta response when their signed cursor is already at the
account head. That response advances no state and creates no materialized
transfer session or page. Clients without the capability continue receiving the
original empty, checksummed transfer session for wire compatibility.

Clients advertising `dhikr_tags_v1` may upsert/delete `user_tag` and
`dhikr_tag_assignment` entity documents and receive those kinds (plus their
tombstones/fences/conflicts) in snapshot and delta transfers. Clients without
the capability continue to receive only pre-existing record kinds
(`custom_dhikr`, `goal`, `count_projection`, and related conflict/tombstone/
fence records for those entities). Tag metadata is account-owned organizational
state; owned custom-audio bytes remain local-only and never appear in progress
documents.

`user_tag` documents carry `id`, display `name`, `normalized_name`,
`created_at`, and `updated_at`. Normalization is the shared algorithm locked by
`contracts/behavior-model/v1/fixtures/tag-normalization-contract.json`: trim and
collapse characters with the Unicode White_Space property (including
Space_Separator such as NNBSP U+202F and FIGURE SPACE U+2007) to a single
U+0020, NFC-normalize display `name`, and derive `normalized_name` with Unicode
Default Case Folding (full case fold, e.g. ß↔SS and dotted capital I) followed
by NFC, without stripping diacritics or Arabic marks. Empty names, names over 40
grapheme clusters or 128 UTF-8 bytes, more than 100 tags per account, and more
than 20 assignments on one dhikr are rejected.

Concurrent creates that collide on `normalized_name` coalesce. The accepted
command receipt keeps `status: "accepted"` and places the **existing** canonical
tag identity in `canonical_effect`:

- `canonical_effect.entity_type` is `"user_tag"`
- `canonical_effect.entity_id` is the surviving canonical UUID (not the losing
  client-proposed create id)
- `canonical_effect.document.id` equals that same canonical UUID
- `canonical_effect.document.normalized_name` is the server-owned normalized form
- `canonical_effect.state` is `"active"`

Capable clients MUST treat `command.entity_id != canonical_effect.entity_id` on
an accepted `user_tag` create as coalesce: atomically re-point local
`dhikr_tag_assignment.tag_id` rows from the losing id to
`canonical_effect.entity_id`, drop the losing local tag, and ack/delete the
outbox command keyed by the losing id. The wire does not emit a separate
coalesce status; the identity swap inside `canonical_effect` is the signal.

`dhikr_tag_assignment` documents carry `id`, `tag_id`, `dhikr_id`, and
`created_at`. Assignments may target the caller's custom dhikrs or stable
built-in dhikr IDs. `tag_id` and `dhikr_id` are immutable after create; updates
that change either reference are rejected. `entity_restore` revalidates
assignment ownership/limits before reactivation. Deleting a tag cascades
assignment tombstones at the same revision; deleting a custom dhikr cascades its
assignment tombstones after the existing goal dependency gate. Older clients can
delete customs without understanding tags.

Transfer materialization sorts records by dependency precedence before paging
and checksums:

| kind | order |
|---|---|
| `custom_dhikr` | 0 |
| `user_tag` | 0 |
| `dhikr_tag_assignment` | 1 |
| `goal` | 2 |
| `count_projection` | 3 |
| `conflict` | 4 |
| `tombstone` / `deletion_fence` | 5 |

Ties at the same order keep ascending `sync_revision` then `id`. Clients may use
any numeric scheme that preserves this relative precedence when applying pages;
checksum verification always uses the server-emitted order.

Clients without `dhikr_tags_v1` exclude `user_tag` / `dhikr_tag_assignment`
rows (and their conflicts) from the entity query **before** the shared transfer
record limit is applied, so capability-gated tag tombstones cannot crowd out or
block non-tag progress under the same cursor/limit budget.

When a client first upgrades into `dhikr_tags_v1`, it must perform one
capability-aware snapshot bootstrap before relying on its previous progress
cursor. Native sync state keeps a durable one-time bootstrap flag so tag
revisions that predate the old cursor are not skipped. After that snapshot
applies successfully, ordinary capability-aware deltas resume.

Deletion wins over an old entity incarnation in v1. A late count command gets a
durable `gone` receipt that clients retain as a user-visible recovery item; it is
never silently applied to a restored incarnation.

Actor recovery does not change an immutable pending command. When its receipt
already exists, a fresh actor in the same account and installation lineage can
durably adopt that identical command at its next sequence and receive the stored
result without applying the mutation again. Adoption never crosses accounts or
installations and never accepts a changed payload.

Actor acknowledgements carry `starting_sequence`, the client's next durable
outbox sequence. If the server returns `actor_fork` for an expired/retired actor,
the client creates a new UUIDv4 actor in the same authenticated installation and
retries the acknowledgement with that same starting sequence. The server assigns
the next installation incarnation and can then adopt any matching lost-response
receipts as those commands are retried.

After an entity is purged, every historical receipt referring to it is redacted
to status `gone` with a canonical `deletion_fence` effect. This applies equally
to ordinary and adopted receipt replay, so a lost accepted response can never
restore purged private state.

Run:

```bash
python3 scripts/validate_progress_sync.py
```

The contract is implemented by the verified-auth Phoenix routes under
`/api/sync/v1/progress`, with matching Room and SwiftData consumers. Transfer
pages and sessions are checksummed; clients stage the whole transfer before an
atomic apply/cursor commit. The v1 server bounds commands, sessions, pages, and
materialized record counts.
