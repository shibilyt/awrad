# Sync v1: the change queue

How a user's own data moves between their phones, the web and the server. Slice 3b ([brief](../../../docs/slices/03b-custom-dhikrs-sync.md)) builds it for custom dhikrs and tags; goals (slice 4) and counts (slice 5) reuse it. Decision: root [`DECISIONS.md`](../../../DECISIONS.md) ADR-2026-10-28 "The change queue", which replaces the frozen progress sync v1 ([`../../progress-sync/v1/`](../../progress-sync/v1/)) for the rebuild.

| File | What it is |
|---|---|
| `sync.schema.json` | JSON Schema 2020-12, `urn:awrad:sync:1`: commands, receipts, changes and the three documents |
| `fixtures/*.json` | `awrad-fixture/1` cases (below): the protocol as tests |
| [`../../api/paths/sync.yaml`](../../api/paths/sync.yaml) | The two HTTP operations. Their schemas restate this one, because the OpenAPI bundler can't follow `urn:` references; `tools/check-sync-contract.mjs` checks every example against `sync.schema.json` |

## Entities

Everything synced is an **entity**: an `entity_type`, an `entity_id` (a UUID), a whole JSON **document**, a per-entity **version** and a **state** (`active` or `deleted`).

| `entity_type` | `entity_id` | Document |
|---|---|---|
| `custom_dhikr` | a new UUIDv7 | `$defs/custom_dhikr_document` |
| `user_tag` | a new UUIDv7 | `$defs/user_tag_document`: `{name, normalized_name}` |
| `dhikr_personal` | the dhikr's ID, built-in or custom | `$defs/dhikr_personal_document`: `{tag_ids}` |

- **Custom dhikr.** The catalog dhikr shape (`urn:awrad:dhikr-catalog:1#/$defs/dhikr`), reusing its `kind`, text and `reference` definitions, but:
  - no `id` (the `entity_id` is the ID), `key`, `aliases`, `virtues` or catalog `tags` (user tags live in `dhikr_personal`);
  - `title` `{en, ar, ml}`, `transliteration` `{en, ml}` and `translation` `{en, ar, ml}` always carry every language key, each text or `null` (API STYLE §3), and the title has at least one text;
  - `audio` is `null` or `{"local_only": true}`: a recording that stays on the device that imported it, until uploads arrive in slice 3c;
  - references keep the catalog's member names, so a Qur'an reference has `ayah_start` and `ayah_end` in camelCase.
- **Tag.** `name` is the display form and `normalized_name` its case fold, both defined by [`fixtures/tag_name_normalization.json`](fixtures/tag_name_normalization.json). Two active tags never share a `normalized_name`.
- **Personal record** (`dhikr_personal`): a user's own data about one dhikr. For now only its tags, in the user's order. Clients never delete one; they put `{"tag_ids": []}`.

**Versions.** 0 means "doesn't exist yet". Every applied change adds one, including a delete and a server-side cascade.

**Revisions.** Each account has a revision counter. Every applied command takes the next revision, and its cascades share it. An entity remembers the revision of its last change.

**Deletes are final.** A deleted entity stays as a tombstone (no document), and every later command on it is `gone`. There is no restore.

## Commands: `POST /api/v1/sync/commands`

A batch of 1–100 commands, applied in order. Each command is `{command_id, entity_type, entity_id, op, base_version, document?}`:

- `command_id` is a new UUIDv7 per command;
- `op` is `put` (create with `base_version` 0, or replace the whole document) or `delete` (no `document`);
- `base_version` is the version the client last knew.

**Batch versus command.** The batch is refused as a whole, with `422 validation_failed` and nothing applied, only when its envelope is wrong (`$defs/command_envelope`):
- 0 or more than 100 commands;
- a non-UUID ID, or an unknown `entity_type` or `op`;
- a bad `base_version`;
- `document` missing on a put, present on a delete, or not an object;
- an unknown member.

Everything else, including a document that breaks its schema, is a `rejected` receipt. One bad command never blocks a queue.

**Rules, in the order the server checks them** (the spec is [`fixtures/sync_receipts.json`](fixtures/sync_receipts.json)):

1. **Receipt store.** A `command_id` it has seen with the same payload (entity_type, entity_id, op, base_version, document) is a `duplicate` carrying the original receipt. With a different payload it's `rejected` with `command_id_reused`, and that rejection isn't stored.
2. A `dhikr_personal` delete is `rejected` with `delete_not_allowed`.
3. **Document.** A put's document must match its schema and the limits below. Otherwise it's `rejected` with `document_invalid` (with `fields`) or `document_too_large`.
4. **Entity state.**
   - A `user_tag` ID that is a merged alias, or a deleted entity, is `gone`.
   - An entity the server has never had needs a put with `base_version` 0; anything else is `rejected` with `entity_not_found`.
   - Otherwise `base_version` must equal the current version, or it's a `conflict`.
