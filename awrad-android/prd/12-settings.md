# 12 - Settings

## Overview

The Settings screen provides access to all user-configurable preferences, organized into logical sections.

---

## Sections

### 1. Profile

**UI Elements:**
- Display name with inline edit (tap to edit, save/cancel buttons)

**Requirements:**
- R-SET-001: Show the user's name in display mode by default.
- R-SET-002: Tapping the name switches to edit mode with a text input field.
- R-SET-003: "Save" button saves the name to preferences and returns to display mode.
- R-SET-004: "Cancel" button discards changes and returns to display mode.
- R-SET-005: Name is used in the home screen greeting.

---

### 2. Counting Preferences

**UI Elements:**
- Vibrate on Count (toggle switch)
- Keep Screen On (toggle switch)
- Sound on Count (toggle switch)

**Requirements:**
- R-SET-010: Vibrate on Count: when enabled, the counting screen triggers haptic feedback on each tap.
- R-SET-011: Keep Screen On: when enabled, the counting screen prevents the display from turning off.
- R-SET-012: Sound on Count: when enabled, the counting screen plays a short tick sound on each count.
- R-SET-013: All toggles are saved immediately to preferences (no "Save" button needed).
- R-SET-014: These preferences take effect the next time the counting screen is opened (or immediately if already open).

---

### 3. Notifications & Reminders

**UI Elements:**
- Daily Reminder toggle
- Reminder Time picker (shows current time, opens picker on tap)
- Download Audio Library button with progress indicator

**Requirements:**
- R-SET-020: Daily Reminder toggle enables/disables the global daily reminder.
- R-SET-021: When toggled on, schedule the global reminder alarm.
- R-SET-022: When toggled off, cancel the global reminder alarm.
- R-SET-023: Reminder Time picker allows selecting hour and minute.
- R-SET-024: Changing the time reschedules the alarm.
- R-SET-025: Download Audio Library button downloads all dhikr audio files that haven't been downloaded yet.
- R-SET-026: Show the count of downloadable (not yet downloaded) dhikrs.
- R-SET-027: Show download progress while downloading.

---

### 4. Prayer Settings

**UI Elements:**
- Location display (city name) with "Change" button
- Location search dialog (same as onboarding: search field + results, GPS button)
- Calculation Method selector (filter chips or dropdown)
- Madhab selector (filter chips or dropdown)

**Requirements:**
- R-SET-030: Display the current city name.
- R-SET-031: "Change" button opens the location search dialog.
- R-SET-032: Location dialog supports both city search and GPS (same as onboarding Step 3).
- R-SET-033: Calculation Method shows all 10 available methods as selectable options.
- R-SET-034: Madhab shows 2 options: Shafi and Hanafi.
- R-SET-035: Changing location, method, or madhab immediately updates prayer time calculations.
- R-SET-036: Changing location reschedules all prayer-linked reminders.

---

### 5. Date & Calendar

**UI Elements:**
- Day Reset Time selector (dropdown/chips)
- Calendar System selector (dropdown/chips)

**Requirements:**
- R-SET-040: Day Reset Time options:
  - **Midnight:** Day changes at 00:00. Standard behavior.
  - **Maghrib:** Day changes at Maghrib prayer time. After Maghrib, the "effective today" becomes tomorrow. This requires a location to be set (for Maghrib time calculation).
- R-SET-041: Calendar System options:
  - **Gregorian:** Standard Western calendar as primary display.
  - **Hijri:** Islamic lunar calendar as primary display.
- R-SET-042: The non-primary calendar is shown as secondary (e.g., if primary is Hijri, Gregorian shows below as secondary).
- R-SET-043: Day Reset Time affects all date-based operations: counting, streaks, goal due-today checks, Wird section assignments.

---

### 6. Language

**UI Elements:**
- Language selector (list of available languages)

**Requirements:**
- R-SET-050: Available languages: English, Arabic (العربية), Malayalam (മലയാളം).
- R-SET-051: Changing language immediately updates the entire app UI.
- R-SET-052: Arabic selection enables right-to-left (RTL) layout.
- R-SET-053: Arabic selection switches the typography to Noto Naskh Arabic font for all text styles.
- R-SET-054: Language preference persists across app restarts.
- R-SET-055: The app supports per-app language settings (independent of device language).

---

### 7. Data Management

**UI Elements:**
- Reset Progress button (destructive)
- Delete All Goals button (destructive)

**Requirements:**
- R-SET-060: "Reset Progress" erases all count entries and resets all goals' totalCompletedCount to 0. Goals themselves are preserved.
- R-SET-061: "Delete All Goals" deletes all goals, their slots, and their count entries.
- R-SET-062: Both actions require a confirmation dialog before proceeding.
- R-SET-063: Confirmation dialogs clearly state what will be deleted and that the action is irreversible.
- R-SET-064: After deleting goals, cancel all associated reminder alarms.

---

### 8. Debug Section (Development Builds Only)

**UI Elements:**
- "Test notification now" button
- "Test notification in 30s" button
- "Reschedule all reminders" button

**Requirements:**
- R-SET-070: Only visible in debug/development builds.
- R-SET-071: "Test notification now" fires a notification immediately (bypasses alarm scheduling). Uses the first goal with notifications enabled, or falls back to global reminder.
- R-SET-072: "Test notification in 30s" schedules an alarm 30 seconds from now to test the full pipeline.
- R-SET-073: "Reschedule all reminders" forces a complete reschedule of all alarms.

---

## Appearance

**Requirements:**
- R-SET-080: Dark Mode preference:
  - `null` (default): Follow the system/device dark mode setting.
  - `true`: Force dark mode.
  - `false`: Force light mode.
- R-SET-081: Theme changes take effect immediately.
