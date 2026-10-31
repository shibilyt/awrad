# Sync v1: the change queue

How a user's own data moves between their phones, the web and the server. Slice 3b ([brief](../../../docs/slices/03b-custom-dhikrs-sync.md)) builds it for custom dhikrs and tags; goals and their order (slice 4, [brief](../../../docs/slices/04-goals.md)) and counts (slice 5) reuse it. Decision: root [`DECISIONS.md`](../../../DECISIONS.md) ADR-2026-10-28 "The change queue", which replaces the frozen progress sync v1 ([`../../progress-sync/v1/`](../../progress-sync/v1/)) for the rebuild.

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
| `practice_policy` | the account's ID | `urn:awrad:practice-settings:1#/$defs/practice_policy_document` (slice 3d, [`../../practice-settings/v1/`](../../practice-settings/v1/)) |
| `goal` | a new UUIDv7 | `urn:awrad:goal-model:1#/$defs/goal_document` (slice 4, [`../../goal-model/v1/`](../../goal-model/v1/)) |
| `goal_order` | the account's ID | `urn:awrad:goal-model:1#/$defs/goal_order_document`: `{goal_ids}` (slice 4) |

- **Custom dhikr.** The catalog dhikr shape (`urn:awrad:dhikr-catalog:1#/$defs/dhikr`), reusing its `kind`, text and `reference` definitions, but:
  - no `id` (the `entity_id` is the ID), `key`, `aliases`, `virtues` or catalog `tags` (user tags live in `dhikr_personal`);
  - `title` `{en, ar, ml}`, `transliteration` `{en, ml}` and `translation` `{en, ar, ml}` always carry every language key, each text or `null` (API STYLE §3), and the title has at least one text;
  - `audio` is one of:
    - `null`: no recording;
    - `{"local_only": true}`: a recording that stays on the device that imported it (signed out, offline, or not uploaded yet);
    - `{"asset_id", "byte_size", "content_type", "duration_ms"}` (`$defs/uploaded_audio`, slice 3c): a recording uploaded to the account's private storage ([`../../audio/v1/`](../../audio/v1/)). Every member is present: `asset_id` a UUID, `byte_size` 1–10,000,000, `content_type` `audio/mpeg` or `audio/mp4`, `duration_ms` an integer ≥ 1 or `null` when the client couldn't measure it. Any other `audio` is a field error `invalid` on `/audio`;
  - references keep the catalog's member names, so a Qur'an reference has `ayah_start` and `ayah_end`;
  - a Qur'an reference's `ayah_end` is at least its `ayah_start` (equal for one ayah). The schema can't compare two members, so a reversed range is a field error `range` on `/references/N/ayah_end`; the built-in catalog has the same check in `tools/check-dhikr-catalog.mjs`.
