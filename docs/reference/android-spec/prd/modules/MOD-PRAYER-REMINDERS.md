# MOD-PRAYER-REMINDERS — Prayer context and reminders

## User outcome

The user can view locally calculated prayer context and schedule reminders for goal, daily, urgency, or Wird practice.

## Scope and requirements

Own location/city configuration integration, local Adhan calculations, day-reset/prayer settings, reminder plans, Android alarms/work/receivers, notification permissions and reliability affordances.

See [Prayer context](../features/FEAT-PRAYER-001.md) and [Reminders](../features/FEAT-REMIND-001.md).

## Boundaries

Prayer calculations are local. Location labels are not coordinates. Exact-alarm/notification permissions and OEM policy are platform dependencies, not product guarantees. Account policy is shared; device context remains per-installation.

## Acceptance

Manual city selection works without GPS; denied system settings do not block counting; reboot/time changes reconcile scheduled reminders without duplicates.

