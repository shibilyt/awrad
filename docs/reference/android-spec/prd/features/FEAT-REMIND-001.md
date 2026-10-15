# FEAT-REMIND-001 — Local reminders and notification reliability

**Status:** implemented with Android alarm/WorkManager lifecycle handling.  
**Entry points:** onboarding, goal create/edit, Settings, Wird selection.

## Goal

Schedule local reminders for a goal, daily remembrance, urgency nudges, or Wird and route the user to the related practice.

## Requirements

- **REMIND-001 [OBSERVED]** Model goal reminder rules locally and schedule them through the current reminder planner/scheduler.
- **REMIND-002 [OBSERVED]** Support goal reminder alarms, daily remembrance work, urgency nudges/retries, and Wird reminders as distinct types.
- **REMIND-003 [OBSERVED]** Use notification channels/builders and stable identity so updates/reschedules replace the intended reminder instead of duplicating it.
- **REMIND-004 [OBSERVED]** Handle notification permission and exact-alarm eligibility. When exact scheduling is unavailable, report/open the relevant system settings or use the current fallback policy; do not promise exact delivery if unavailable.
- **REMIND-005 [OBSERVED]** Reconcile/reschedule on boot, package replacement, time/timezone change, and exact-alarm access changes.
- **REMIND-006 [OBSERVED]** Tapping a goal reminder opens its goal/slot counter; tapping a Wird reminder opens its intended reader/definition or a safe list fallback.
- **REMIND-007 [OBSERVED]** Respect user urgency preference and the notification-obligation engine's eligibility/deadline/suppression rules in current behavior fixtures.
- **REMIND-008 [OBSERVED]** Battery optimization help may explain system/OEM restrictions; that guidance cannot guarantee OEM delivery behavior.

## Acceptance examples

1. Reboot/timezone change causes schedules to be reconciled, not blindly duplicated.
2. Denying `POST_NOTIFICATIONS` does not prevent local counting, and the UI does not claim a notification was delivered.
3. A stale notification intent cannot open the wrong goal/slot.
4. Completed goals/slots cancel reminders according to current policy.

## Open decisions

Confirm fallback behavior for inexact alarms and disabled notifications on each supported Android version/OEM; check system integration on physical hardware before claiming exact delivery.