- **Tag.** `name` is the display form and `normalized_name` its case fold, both defined by [`fixtures/tag_name_normalization.json`](fixtures/tag_name_normalization.json). Two active tags never share a `normalized_name`.
- **Personal record** (`dhikr_personal`): a user's own data about one dhikr. For now only its tags, in the user's order. Clients never delete one; they put `{"tag_ids": []}`.
- **Practice policy** (`practice_policy`, slice 3d): the account's day reset, method, madhab, week start and Hijri corrections. One per account, its ID the account's; never deleted. Phones merge a conflict on it by setting instead of asking ([`../../practice-settings/v1/`](../../practice-settings/v1/)).
- **Goal** (`goal`, slice 4): one goal as a whole document: its dhikr and a snapshot of the dhikr's label, its name, shared or dedicated counts, dated versions of its settings, pauses, excused days and how it ended ([`../../goal-model/v1/README.md`](../../goal-model/v1/README.md), The goal document). Its counts aren't in it: they're the count log's (slice 5). Clients delete a goal only from History or before it has counts (decision 27).
- **Goal order** (`goal_order`, slice 4): the user's order of My Goals, `{goal_ids}`. One per account, its ID the account's; never deleted. It's written when the user reorders, and phones merge a conflict on it instead of asking (`goal-model/v1/fixtures/goal_order_merge.json`), keeping a `base_document` like the practice policy.

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
2. A `dhikr_personal`, `practice_policy` or `goal_order` delete is `rejected` with `delete_not_allowed`. A `practice_policy` or `goal_order` whose `entity_id` isn't the account's ID is `rejected` with `entity_id_invalid`, with a `mismatch` error on `/entity_id`.
3. **Document.** A put's document must match its schema and the limits below; a goal must also follow the goal rules (`goal-model/v1/fixtures/goal_validity.json`, below). Otherwise it's `rejected` with `document_invalid` (with `fields`) or `document_too_large`.
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
   - A `custom_dhikr` put whose `audio` names an `asset_id` that isn't a ready asset of the account (never uploaded, still pending, cleaned up, or another account's) is `rejected` with `audio_not_found`, with a `not_found` error on `/document/audio/asset_id`. One naming a ready asset but with a different `byte_size` or `content_type` is `rejected` with `audio_mismatch`, with a `mismatch` error on each disagreeing member (`/document/audio/byte_size`, `/document/audio/content_type`). `duration_ms` isn't compared. Clients confirm the upload before they queue the put, and copy the asset's size and type.
   - **A goal's `dhikr_id` and `counts` never change** after creation. A put on a stored goal that changes either is `rejected` with `goal_field_immutable`, with an `immutable` error on each changed member (`/document/counts`, `/document/dhikr_id`). This is checked before the dhikr below, so a changed `dhikr_id` is never `dhikr_not_found`. Phones handle it like other rejections: they restore the server's copy and show a notice. Another dhikr, or another counts choice, is a new goal.
   - **A goal's dhikr** must be a built-in dhikr or a custom dhikr of the account:
     - an ID that's neither is `rejected` with `dhikr_not_found`, with a `not_found` error on `/document/dhikr_id`;
     - a custom dhikr that has been **deleted** is accepted, so an edit made offline isn't lost. If the document hasn't ended, the server stores it ended, `{"on": <date>, "reason": "dhikr_deleted"}`, as the cascade below would have (decision 37). The receipt is `applied`; phones get the ended document from the changes feed.
   - **Goal limits:** a put that would give the account more than 300 goals that haven't ended, or more than 2,000 goals in all (ended ones included, deleted ones not), is `rejected` with `goal_limit_reached`. Ending a goal is never refused.
   - **A `goal_order`'s IDs** are rewritten: an ID that isn't a non-deleted goal of the account (unknown, deleted, another account's) is dropped. Repeats are a schema error (`document_invalid`, `duplicate` on `/document/goal_ids`). A goal created earlier in the same batch counts.
6. **Apply.** The command takes `head_revision + 1`.
   - Deleting a tag removes it from every `dhikr_personal` that has it.
   - Deleting a custom dhikr deletes its `dhikr_personal`, and **ends every goal of it that hasn't ended** (active and paused ones) with `{"on": <date>, "reason": "dhikr_deleted"}`. Their history and counts stay (decision 37).
   - Deleting a goal changes nothing else. A `goal_order` naming it keeps the ID until its next put drops it; clients ignore IDs they don't have.
   - The cascades happen at the same revision, and the command's `applied` receipt lists them in `cascaded`.

**The date a server-ended goal gets.** The server doesn't know the user's practice day, so `on` is the UTC date it applies the command on, or the goal's `created_on` or last version's `from` if one is later. It can be a day off the user's own date. The deleting phone has already ended the goals locally with its practice day; the server's documents replace them when they arrive in the feed.

**Goal documents** are checked in two layers, pinned by [`fixtures/goal_document_validity.json`](fixtures/goal_document_validity.json):
- **structure first** (`$defs/goal_document`):
  - a missing member is `required`;
  - an unknown member is `not_allowed`;
  - a wrong type, an unknown enum value, a session kind that doesn't exist, a non-UUID ID, or an impossible month-day (31 April, on the range's `start` or `end`) is `invalid`;
  - an empty string is `blank`;
  - text over its limit is `too_long`;
  - a list over its limit is `too_many`;
  - an empty list that needs at least one item (`versions`, `weekdays`, month `days`, specific `dates`, yearly `ranges`) is `required` on that list's own pointer. An empty `sessions` list is valid: the goal has no sessions;
  - repeated excused days are `duplicate`;
  - a snapshot title without any text is `required` on `/dhikr_snapshot/title`;