5. **Entity rules.**
   - A `user_tag` create whose `normalized_name` an active tag already has is `merged` (below).
   - A rename onto another active tag's name is `rejected` with `tag_name_taken`; existing tags are never merged.
   - Creating past 100 active tags, or 1,000 active custom dhikrs, is `rejected` with `tag_limit_reached` or `custom_dhikr_limit_reached`.
   - A `dhikr_personal` must belong to a built-in dhikr or an active custom dhikr of the account (`dhikr_not_found`). Its tag IDs are rewritten:
     - aliases become their surviving tag;
     - deleted tags are dropped;
     - repeats are removed, keeping first-occurrence order.

     An ID the account never had is `rejected` with `tag_not_found`.
6. **Apply.** The command takes `head_revision + 1`.
   - Deleting a tag removes it from every `dhikr_personal` that has it.
   - Deleting a custom dhikr deletes its `dhikr_personal`.
   - Both cascades happen at the same revision. From slice 4, a custom dhikr that goals use can't be deleted.

**Receipts** (`$defs/receipt`), one per command, in order:

| `status` | Meaning | Carries |
|---|---|---|
| `applied` | Done | `version`, `revision` |
| `duplicate` | Seen before with the same payload | `original`: the first receipt |
| `conflict` | `base_version` is stale | `current`: the server's `{version, state, document}` |
| `merged` | A tag create whose name exists | `merged_into` (the surviving tag), `current` (that tag) |
| `gone` | Deleted, or a merged tag ID | — |
| `rejected` | Invalid, over a limit, or a reused `command_id` | `code`, `fields` (`{field, code}`, pointers into the command), `current` (the server's copy to undo to, or `null`) |

Every receipt except `command_id_reused` is stored for 90 days, whatever its status. The response also carries `head_revision`.

**Tag merging.** Two phones that both create "Morning" offline end up with one tag:
- the second create is `merged`;
- its ID becomes an **alias** of the first, so any later `dhikr_personal` naming the alias is rewritten to the surviving tag, even in the same batch;
- a merge changes no entity and takes no revision.

## Changes feed: `GET /api/v1/sync/changes?after=N&limit=200`

Returns `{changes, next_after, has_more, head_revision}`. Each change is an entity's latest state, `{entity_type, entity_id, state, version, revision, document}`, where `document` is `null` for a delete. The spec is [`fixtures/sync_changes_feed.json`](fixtures/sync_changes_feed.json).

- **Content.** Entities whose revision is above `after`, ordered by revision, then `entity_type`, then `entity_id`.
- **`after`.** `after=0` is a full download and lists only active entities. `after>0` includes deletes.
- **`limit`.** 1–500, default 200.
- **Pages.** Whole revisions are added until a page holds at least `limit` changes, so a revision is never split and a page can be longer than `limit`.
  - If more remain, `has_more` is true and `next_after` is the page's last revision.
  - Otherwise `next_after` is `head_revision`. An `after` above the head gets an empty page, also with `next_after = head_revision`.
- **Consistency.** A page is read from one snapshot.

## Both endpoints

- **Auth.** A bearer token (phones) or the browser cookie session; the POST also needs `X-CSRF-Token`.
- **`X-Awrad-Account`** is required: the account the client believes it is writing to or reading.
  - A different account is `409 account_mismatch`, with nothing read or written.
  - A missing or malformed header is `400`.
- **Errors.** `401` and `403` as on other authenticated routes, and `429` with `Retry-After`.
- **`Idempotency-Key`** is accepted and ignored on the POST: commands are idempotent by `command_id`.

## Limits

| Limit | Where it's enforced |
|---|---|
| 1–100 commands per batch | Schema (`command_batch`); otherwise 422 |
| 1,000 active custom dhikrs per account | Server: `custom_dhikr_limit_reached` (not in the fixtures, because of its size) |
| 100 active tags per account | Server: `tag_limit_reached` |
| 20 tags per dhikr, no repeats | Schema: `document_invalid` |
| Custom dhikr: title 120 per language; Arabic, transliteration and translation 5,000 per language; 20 references | Schema, counted in Unicode code points: `document_invalid` |
| Tag name: 1–40 extended grapheme clusters, ≤ 128 UTF-8 bytes, already in display form; `normalized_name` equal to the server's | Server (the schema only bounds code points): `document_invalid` |
| 64 KB per document: UTF-8 bytes of its compact JSON, non-ASCII unescaped | Server: `document_too_large` |
| Changes page: `limit` 1–500, default 200 | Schema (OpenAPI) |
| Receipts kept 90 days | Server |

**Graphemes.** Grapheme counts follow Unicode UAX #29 as each platform ships it. The fixtures avoid characters whose segmentation changed recently, such as Indic conjuncts and emoji sequences.

## Phones

Android and iOS keep an **outbox** (the queue) in each profile's database. The web has none: it sends each edit as a one-command batch and reads the feed from `after=0` when it loads and again after each edit.

### Saving an edit

The rules are in [`fixtures/outbox_enqueue.json`](fixtures/outbox_enqueue.json). The change and its command are saved in one local transaction.

- **Last command never sent:** the edit replaces it in place, keeping its `command_id`, `base_version` and position. A delete of an entity whose never-sent create is still queued removes that create instead.
- **Otherwise:** a command is added at the end. Its `base_version` is the previous command's `base_version` + 1, or the known version when nothing is queued for the entity.
- **Deleting a custom dhikr** also drops never-sent commands for its `dhikr_personal`.

### Sending and pulling

The rules are in [`fixtures/apply_changes.json`](fixtures/apply_changes.json).

1. Send queued commands in order, in batches, then apply the receipts:

   | Receipt | What the phone does |
   |---|---|
   | `applied` | Records the version |
   | `duplicate` | Acts as its original |
   | `conflict` | Keeps the local edit and opens a conflict ("Changed on another device": **Keep mine** re-queues it on the server's version, **Use theirs** takes the server's copy). Later unsent commands for the entity are dropped |
   | `merged` | Rewrites the tag ID everywhere locally, in documents and unsent commands |
   | `gone` | Removes the entity |
   | `rejected` | Restores the server's copy, or removes the entity, and tells the user |

2. Pull pages from the stored `after`. Each page is applied in one transaction together with its `next_after`.
   - A change to an entity with a queued command or an open conflict updates only its known version.
   - A change older than the known version is ignored.
   - A delete of something the phone doesn't have is ignored.

**Cadence.** Sync on app start, after a change (with a 2 s debounce) and every 5 minutes while open. On failure, back off from 5 s to 5 min with ±20% jitter.

### Local profiles

The rules are in [`fixtures/profile_switch.json`](fixtures/profile_switch.json).

Each account's data lives in its own **profile**, a separate local database. A registry records every profile (local ID, account ID, email, feed `after`, last used) and which one is active. The fixtures leave out last used, which only orders the Settings list.

- **Before any sign-in** there is one anonymous profile. Edits are saved but never queued.
- **The first sign-in** asks once, only if the anonymous profile has data:
  - **Add to my account** adopts it and queues every entity as a put;
  - **Erase** replaces it with a fresh download.

  An empty anonymous profile is adopted silently.
- **Signing out** keeps the active profile. Its edits are queued but not sent.
- **Signing in again** as the same account sends its queue without asking.
- **Signing in as another account** switches to that account's profile, creating it if needed. The other profiles, unsent commands included, stay untouched.
- **Remove from this device** warns first if the profile has unsent changes. Removing the active profile signs out and starts a fresh anonymous profile.
- **When an account no longer exists**, the phone offers to remove its profile.

**Two safety checks** keep accounts from mixing:
- the sync engine sends only when the signed-in account equals the active profile's account;
- every request carries that account in `X-Awrad-Account`.

## Fixtures

| File | Who runs it | Cases |
|---|---|---|
| `tag_name_normalization.json` | All four | Display and normalized tag names, limits |
| `custom_dhikr_validity.json` | All four | Which custom dhikr documents are valid, with `{field, code}` errors |
| `sync_receipts.json` | Server | A state and a batch: receipts, head, changes, aliases, stored receipts |
| `sync_changes_feed.json` | Server | Entities, `after`, `limit`: the page |
| `outbox_enqueue.json` | Android, iOS | Known versions, queue and an edit: the queue |
| `apply_changes.json` | Android, iOS | Local state and a page, receipts or a resolution: local state and notices |
| `profile_switch.json` | Android, iOS | Registry, event and choice: the prompt, the registry, what's queued, synced and erased |

`npm test` in `contracts/` validates the fixtures and runs `tools/check-sync-contract.mjs`. That script checks that:
- the OpenAPI examples match this schema;
- `custom_dhikr_validity` agrees with `$defs/custom_dhikr_document`;
- the non-rejected commands in `sync_receipts` are valid commands;
- the names `tag_name_normalization` accepts make valid tag documents.
