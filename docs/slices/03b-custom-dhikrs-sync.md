# Slice 3b: Custom dhikrs, tags and the change queue

Status: Agreed (contract accepted 2026-10-28)
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 3b
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

Users can create, edit and delete their own dhikrs and tag any dhikr, offline on phones and online on the web. Once they're signed in, it all reaches every device. This slice builds the **change queue**, the sync mechanism that goals (slice 4) and counting (slice 5) reuse.

## Decisions (2026-10-28)

- **Sync starts here.** Custom dhikrs and tags are the change queue's first users.
- **Audio:**
  - Custom dhikrs can hold a recording kept on the device.
  - Uploading it to private storage is slice 3c: 10 MB per file, 500 MB per account, MP3 and M4A/AAC.
- **Duplicate tags merge.** Two devices that both create "Morning" offline end up with one tag, and every dhikr keeps it.
- **Local profiles.** A phone keeps each account's data in its own local profile, labelled with the account, and never mixes two accounts. Before the first sign-in there is one anonymous profile; the first sign-in asks once to add it to the account or erase it.
- **The web edits too.** It's online only and sends each edit straight away, with no queue.
- **Contract details agreed (2026-10-28):** Qur'an references are `ayah_start`/`ayah_end` everywhere (the catalog is renamed, so each app updates its catalog parsing in this slice); a refresh for a deleted account answers `401 account_deleted`, and the phone offers to remove that profile. The mobile apps stay complete without an account (ADR-2026-10-28): signed out, nothing contacts the server.

## Decisions after the build (2026-10-28)

Gaps found while building the four platforms, closed in `contracts/` (sync README, fixtures and `components.md`):