- **then, only for a structurally valid document, the goal rules** (`goal_validity`): each error is reported on the version (`N`) and session (`M`) it's in. Errors are sorted by field, then code:

| Goal rule | Field | Code |
|---|---|---|
| `target_required` | `/document/versions/N/count_policy/target` | `required` |
| `session_target_required` | `/document/versions/N/sessions/M/target` | `required` |
| `streak_threshold_value_required`, `streak_pace_not_allowed` | `/document/versions/N/count_policy/streak_threshold` | `invalid` |
| `end_date_and_duration` | `/document/versions/N/active_period/duration_days` | `not_allowed` |
| `make_up_not_allowed` | `/document/versions/N/make_up/window` | `not_allowed` |
| `sessions_with_minimum_or_cap` | `/document/versions/N/count_policy/minimum` or `…/maximum`, each that is set | `not_allowed` |
| `session_id_mismatch` | `/document/versions/N/sessions/M/id` | `mismatch` |
| `session_duplicate` | `/document/versions/N/sessions/M/id`, on each later one | `duplicate` |
| `session_window_empty` | `/document/versions/N/sessions/M/to` | `range` |
| `structural_change` | `/document/versions/N`, on each version that differs from the first | `mismatch` |
| `versions_out_of_order` | `/document/versions/N/from`, on each one not after the one before | `range` |
| `first_version_not_created_on` | `/document/versions/0/from` | `mismatch` |

A put's errors carry `/document` in front of these pointers.

**Receipts** (`$defs/receipt`), one per command, in order:

