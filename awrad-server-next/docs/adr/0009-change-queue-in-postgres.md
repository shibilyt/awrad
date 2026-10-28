# 0009: The change queue in Postgres: one locked transaction per batch, one statement per feed page

Status: Accepted (2026-10-28)

## Context

Root ADR-2026-10-28 "The change queue" and `contracts/sync/v1/` fix the protocol: per account, a head revision under a row lock, one entity table, receipts kept 90 days, and tag aliases. Every applied command takes the next revision and its cascades share it; a command's outcome never undoes another's; a feed page never splits a revision and is read from one snapshot. How the server meets that is its own choice. The frozen `awrad_server` progress sync is evidence of the behaviour, not a design to copy.

## Decision

- **Four tables** (`priv/repo/migrations/20261028120000_create_sync.exs`), each referencing `users` `ON DELETE CASCADE`, with UUIDv7 primary keys:
  - `sync_heads`: one row per account, `head_revision`;
  - `sync_entities`: `(user, entity_type, entity_id)` unique, `version`, `revision`, `state`, `document` (`jsonb`, `NULL` for a tombstone), indexed on `(user, revision, entity_type, entity_id)` for the feed;
  - `sync_receipts`: `(user, command_id)` unique, the SHA-256 of the canonical payload, and the receipt as sent;
  - `sync_tag_aliases`: `(user, alias_id)` unique, and the surviving `tag_id`.
- **A batch is one transaction holding the account's head row `FOR UPDATE`** (created at revision 0 on the first batch with `INSERT … ON CONFLICT DO NOTHING`). Two batches of one account never interleave, and revisions commit in order, so a reader never sees revision N + 1 without N.
- **Decide, then write.** Each command reads what it needs, decides its receipt, and writes only when it's applied (entity, cascades, head); every other outcome writes only its receipt, and a merge only its alias. No outcome can undo another, so no savepoints. An unexpected database error aborts the whole batch (a `500`, nothing committed); the client resends the same commands, and their `command_id`s make that safe.
- **Payload hash.** SHA-256 of the canonical JSON of `entity_type`, `entity_id`, `op`, `base_version` and `document`, with object members sorted by name, so it doesn't depend on map order or the Erlang version. `command_id_reused` isn't stored; every other first receipt is, and is replayed byte for byte as `original`.
- **Documents are checked by hand** (`Awrad.Sync.Documents`, `CustomDhikrDocument`, `TagName`), not by a JSON Schema library at run time: the fixtures need specific `{field, code}` errors, and JSV is a test-only dependency. The size check (64 KB of compact JSON) runs first, so an oversized document is `document_too_large` whatever else is wrong with it.
- **A feed page is one SQL statement** (`Awrad.Sync.Feed`): the head, the cut-off revision (that of the `limit`-th matching change), the page and `has_more` come from one query, which Postgres runs against one snapshot. No `REPEATABLE READ` transaction is needed. `entity_type` is ordered with `COLLATE "C"`, and `entity_id` as a `uuid`, which matches the lowercase text order the fixtures use.
- **Routes** sit behind `AccountAuth`, the either-credential pipeline whose branches each accept only their own credential (bearer if there's an `Authorization` header, otherwise only the cookie session with CSRF on the POST). Phoenix routes by path, so one route per operation with that dispatch is how "both pipelines" is mounted.
- `Awrad.Pruner` deletes receipts older than 90 days hourly.

## Consequences

- One account's syncs queue behind each other; different accounts never wait on each other.
- A batch of 100 commands is one transaction of a few hundred small statements. If that ever matters, entity reads can be batched per command list without changing the protocol.
- Tag-name collisions are found by scanning the account's active tags (`document->>'normalized_name'`, at most 100); no expression index yet.
- Goals (slice 4) and counts (slice 5) add entity types: a document checker, rules in `Awrad.Sync.Rules`, and the type in the `entity_type_known` check constraint.
