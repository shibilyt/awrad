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