| `status` | Meaning | Carries |
|---|---|---|
| `applied` | Done | `version`, `revision`, `cascaded` |
| `duplicate` | Seen before with the same payload | `original`: the first receipt |
| `conflict` | `base_version` is stale | `current`: the server's `{version, state, document}` |
| `merged` | A tag create whose name exists | `merged_into` (the surviving tag), `current` (that tag) |
| `gone` | Deleted, or a merged tag ID | — |
| `rejected` | Invalid, over a limit, naming something missing, or a reused `command_id` | `code`, `fields` (`{field, code}`, pointers into the command), `current` (the server's copy to undo to, or `null`) |

**Cascades in receipts.** The `applied` receipt of a `user_tag` or `custom_dhikr` delete carries `cascaded`: one `{entity_type, entity_id, state, version, revision}` for every other entity the server changed at the same revision (personal records, and the goals a custom dhikr delete ended), ordered by `entity_type`, then `entity_id`, and empty when nothing cascaded. Every other `applied` receipt has `cascaded: null` (STYLE §3). Phones apply the entries to their known versions straight away, so the next edit of a cascaded record doesn't conflict; the documents arrive in the changes feed. A command already queued for a cascaded record before the receipt arrives, or sent in the same batch after the delete, still carries the old `base_version` and conflicts as normal.

Every receipt except `command_id_reused` is stored for 90 days, whatever its status, `cascaded` included. The response also carries `head_revision`.

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
| 300 goals that haven't ended, and 2,000 goals in all (ended included), per account | Server: `goal_limit_reached` (not in the fixtures, because of their size). Apps never reach them: they show a gentle note past about 7 daily goals instead (decision 42) |
| Goal: 1–100 versions (clients fold the oldest, `goal_version_add.json`), 500 pause ranges, 1,000 excused days; name and snapshot title 120 per language, snapshot Arabic 5,000 | Schema: `document_invalid` |
| Goal order: 2,000 IDs, no repeats | Schema: `document_invalid` |
| 20 tags per dhikr, no repeats | Schema: `document_invalid` |
| Custom dhikr: title 120 per language; Arabic, transliteration and translation 5,000 per language; 20 references | Schema, counted in Unicode code points: `document_invalid` |
| Tag name: 1–40 extended grapheme clusters, ≤ 128 UTF-8 bytes, already in display form; `normalized_name` equal to the server's | Server (the schema only bounds code points): `document_invalid` |
| 64 KB per document: at most 65,536 UTF-8 bytes of its compact JSON, non-ASCII unescaped | Server: `document_too_large` |
| Uploaded audio: 1–10,000,000 bytes, `audio/mpeg` or `audio/mp4` | Schema: `document_invalid` (`invalid` on `/audio`) |
| Uploaded audio names a ready asset of the account | Server: `audio_not_found` |
| Uploaded audio's `byte_size` and `content_type` are the asset's | Server: `audio_mismatch` |
| Upload limits (per file, 500,000,000 bytes per account, types) | [`../../audio/v1/`](../../audio/v1/), at upload time |
| Changes page: `limit` 1–500, default 200 | Schema (OpenAPI) |
| Receipts kept 90 days | Server |

**Graphemes.** Grapheme counts follow Unicode UAX #29 as each platform ships it. The fixtures avoid characters whose segmentation changed recently, such as Indic conjuncts and emoji sequences.

## Phones

Android and iOS keep an **outbox** (the queue) in each profile's database. The web has none: it sends each edit as a one-command batch and reads the feed from `after=0` when it loads and again after each edit.

### Saving an edit

The rules are in [`fixtures/outbox_enqueue.json`](fixtures/outbox_enqueue.json). The change and its command are saved in one local transaction.

- **Last command never sent:** the edit replaces it, keeping its `command_id`, `base_version` and position. A delete of an entity whose never-sent create is still queued removes that create instead.
- **Except when the replacement would get ahead of what it names:** if the new document references an entity whose never-sent put sits later in the queue, the command moves to immediately after the last such put. References are the tags in `tag_ids`, a `dhikr_personal`'s own custom dhikr, a goal's custom dhikr (`dhikr_id`) and the goals in a `goal_order`'s `goal_ids`; custom dhikr, tag and practice policy documents reference nothing, so their replacements never move. Everything else keeps its relative order. Without this, a record sent before its tag's, custom dhikr's or goal's create would be `rejected` with `tag_not_found` or `dhikr_not_found`, or lose a goal from the order.
- **Otherwise:** a command is added at the end. Its `base_version` is the previous command's `base_version` + 1, or the known version when nothing is queued for the entity.
- **Deleting a custom dhikr** also drops never-sent commands for its `dhikr_personal`. Its goals end locally in the same transaction (`ended: {on: today, reason: dhikr_deleted}`), without commands: the server ends them itself and lists them in the delete's `cascaded`. If the dhikr's create was never sent, its goals' never-sent commands are dropped too: the server has never had the dhikr, so they could only be rejected, and those goals stay on the phone, ended.
- **Deleting a tag** queues only the tag delete, never a `dhikr_personal` put: the server removes the tag from every record itself and reports them in the receipt's `cascaded`. Locally, the tag leaves every `dhikr_personal` document and every never-sent `dhikr_personal` command in the same transaction.

### Sending and pulling

The rules are in [`fixtures/apply_changes.json`](fixtures/apply_changes.json).

1. Send queued commands in order, in batches, then apply the receipts:

   | Receipt | What the phone does |
   |---|---|
   | `applied` | Records the version, and sets the known version of each `cascaded` entity it has (removing a deleted one) |
   | `duplicate` | Acts as its original |
   | `conflict` | Keeps the local edit and opens a conflict ("Changed on another device": **Keep mine** re-queues it on the server's version, **Use theirs** takes the server's copy). Later unsent commands for the entity are dropped. Three entity types open no conflict: a `practice_policy` merges by setting and re-queues the result ([`../../practice-settings/v1/README.md`](../../practice-settings/v1/README.md)); a `goal_order` merges the same way by `goal_order_merge`; a `goal` takes the server's document (below) |
   | `merged` | Rewrites the tag ID everywhere locally, in documents and unsent commands |
   | `gone` | Removes the entity |
   | `rejected` | Restores the server's copy, or removes the entity, and tells the user. Except `audio_not_found` and `audio_mismatch` on a custom dhikr put (below) |

   **Goal conflicts: the first to reach the server wins** (decision 44). A goal edit, or delete, whose receipt is `conflict`:
   - takes the server's document and version (a goal the phone deleted comes back), and opens no conflict. If the server's copy is deleted, the phone removes the goal;
   - drops the goal's later unsent commands;
   - adds the notice `goal_edit_not_applied`, unless the local document already equalled the server's. The phone remembers what the user did (pause, edit, end, delete) and the notice offers to do it again on the server's goal, for example "Isthighfar was updated on another device; your pause wasn't applied. Pause again?". Retrying is an ordinary new edit.
   - The exception is an automatic end (completed, or by date) that lost: it shows no notice, and the phone writes it again when it next finds it. The fixtures have no such case, because a command doesn't record whether it was automatic.

   Counts never conflict: they're an append-only log (slice 5).

   **Audio rejections lose nothing.** A custom dhikr put rejected with `audio_not_found` or `audio_mismatch` (for example, its asset was cleaned up while the put waited offline) keeps the local document:
   - if the recording's file is still on the phone, `audio` goes back to `{"local_only": true}` and the upload is queued again; it gets a new `asset_id`, and once confirmed it queues its own put naming the new asset;
   - otherwise `audio` becomes `null`;
   - the known version becomes the server's (`current.version`, or 0 when `current` is `null`), and the entity's unsent commands are replaced by one put of the kept document on that version, queued ahead of every other unsent command, where the rejected put was. So a dhikr whose create was rejected reaches the server before its personal record does, and its text syncs now rather than after the upload;
   - if the user has deleted the dhikr since, its unsent delete is replaced by a delete on the server's version, or dropped when the server has no copy;
   - the user gets a notice with the code.

2. Pull pages from the stored `after`. Each page is applied in one transaction together with its `next_after`.
   - A change other than a delete, to an entity with a queued command or an open conflict, updates only its known version.
   - A change older than the known version is ignored.
   - A delete cleans up exactly as a `gone` receipt does, even when the entity has queued commands or an open conflict: the entity goes, its unsent commands are dropped (sent ones wait for their receipts) and its conflict is closed. A deleted tag is removed from local personal records and unsent commands; a deleted custom dhikr takes its personal record and that record's unsent commands with it. Its goals stay: the server's ended documents arrive in the same page, at the same revision.
   - A delete of something the phone doesn't have is ignored.

**Cadence.** Sync on app start, after a change (with a 2 s debounce) and every 5 minutes while open. On failure, back off from 5 s to 5 min with ±20% jitter.

### Local profiles

The rules are in [`fixtures/profile_switch.json`](fixtures/profile_switch.json).

Each account's data lives in its own **profile**, a separate local database. A registry records every profile (local ID, account ID, email, feed `after`, last used) and which one is active. The fixtures leave out last used, which only orders the Settings list.

- **Before any sign-in** there is one anonymous profile. Edits are saved but never queued.
- **The first sign-in** asks once, only if the anonymous profile has data:
  - **Add to my account** adopts it and queues every entity as a put;
  - **Erase** replaces it with a fresh download.

  An empty anonymous profile is adopted silently. Goals count as data. The practice policy and the goal order aren't among the profile's entities until then, and don't count as data here:
  - the practice policy follows its own first-sign-in rule ([`../../practice-settings/v1/README.md`](../../practice-settings/v1/README.md));
  - the goal order is decided after the first complete pull: the account's `goal_ids` (none if it has no order), then the profile's goals the account's order doesn't name, in the profile's order. It's queued as a put on the account's version (0 if none) only when it differs from the account's.
- **Signing out** keeps the active profile. Its edits are queued but not sent.
- **Signing in again** as the same account sends its queue without asking.
- **Signing in as another account** switches to that account's profile, creating it if needed. The other profiles, unsent commands included, stay untouched.
- **Signing in from an anonymous profile with data, as an account that already has a profile on the phone,** asks the same question:
  - **Add to my account** merges the anonymous data into the account's profile: tags with the same name fold together locally (onto the account's tag), and every merged entity is queued as a put. A personal record both profiles have gets the union of their tags: the account profile's first, in their order, then the anonymous-only ones, without repeats after folding and capped at 20, keeping the account profile's. Goals keep their IDs and are queued as puts, and the goal order is the account profile's, then the anonymous goals in their order. The anonymous profile is then deleted;
  - **Erase** discards the anonymous data.

  Either way the account's profile becomes active. An empty anonymous profile asks nothing and stays as it is.
