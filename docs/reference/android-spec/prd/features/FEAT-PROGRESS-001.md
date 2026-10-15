# FEAT-PROGRESS-001 — Progress, history, and streaks

**Status:** local calculators and count history are implemented; screen presentation is distributed across Home, Goals, Counter, and Settings.

## Goal

Let users review progress honestly across current goals, practice dates, slots, and sessions.

## Requirements

- **PROGRESS-001 [OBSERVED]** Derive current goal totals from count records and supported local projection/cache; `total_completed_count` is derived, not an independent sync authority.
- **PROGRESS-002 [OBSERVED]** Show per-goal/slot count history and allow explicitly confirmed corrections where the counter exposes them.
- **PROGRESS-003 [OBSERVED]** Resolve recurrence and effective practice date using configured day-reset/calendar/prayer context rather than device wall-clock assumptions alone.
- **PROGRESS-004 [OBSERVED]** Evaluate streak/progress eligibility through shared behavior rules. Match fixtures/contracts for recurrence, effective day, count caps, slot selection, and streaks.
- **PROGRESS-005 [OBSERVED]** Keep historical dates stable when timezone/location context changes; sync contract does not rebucket historical ledger credits.
- **PROGRESS-006 [OBSERVED]** Display account-synced community totals as an aggregate with their stated approximate semantics; do not confuse them with a user's full offline total.

## Integrity requirements

History uses signed 64-bit counts and stable goal/slot IDs. Corrections consume only count credits observed by the user/client basis and never make negative debt. A locally cached aggregate may be refreshed transactionally but must remain derived. Date/time displays should distinguish local practice date from UTC transport timestamps.

## Acceptance examples

1. A goal's shown total matches its underlying count projection.
2. A correction cannot consume a later unseen increment.
3. A timezone or day-reset preference change does not rewrite existing ledger dates.
4. Offline local progress can exceed data currently visible in server-backed community aggregates.

## Open decisions

The exact calendar/chart/streak visuals, empty-history content, and export format are not established by Phase 1 and need confirmation before pixel-accurate recreation.