1. **Anonymous data, existing profile.** Signing in from an anonymous profile with data, as an account that already has a profile on the phone, asks: **Add to my account** merges the anonymous data into that profile (same-name tags fold together locally; a personal record both have gets the union of their tags, the account's first, capped at 20; every merged entity is queued as a put); **Erase** discards it and activates the existing profile (`profile_switch.json`).
2. **Removing the active profile** signs out and activates the anonymous profile if one exists, or else creates a fresh one. There's at most one anonymous profile at a time.
3. **Keeping a deleted account's profile.** **Keep** on the active profile signs out; the profile stays active and usable offline, is marked `account_deleted`, never syncs and can be removed later. Its unsent commands are dropped, and later edits are saved but never queued.
4. **Deletes in a changes page** clean up exactly as a receipt does: a deleted tag leaves local personal records, a deleted custom dhikr takes its personal record, and unsent commands for the deleted entity are dropped (`apply_changes.json`).
5. **Cascades in receipts.** The `applied` receipt of a `user_tag` or `custom_dhikr` delete carries `cascaded` (`{entity_type, entity_id, state, version, revision}` for every entity changed at that revision; `null` on other applied receipts). Phones update their known versions from it straight away; an edit already queued or in the same batch conflicts as normal. Deleting a tag queues only the tag delete, never personal-record puts.
6. **Ranges and sizes.** A Qur'an reference needs `ayah_end` ≥ `ayah_start` (field error `range`; the catalog check enforces it for built-ins). 64 KB per document means 65,536 bytes of UTF-8 JSON; 10 MB of audio (3c) means 10,000,000 bytes.
7. **Components:** filter chip, conflict banner, "Change refused" notice, multi-line text field, the Sources section on the dhikr detail, and the "Your dhikrs" collection tile (`contracts/design-system/v1/components.md`).
8. **Queue order on replace.** A replaced never-sent command keeps its place and `command_id`, unless its new document references a tag or custom dhikr whose never-sent put sits later in the queue; then it moves to just after the last such put, so the server never sees a personal record before its tag or dhikr exists (`outbox_enqueue.json`).

## Scope

| In scope | Out of scope (and where it goes instead) |
|---|---|
| The change queue: commands, receipts, the changes feed, conflicts, deletes | Goals and counts (slices 4, 5), on the same queue |
| Custom dhikrs: create, edit, delete; same shape as built-ins (`$defs/dhikr`) | Virtues on custom dhikrs; custom collections (later) |
| User tags: create, rename, delete; tag built-in and custom dhikrs | Favourites and notes (later, in the same per-dhikr record) |
| Local audio on a custom dhikr (import, play, replace, remove) | Uploading audio (3c) |
| Local profiles: anonymous, then one per account; switching accounts; removing an account's data from the phone | Restoring deleted items |
| Library: "Your dhikrs" collection, tag chips, a tag filter | |

Platforms: server ☑ · Android ☑ · iOS ☑ · web ☑ (online, no queue)

## What we keep and drop from the old progress sync

The frozen design is in `docs/progress-sync-architecture.md` and ADR-2026-07-16/24.

| Old | New |
|---|---|
| Per-account revision under a row lock | **Keep** |
| Command IDs with idempotent receipts and a payload hash | **Keep** (IDs are UUIDv7) |
| Whole-document version checks | **Keep** |
| Tombstones | **Keep**. A delete is final; no restore, purge or fences |
| Actors, contiguous sequences, fork and adoption, incarnations | **Drop**. Receipts plus in-order batches are enough |
| Transfer sessions, checksums, generations | **Drop**. One "changes after revision N" feed |
| JSONB entities plus legacy tables (written twice) | **Drop**. One entity table |
| Separate tag-assignment entities, coalesced on receipt | **Change**. A per-dhikr personal record holds `tag_ids`; the server remembers merged tag IDs and rewrites references itself |
| Rewriting a command after it was sent | **Drop**. Only a never-sent command may be replaced |
| iOS diffing the whole database on every write | **Drop**. Each edit records its own command |

## The change queue

### Entities in 3b

| `entity_type` | `entity_id` | Document |
|---|---|---|
| `custom_dhikr` | a new UUIDv7 | `$defs/dhikr` without `key`, `virtues` or `audio`, plus `audio: {local_only: true}` or null |
| `user_tag` | a new UUIDv7 | `{name, normalized_name}` |
| `dhikr_personal` | the dhikr's ID (built-in or custom) | `{tag_ids: [...]}` (≤ 20) |

**Limits:**
- 1,000 custom dhikrs per account;
- 100 tags per account;
- 20 tags per dhikr;
- 64 KB per document.

**Tag names:**
- 1–40 characters, 128 bytes at most;
- `normalized_name` follows the shared tag-normalization fixture: trim, collapse spaces, NFC, case-fold;
- the server recomputes it and rejects a mismatch.

### Commands (`POST /api/v1/sync/commands`)

The request has 1–100 commands, applied in order. Each command is:

```json
{
  "command_id": "<uuidv7>",
  "entity_type": "custom_dhikr",
  "entity_id": "<uuid>",
  "op": "put",
  "base_version": 3,
  "document": { "…": "…" }
}
```

- **`put`** creates the entity (`base_version` 0) or replaces it.
- **`delete`** marks it deleted.
- **Receipts:** each command gets one receipt, in the same order. A command's outcome never undoes the others.

| `status` | Meaning | Carries |
|---|---|---|
| `applied` | Done | `version`, `revision` |
| `duplicate` | Same `command_id` and payload as before | the original receipt |
| `conflict` | `base_version` is stale | the server's current entity (version, state, document) |
| `merged` | A `user_tag` create whose name already exists | `merged_into` (the existing tag ID) |
| `gone` | The entity is deleted | — |
| `rejected` | Invalid, over a limit, or a reused `command_id` with a different payload | `code`, `fields` |

**Server rules:**
- One account's batches are serialized: its revision row is locked, and every applied change gets the next revision.
- Receipts are kept for 90 days.
- **Tag merging:** a merged tag's ID is remembered as an alias. Any later `dhikr_personal` document naming the alias is rewritten to the surviving tag ID. That covers a merge and its tag use landing in the same batch, the bug that broke the old iOS client.
- **Deleting a tag** removes it from every `dhikr_personal` document, at the same revision.
- **Deleting a custom dhikr** deletes its `dhikr_personal` too. From slice 4, it's blocked while goals use it.

### Changes feed (`GET /api/v1/sync/changes?after=N&limit=200`)

- **Response:** `{changes: [{entity_type, entity_id, state, version, revision, document?}], next_after, has_more, head_revision}`, ordered by revision.
- **`after=0`** is a full download: it lists only active entities.
- **`after>0`** also includes deletes.
- **Deletes of unknown entities:** a client ignores a delete for something it doesn't have.

### Clients (Android and iOS)

**Saving an edit:** the change and its command go into the queue in one local transaction. The command is `pending`, and its `base_version` is the last version this device knows for the entity. If the same entity already has a pending, never-sent command, that command is replaced (same `command_id`, same position unless its document now references a tag or custom dhikr whose never-sent put is later in the queue, in which case it moves to just after the last of those); once it has been sent, a new command is added after it.

**Sending:**
- When signed in and online: send pending commands in order, in batches.
- After a receipt, drop the command and record the entity's new version.
- `merged`: replace the tag ID everywhere locally.
- `rejected`: undo locally to the server version and tell the user.
- `conflict`: keep the local edit and mark the dhikr "Changed on another device". The user picks **Keep mine** (re-sent on the server's version) or **Use theirs**.

**Pulling:**
- After sending, read the changes feed from the stored `after` and apply each change in one transaction with the new `after`.
- A change to an entity that has a pending local edit updates only its known server version; the local edit is kept and its conflict resolved on send.

**Cadence:**
- Sync on app start, on a change (after a 2 s debounce) and every 5 minutes while open.
- Back off from 5 s to 5 min, with ±20% jitter.

**Local profiles (who the data on a phone belongs to):**
- **Profiles and the registry.** Each profile is its own local database file. A small registry records:
  - every profile: local ID, account ID (none for the anonymous profile), email for display, its changes-feed `after`, and when it was last used;
  - which profile is active.
- **Before any sign-in:** there's one anonymous profile. Everything is saved locally and nothing is queued for sending.
- **First sign-in as an account (A):**
  - If the anonymous profile has data, the app asks once:
    - **Add to my account:** the anonymous profile becomes A's profile, every entity in it is queued as a `put`, and then A's server data is pulled and merged (tags with the same name merge);
    - **Erase:** the anonymous profile is deleted and A's profile is downloaded fresh.
  - If the anonymous profile is empty, A's profile is simply created.
- **Signing out** keeps the active profile: the last account that signed in. New edits go on being saved and queued for that account; they just aren't sent.
- **Signing in as the same account** sends the queue and pulls, with no question asked.
- **Signing in as a different account (B):**
  - The phone switches to B's profile, downloading it if it's new. A's profile, including commands not yet sent, stays untouched on the phone and becomes active again when A signs in.
  - Two accounts' data never mix. A profile's queue is only ever sent with its own account's token.
- **Removing an account's data:** Settings lists the profiles on the phone, each with **Remove from this device**. It warns first if the profile has unsent changes.
- **A deleted account:** if signing in shows a profile's account no longer exists, the phone offers to remove that profile.
- **Two safety checks:**
  - the sync engine sends only when the signed-in account ID equals the active profile's account ID;
  - every sync request carries the account ID it expects (`X-Awrad-Account`), and the server refuses a mismatch with `409 account_mismatch`.

### Web

The web sends each edit as a one-command batch through the same endpoint, with the browser session plus CSRF. It reads the changes feed from `after=0` when it loads, and reads again after each edit. It has no queue and no offline state.

## Domain and fixtures (step 3)

- **`CONTEXT.md`:**
  - **Custom dhikr**, **Tag**, **Change queue**, **Command**, **Revision**, **Conflict**.
  - **Personal record**: a user's own data about one dhikr, for now its tags.
  - **Local profile**: one account's data on a phone (or the anonymous data before any sign-in), kept apart from every other account's.
- **Fixtures** (`contracts/sync/v1/fixtures/`):
  - `tag_name_normalization.json`: the old v1 cases, ported to awrad-fixture/1, plus new ones;
  - `custom_dhikr_validity.json`: which custom dhikr documents are valid;
  - `sync_receipts.json`: given server state and a batch, the receipts and the resulting state. The server runs it; it's the protocol spec;
  - `outbox_enqueue.json`: given local state and a pending queue, the queue after an edit (replace-if-unsent, append-if-sent). Android and iOS run it;
  - `apply_changes.json`: given local state, pending commands and a changes page, the resulting local state and conflicts. Android and iOS run it.
  - `profile_switch.json`: given the profile registry, the signed-in account and the user's choice, the resulting active profile and what is queued, kept or erased. Android and iOS run it.

## Contract (step 4)

- **Operations:**
  - `post_sync_commands` `POST /api/v1/sync/commands`;
  - `list_sync_changes` `GET /api/v1/sync/changes`.
  - Both work with a bearer token (mobile) or a cookie plus CSRF (web), and both require `X-Awrad-Account`.
- **Schemas** in `contracts/sync/v1/sync.schema.json`: command, receipt, change, and the three entity documents.
- **ADR:** "The change queue", replacing progress sync v1 for the rebuild.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | Sync tables (heads, entities, receipts, tag aliases), the two endpoints, the rules above, fixture runners | `mix validate` | ☑ |
| awrad-android-next | Room entities and outbox, sync engine, binding prompt, custom dhikr editor, tags, Library additions, local audio | Gradle validation | ☑ |
| awrad-ios-next | Same as Android, on SwiftData | `scripts/validate` | ☑ |
| awrad-web-next | Custom dhikr editor and tags over the API | `npm run validate` | ☑ |

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| Create a custom dhikr offline, sign in, add to account; it appears on the other platforms | ☑ | ☑ | ☑ | Real server on :4100; phone data seen on the web and in the API feed |
| The same tag created on two devices offline merges | ☑ | ☑ | — | Protocol run against the real server (merge, alias rewrite in the same batch) plus the shared fixtures on both phones |
| Edit the same dhikr on two devices: conflict, then Keep mine or Use theirs | ☑ | ☑ | ☑ | Android Keep mine, iOS Use theirs, web Keep mine, each against a second device's earlier edit |
| Delete on one device; it disappears on the others | ☑ | ☑ | ☑ | Protocol run (tag delete with `cascaded`, seen by the second device) plus the `apply_changes` page-delete fixtures |
| Anonymous use → sign in (add) → sign out → more edits → sign in again: queued edits sync, no prompt | ☑ | ☑ | — | Zero requests while signed out (network capture on Android, connection monitor on iOS) |
| Sign in as B after A: B's data only; A's unsent edits kept and sent when A returns | ☑ | ☑ | — | |
| Remove an account's data from the phone, with a warning about unsent changes | ☑ | ☑ | — | Remove after `account_deleted` on both phones; the unsent-changes warning is covered by `profile_switch` and profile tests |

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