- **Remove from this device** warns first if the profile has unsent changes. Removing the active profile signs out and activates the anonymous profile if there is one, or else starts a fresh one. There is at most one anonymous profile at a time.
- **When an account no longer exists**, the phone offers to remove its profile or keep it. **Keep** marks the profile `account_deleted` and drops its unsent commands, which can never be sent: it stays usable offline, its edits are saved but never queued, it never syncs again, and it can be removed later. If it's the active profile, the phone signs out and the profile stays active.

**Two safety checks** keep accounts from mixing:
- the sync engine sends only when the signed-in account equals the active profile's account;
- every request carries that account in `X-Awrad-Account`.

## Fixtures

| File | Who runs it | Cases |
|---|---|---|
| `tag_name_normalization.json` | All four | Display and normalized tag names, limits |
| `custom_dhikr_validity.json` | All four | Which custom dhikr documents are valid, with `{field, code}` errors |
| `goal_document_validity.json` | All four | Which goal documents are valid, with `{field, code}` errors |
| `sync_receipts.json` | Server | A state (account ID, entities, receipts, tag aliases, audio assets, and the UTC date when the server ends a goal) and a batch: receipts, head, changes, aliases, stored receipts |
| `sync_changes_feed.json` | Server | Entities, `after`, `limit`: the page |
| `outbox_enqueue.json` | Android, iOS | Known versions, queue and an edit: the queue |
| `apply_changes.json` | Android, iOS | Local state, which recording files are on the phone, and a page, receipts or a resolution: local state, uploads queued again and notices. A `practice_policy` or `goal_order` carries its `base_document` |
| `profile_switch.json` | Android, iOS | Registry, event and choice: the prompt, the registry, what's queued, merged, synced and erased |

