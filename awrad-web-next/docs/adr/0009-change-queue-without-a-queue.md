# 0009: The web edits through the change queue with no queue of its own

Status: Accepted (2026-10-28).

## Context

Slice 3b brings the change queue (root ADR-2026-10-28, `contracts/sync/v1/`): custom dhikrs, user tags and per-dhikr personal records, written as commands with a `base_version` and read from a changes feed. Phones keep an outbox, known versions and a feed position per local profile. The web is online-only and signed in (ADR-2026-10-15), and the brief says it sends each edit straight away as a one-command batch. The web still has to pick where the account's entities live, when the feed is read, how a stale `base_version` reaches the person, and how custom dhikrs share the built-ins' screens.

## Decision

- **The query cache is the only copy.** `src/shared/sync` reads every page of `list_sync_changes` from `after=0` into one `SyncState` (active entities by type and ID, plus the head revision) under the TanStack Query key `["account", "sync", <account id>]`. Signing out (`forgetAccount`) drops it, and another account never shares it. There's no outbox, no stored `after` and no local profile.
- **One command per edit.** `useSendEdit` posts a single command with a new UUIDv7 `command_id` and `X-Awrad-Account` (the signed-in account's ID); the API client adds CSRF. The receipt is applied to the cache at once (`applyReceipt`, a duplicate as its original), then the whole feed is read again from `after=0`. The full reread, rather than an incremental one from `head_revision`, keeps the web stateless; an account is at most about a dozen pages.
- **Edits are based on what was on screen.** The editor, the tag sheet and rename take `base_version` from the version shown when they opened, not the latest refetch, so a change made elsewhere meanwhile is a `conflict` and is never silently overwritten.
- **Conflicts ask the person.** `useEdit` turns a `conflict` receipt into the "Changed on another device" dialog (`ChoiceDialog`, which can't be dismissed): it shows the server's copy; **Use theirs** keeps it (already in the cache), **Keep mine** sends the same edit again on the server's version. The calling page awaits the settled result.
- **Session problems settle the page.** `401` from either operation forgets the account (the Library shows signed out); `409 account_mismatch` drops the account's entities and refetches who is signed in.
- **Custom dhikrs wear the catalog's shape.** `asDhikr` maps a `custom_dhikr_document` to the catalog `Dhikr` type (its ID as its key; each text in the UI language, then English, then any; no virtues, catalog tags or audio), so the rows, the detail and the tag filter treat both alike. The detail route `/library/dhikrs/$key` takes a catalog key or a custom dhikr's ID.
- **Shared rules are client checks only.** `normalizeTagName` and `customDhikrProblems` run the shared fixtures and guard the forms; the server's receipt stays the authority, and its `rejected` fields map onto the same form fields.

## Consequences

- A page reload costs one full read of the feed; nothing survives in the browser between visits, matching the online-only rule.
- Each edit is two requests (the command, then the reread), plus a CSRF token fetch for the first write.
- Phones' fixtures (`outbox_enqueue`, `apply_changes`, `profile_switch`) and the server's (`sync_receipts`, `sync_changes_feed`) don't apply to the web; `src/shared/sync/fixtures.test.ts` lists them as another platform's, so a new fixture file still fails until it's classified.
- When slice 4 adds goals, they're new entity types in the same `SyncState`, and a custom dhikr's delete can come back `rejected` while goals use it.
