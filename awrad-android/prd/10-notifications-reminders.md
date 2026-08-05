# 10 - Notifications & Reminders

## Overview

The app supports configured goal, prayer-linked, and daily reminders plus the cross-platform notification obligation engine. Configured reminders retain their existing behavior. The obligation engine adds deadline warnings, streak guardians, live-state cancellation, exact-alarm/WorkManager fallback, and a global urgency preference.

The current cross-platform timing and lifecycle contract is documented in [`../../docs/notification-obligation-engine.md`](../../docs/notification-obligation-engine.md). Where older requirements below describe fixed prayer offsets, numeric request-code identity, or a single follow-up path, current executable planner, identity, reconciliation, and delivery tests are authoritative for engine-generated urgency nudges.

---

## Reminder Types

### 1. Goal-Specific Reminders

Triggered at a user-configured time for goals with notifications enabled.

**Requirements:**
- R-NOTIF-001: When a goal has `notificationEnabled = true`, schedule a daily alarm at `notificationHour:notificationMinute`.
- R-NOTIF-002: Only schedule for goals that are active, not completed, and due today.
- R-NOTIF-003: Check if the goal is "due today" using the goal due-today logic (see Goal System doc).
- R-NOTIF-004: If the scheduled time has already passed today, skip (do not fire immediately).
- R-NOTIF-005: Use exact alarm scheduling (not batched/inexact) for reliable delivery.

### 2. Prayer-Linked Reminders

Triggered relative to prayer times for PRAYER_BASED goals.

**Requirements:**
- R-NOTIF-010: For each PRAYER_BASED goal, schedule reminders based on its slots.
- R-NOTIF-011: For each slot, determine the relevant prayer time:
  - `before_fajr` → Fajr time - 10 minutes
  - `after_fajr` → Fajr time + 10 minutes
  - `before_dhuhr` → Dhuhr time - 10 minutes
  - `after_dhuhr` → Dhuhr time + 10 minutes
  - (same pattern for Asr, Maghrib, Isha)
- R-NOTIF-012: Offset is -10 minutes for "before" slots and +10 minutes for "after" slots.
- R-NOTIF-013: Prayer times are calculated from the user's location and prayer settings.
- R-NOTIF-014: If no location is set, prayer-linked reminders cannot be scheduled.
- R-NOTIF-015: The notification includes the prayer name in the title (e.g., "Time for Isthighfar after Fajr").

### 3. Global Daily Reminder

A general reminder not tied to any specific goal.

**Requirements:**
- R-NOTIF-020: When `daily_reminder_enabled` is true, schedule a daily alarm at `reminder_hour:reminder_minute`.
- R-NOTIF-021: The notification says "Time for Dhikr" with a generic body message.
- R-NOTIF-022: Uses a separate notification channel with default (lower) importance.
- R-NOTIF-023: Tapping the notification opens the app's home screen.

---

## Follow-Up Reminders

**Requirements:**
- R-NOTIF-030: When a goal-specific or prayer-linked reminder fires:
  1. Check the database for today's progress
  2. If remaining count > 0 (goal not completed for the day), show the notification
  3. If remaining count <= 0 (already done), skip the notification
  4. Schedule a follow-up reminder 3 hours later
- R-NOTIF-031: Follow-up reminders have a cutoff at 22:00 (10 PM) to avoid late-night notifications.
- R-NOTIF-032: Follow-up notifications have a different title format: "Reminder: {dhikr}" instead of "Time for {dhikr}".
- R-NOTIF-033: Follow-ups do not chain (a follow-up does not schedule another follow-up).

---

## Notification Content

### Goal Reminder Notification

| Element | Content |
|---------|---------|
| Title | "Time for {dhikr transliteration}" (regular) OR "Time for {dhikr} after {prayer}" (prayer-linked) OR "Reminder: {dhikr}" (follow-up) |
| Body | "{remaining} remaining ({todayCount}/{dailyTarget})" |
| Progress bar | Percentage: todayCount / dailyTarget |
| Large icon | App icon |
| Actions | "Start Counting" (opens counting screen), "Done" (dismisses) |
| Tap action | Opens app to counting screen for the goal |
| Priority | High |
| Auto-cancel | Yes |

### Global Reminder Notification

| Element | Content |
|---------|---------|
| Title | "Time for Dhikr" |
| Body | "Take a moment to remember Allah and count your daily dhikr" |
| Large icon | App icon |
| Tap action | Opens app home screen |
| Priority | Default |

---

## Notification Channels

| Channel ID | Name | Importance | Description |
|-----------|------|------------|-------------|
| goal_reminders | "Goal Reminders" | High (sound + vibration) | Goal and prayer-linked reminders |
| global_reminder | "Daily Dhikr Reminder" | Default (silent) | Global daily reminder |
| dhikr_counting | "Dhikr Counting" | Low (no sound/vibration) | Foreground service notification |

---

## Alarm Scheduling Architecture

### Requirements

- R-NOTIF-040: Use exact alarms as the primary scheduling mechanism (not periodic/inexact alarms).
- R-NOTIF-041: Each alarm has a unique, deterministic request code:
  - Goal reminders: base 10,000 + goalId
  - Prayer slot reminders: base 20,000 + (goalId * 20) + slotIndex
  - Follow-up reminders: base 40,000 + goalId
  - Global reminder: code 30,000
  - Test reminders: base 50,000
- R-NOTIF-042: A daily watchdog task runs at 00:15 AM to catch any missed alarms.
- R-NOTIF-043: The watchdog reschedules all alarms (acts as a safety net).

### Rescheduling Triggers

All alarms must be rescheduled when:
- R-NOTIF-050: App starts (application launch)
- R-NOTIF-051: Device reboots
- R-NOTIF-052: App is updated
- R-NOTIF-053: Timezone changes
- R-NOTIF-054: System time is changed
- R-NOTIF-055: Exact alarm permission is granted
- R-NOTIF-056: Daily watchdog fires (00:15 AM)

### Cancellation

- R-NOTIF-060: When a goal is deleted, cancel all alarms associated with it (reminder, follow-up, all prayer slots).
- R-NOTIF-061: When a non-prayer-based goal reaches its target, cancel the reminder for that goal.
- R-NOTIF-062: "Done" action on notification dismisses the notification by ID.

---

## Notification Permission

- R-NOTIF-070: On app launch, request notification permission (required on modern platforms).
- R-NOTIF-071: If permission is denied, reminders will not fire but the app should still function otherwise.

---

## Battery Optimization Guidance

Many device manufacturers aggressively kill background processes, which can prevent alarms from firing.

**Requirements:**
- R-NOTIF-080: Detect the device manufacturer and provide OEM-specific guidance for keeping the app alive.
- R-NOTIF-081: Supported OEMs with specific guidance:
  - Samsung: "Add to Never Sleeping Apps"
  - Xiaomi/Redmi: "Enable Autostart, disable battery saver"
  - Huawei/Honor: "Add to PowerGenie whitelist"
  - OPPO/OnePlus/Realme: "Disable sleep optimization"
  - Vivo: "Disable AI sleep mode"
- R-NOTIF-082: Provide a link or intent to the battery optimization settings.
- R-NOTIF-083: Check if the app is exempt from battery optimization.

---

## Debug/Test Features

- R-NOTIF-090: In debug mode, Settings screen shows:
  - "Test notification now" - fires a notification immediately (bypasses alarm scheduling)
  - "Test notification in 30s" - schedules an alarm for 30 seconds from now (tests full pipeline)
  - "Reschedule all reminders" - forces a full reschedule
