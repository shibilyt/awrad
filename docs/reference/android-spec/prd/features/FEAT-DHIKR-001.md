# FEAT-DHIKR-001 — Custom dhikr and tags

**Status:** local create/edit/tag management is implemented; multi-category custom content participates in the current shared contract.

## Goal

Allow users to preserve personal remembrance text and organize it alongside bundled dhikr.

## Requirements

- **DHIKR-001 [OBSERVED]** Create and edit a custom dhikr through the library/detail entry points.
- **DHIKR-002 [OBSERVED]** Store dhikr identity, text/content fields, primary category and supported ordered category selection locally; use versioned mappers for sync rather than serializing Room records directly.
- **DHIKR-003 [OBSERVED]** Allow user tags and dhikr-tag assignment management on the Manage Tags route.
- **DHIKR-004 [OBSERVED]** Normalize tag uniqueness/display and filter behavior according to `contracts/behavior-model/v1/fixtures/tag-normalization-contract.json` and related fixtures. Multi-filter composition follows the current contract.
- **DHIKR-005 [OBSERVED]** For the API contract, a custom dhikr's singular `category` remains the primary and equals the first ordered item in `categories`; an older client omitting the array is compatible as `[category]`.
- **DHIKR-006 [OBSERVED]** Validate custom audio separately through the Audio feature's MIME, duration, size, and file-ownership rules.
- **DHIKR-007 [OBSERVED]** Built-in records are content-managed by canonical keys/UUIDs; editing display text must not change their identity.

## Edge behavior

Reject invalid content before persistence. A failed save must retain the user's entered draft where the screen lifecycle allows. Tag whitespace/case normalization must not create visually duplicate tags. Deleting a tag should remove or detach assignments according to current behavior; exact confirmation copy is **[UNKNOWN]**.

## Acceptance examples

1. A saved custom dhikr is available from the local library offline.
2. Its primary category equals the first ordered category on sync.
3. Equivalent normalized tags do not create duplicates.
4. An unsynced change is kept in local state/outbox until accepted or represented as a conflict.

## Open decisions

Confirm required text fields, transliteration/translation validation, destructive-delete UX, and whether custom audio is copied into backup/export.

