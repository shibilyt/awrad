# FEAT-WIRD-001 — Wird library, scheduling, and reader

**Status:** bundled/custom definitions and local reading sessions are implemented.  
**Routes:** list, create, detail, edit, and reader.

## Goal

Let users browse or create a structured Wird, select when to read it, and persist reading progress locally.

## Requirements

- **WIRD-001 [OBSERVED]** Browse bundled and user-created Wird definitions from Home/Library entry points.
- **WIRD-002 [OBSERVED]** Create/edit user Wird definitions locally; inspect detail and selected/scheduled state.
- **WIRD-003 [OBSERVED]** Read a specific part through `wird_reader/{wirdId}/{partId}` and navigate contents/parts with reader controls.
- **WIRD-004 [OBSERVED]** Persist Wird session/progress in Room independently of network availability.
- **WIRD-005 [OBSERVED]** Support the current bundled Dalail al-Khayrat content asset. Its content/structural identities follow `contracts/wird-model/v1/`; generated assets must remain canonical.
- **WIRD-006 [OBSERVED]** Local reminder scheduler can open a selected Wird from a notification/deep link.
- **WIRD-007 [OBSERVED]** Built-in structural IDs are UUIDv3-derived from content paths; reordering reviewed content is an identity migration, not a cosmetic edit.
- **WIRD-008 [UNKNOWN]** Completion criteria, exact cadence/selection UI, and progress reset behavior must follow current implementation and behavior fixtures.

## Acceptance examples

1. A built-in Wird can be read offline.
2. Moving between parts retains the selected definition and updates the local session.
3. Generated bundled content matches the versioned source/manifest.
4. A scheduled notification opens the intended Wird route or list fallback.

## Open decisions

Confirm which built-ins are available, how weekday schedules are presented, and whether user-created Wird is eligible for cross-device sync (the current content contract alone does not establish that).