The goal rules a server applies are in [`../../goal-model/v1/`](../../goal-model/v1/) (`goal_validity`), and the goal order merge phones apply is `goal-model/v1/fixtures/goal_order_merge.json`.

`npm test` in `contracts/` validates the fixtures and runs `tools/check-sync-contract.mjs`. That script checks that:
- the OpenAPI examples match this schema;
- `custom_dhikr_validity` agrees with `$defs/custom_dhikr_document` plus the Qur'an range rule, with a `range` error for each reversed range;
- the non-rejected commands in `sync_receipts` are valid commands;
- each `applied` receipt in `sync_receipts` has `cascaded` exactly when its command is a `user_tag` or `custom_dhikr` delete, listing the entities changed at its revision;
- in `sync_receipts`, a put naming uploaded audio is applied only for a ready asset with the same size and type, `audio_not_found` exactly when the asset isn't ready, and `audio_mismatch` exactly when it is ready but disagrees;
- in `apply_changes`, an `audio_not_found` or `audio_mismatch` rejection keeps the local document, fixes its audio, re-queues it ahead of other unsent commands, queues the upload again exactly when the file is on the phone, and adds a notice;
- in `sync_receipts`, a goal put is `dhikr_not_found` exactly when its dhikr is neither built-in nor a custom dhikr the account has had; an applied goal follows the goal rules and is stored as sent, or ended when it names a deleted custom dhikr; a `document_invalid` goal breaks the schema or the goal rules; an applied goal order keeps only the account's non-deleted goals; a custom dhikr delete ends exactly its goals that hadn't ended, at its revision, on the right date;
- in `sync_receipts`, a put changing a stored goal's `dhikr_id` or `counts` is `goal_field_immutable`, with an `immutable` error on each, and only such a put is;
- in `apply_changes`, a goal conflict takes the server's goal (or removes it when the server's copy is deleted) with a `goal_edit_not_applied` notice unless nothing was lost, and a goal order conflict merges by `goal_order_merge`;
- `goal_document_validity` says valid exactly when the document matches `$defs/goal_document` and the goal rules, and lists exactly the goal rules' field errors for a structurally valid document. Structural errors are pinned by the cases only;
- the names `tag_name_normalization` accepts make valid tag documents.
