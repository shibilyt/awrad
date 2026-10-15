# FEAT-SETTINGS-001 — App and practice settings

**Status:** implemented settings hub; domain writes are delegated to owned repositories/features.  
**Route:** `settings`.

## Goal

Let users configure app appearance, language, counting, prayer context, reminders, audio, account/sync, and local data actions.

## Requirements

- **SET-001 [OBSERVED]** Provide settings entry points for profile/account, theme, language, counter behavior, prayer/calendar context, reminders, audio downloads, sync state/actions, and local-data actions.
- **SET-002 [OBSERVED]** Persist local preferences in DataStore and product records in their feature-owned Room repositories.
- **SET-003 [OBSERVED]** Theme supports light/dark/system; app defaults to following system unless a stored preference chooses otherwise.
- **SET-004 [OBSERVED]** Counter controls include vibration, keep screen on, click sound, text size, and line spacing as currently consumed by the counter.
- **SET-005 [OBSERVED]** Prayer and day-boundary changes route through current practice settings repository/contract; server shared policy is revisioned and device location/timezone remains installation-scoped.
- **SET-006 [OBSERVED]** Audio management uses app-owned downloaded/custom files and does not require shared media access.
- **SET-007 [OBSERVED]** Include confirmation for destructive reset/delete-goal actions currently shown. Keep recovery semantics tied to current repository behavior.
- **SET-008 [OBSERVED]** Settings may show sync health/conflicts; local practice remains usable when sync is unavailable.
- **SET-009 [UNKNOWN]** Exact reset scope and whether reset affects authenticated server state must be surfaced from current UI/actions before reconstruction.

## Acceptance examples

1. Theme/language changes update subsequent screens and persist after app restart.
2. Reset/delete actions require explicit user confirmation and report completed scope accurately.
3. Turning off a reminder or deleting a goal reconciles scheduled system work.

## Open decisions

Confirm reset versus clear-data semantics, local-only guest data export, account deletion support on Android, and the settings sections to retain if any are hidden by account state.

