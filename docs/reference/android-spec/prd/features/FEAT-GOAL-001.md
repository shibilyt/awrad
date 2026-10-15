# FEAT-GOAL-001 — Goal creation and management

**Status:** implemented with Room-backed goals and domain validation.  
**Screens:** Goals, Create Goal, Goal Detail, Edit Goal, Edit Schedule, Edit Reminders.

## Goal

Let a user turn a dhikr into a repeatable practice with target, schedule/slot, and reminder context and manage its lifecycle.

## Requirements

- **GOAL-001 [OBSERVED]** Create a goal from the Goals flow, onboarding, or a dhikr with its identity carried to the composer.
- **GOAL-002 [OBSERVED]** Persist goal definition and child records locally before optional sync. Current shared identities are UUIDv4; do not revive legacy integer IDs.
- **GOAL-003 [OBSERVED]** Support goal detail and edit paths for the goal, schedule, and reminders.
- **GOAL-004 [OBSERVED]** Goal validation covers invalid duration, non-positive streak threshold, invalid schedule/timing/count policy/reminder configuration, and missing target where the goal is not a tracker.
- **GOAL-005 [OBSERVED]** Support goal lifecycle distinctions: active, paused (`is_active=false`, no completion timestamp), completed (completion timestamp present), and deleted/tombstoned according to the progress contract.
- **GOAL-006 [OBSERVED]** Model recurrence and slot ownership with stable identities; slots referenced by count history are archived rather than removed.
- **GOAL-007 [OBSERVED]** A successful goal creation can navigate directly to that goal's counter.

## Rules and edge cases

GoalFactory/domain validation is authoritative for valid combinations. Goal scheduling may include daily/recurring schedules, date/weekday/month-day selection, time context, and count policies. Exact forms and allowed combinations should be read from current source/contracts when implementing. Reminder permission denial is owned by the Reminder PRD. A tracker without a target is allowed; do not block it with a target-required rule.

## Acceptance examples

1. Invalid goal values are rejected before persistence.
2. A goal created from a dhikr retains the selected dhikr identity.
3. Pausing does not mark the goal completed; completion uses the explicit completion state.
4. A slot with historical counts can be archived without invalidating history.

## Open decisions

Confirm exact displayed target/session modes, schedule picker interactions, and whether “delete” means local removal, tombstone, or purge in each user-facing context.

