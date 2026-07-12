# 004 — Notification Scheduling Strategy

**Status:** Accepted
**Date:** 2025-02
**Context:** Notifications, Reminders, Background Execution

---

## Context

Dhikr reminders need to fire at precise times — "remind me at 8:00 AM" should mean 8:00 AM, not "sometime between 8:00 and 8:30 when the system decides." Android's background execution restrictions make this challenging, especially with OEM battery killers.

## Options Considered

### Option A: WorkManager only
- Schedule periodic or one-shot workers for each reminder
- WorkManager batches work for battery efficiency
- **Problem:** WorkManager is intentionally inexact. A reminder scheduled for 8:00 AM might fire at 8:15 or 8:45. Users would complain about late reminders.

### Option B: AlarmManager only
- `setAlarmClock()` for maximum reliability (survives Doze, never batched)
- Must reschedule on boot, timezone change, app update
- No built-in retry or watchdog

### Option C: Hybrid — AlarmManager primary + WorkManager watchdog
- AlarmManager `setAlarmClock()` for all time-sensitive reminders
- WorkManager as a daily safety net that reschedules all alarms at 00:15 AM
- Covers both precision and resilience

## Decision

**Option C** — Hybrid approach.

## Reasoning

1. **`setAlarmClock()` is the most reliable scheduling API on Android.** It is designed for user-facing alarms (like alarm clock apps). Unlike `setExact()` or `setExactAndAllowWhileIdle()`, it is guaranteed to fire on time even in Doze mode.

2. **WorkManager cannot guarantee timing.** By design, WorkManager batches work for battery optimization. For a prayer-linked reminder that should fire at Fajr+10 minutes, even a 5-minute delay is unacceptable.

3. **The watchdog catches edge cases.** OEM battery killers (Samsung, Xiaomi, Huawei) sometimes kill the alarm service entirely. The daily WorkManager task at 00:15 AM reschedules all alarms for the new day, acting as a recovery mechanism.

4. **Follow-ups use `setExactAndAllowWhileIdle()`.** Follow-up reminders (3 hours after initial) are less time-critical, so we use a lighter-weight exact alarm API that consumes fewer resources.

## Alarm Types & Request Codes

Deterministic request codes prevent collisions:

| Type | Base Code | Formula |
|------|-----------|---------|
| Goal reminder | 10,000 | `10000 + goalId` |
| Prayer slot | 20,000 | `20000 + (goalId * 20) + slotIndex` |
| Follow-up | 40,000 | `40000 + goalId` |
| Global | 30,000 | Fixed: `30000` |
| Test | 50,000 | `50000 + goalId` |

## Follow-Up Design

When a reminder fires and the goal is not yet completed for the day:
1. Show the notification.
2. Schedule a follow-up 3 hours later.
3. The follow-up has a 22:00 (10 PM) cutoff — no notifications after that.
4. Follow-ups don't chain (no follow-up of a follow-up).

**Why 3 hours?** Enough time that the user isn't pestered, short enough that they're still likely awake and have time to complete the dhikr.

**Why 22:00 cutoff?** Reminders after 10 PM are disruptive and unlikely to be acted on. Respect the user's sleep.

## Rescheduling Triggers

All alarms are rescheduled on:
- App startup (initialization)
- Device boot (`BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`)
- App update (`MY_PACKAGE_REPLACED`)
- Timezone change (`TIMEZONE_CHANGED`)
- System time change (`TIME_SET`)
- Exact alarm permission grant
- Daily watchdog (00:15 AM)

## Consequences

- Requires `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` permissions.
- A `BroadcastReceiver` must handle alarm intents and system events.
- The rescheduling logic must be fast (runs on every app launch).
- OEM battery optimization guidance is needed (see Decision 013).
