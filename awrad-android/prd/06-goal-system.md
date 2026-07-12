# 06 - Goal System

## Overview

Goals are the core tracking unit. A user creates a goal for a specific dhikr, choosing a type and target count. Goals support 4 types with different scheduling and slot structures.

---

## Goal Types

### DAILY
- **Description:** Repeat a target count every day.
- **Slots:** One slot with key `anytime`.
- **Schedule:** Due every day.
- **Example:** "Say SubhanAllah 100 times every day."

### PRAYER_BASED
- **Description:** Count tied to specific prayers, with before/after timing.
- **Slots:** Multiple slots based on selected prayers and timing (before/after/both).
- **Schedule:** Due every day.
- **Example:** "Say Isthighfar 33 times after each of the 5 prayers."

### ONE_TIME
- **Description:** A single total target, not recurring.
- **Slots:** One slot with key `anytime`.
- **Schedule:** Only due on the start date. Progress carries across days toward the total target.
- **Example:** "Complete 70,000 La ilaha illallah."

### ADVANCED
- **Description:** Daily target with optional end date/duration and configurable notifications.
- **Slots:** One slot with key `anytime`.
- **Schedule:** Due every day within the date range.
- **Example:** "Say Swalath 500 times daily for 40 days."

---

## Goal Creation Wizard (2 Steps)

### Step 1: Select Dhikr

**UI Elements:**
- Search text field
- Scrollable list of dhikr cards
- Each card shows: Arabic text, transliteration, title

**Requirements:**
- R-GOAL-001: Display all dhikrs from the database.
- R-GOAL-002: Search filters dhikrs by title, transliteration, translation, and Arabic text (case-insensitive, substring).
- R-GOAL-003: Tapping a dhikr card selects it and advances to Step 2.
- R-GOAL-004: If a `dhikrId` is passed as a parameter (e.g., from the detail screen), skip Step 1 and go directly to Step 2 with that dhikr pre-selected.

### Step 2: Configure Goal

**UI Elements:**
- Selected dhikr card with audio preview button
- Goal type selector (4 chips: Daily, One-time, Prayer-based, Advanced)
- Adaptive form that changes based on selected goal type
- Create button

#### Common Elements (All Types)

- Audio preview play/pause button for the selected dhikr

#### DAILY Form

- Target count input field (numeric keyboard)

#### ONE_TIME Form

- Target count input field (numeric keyboard)

#### PRAYER_BASED Form

- **Prayer timing selector:** 3 options (Before, After, Both)
- **Prayer checkboxes:** Fajr, Dhuhr, Asr, Maghrib, Isha (at least one must be selected)
- **Count mode toggle:** Uniform count vs. per-prayer count
  - **Uniform:** Single target count field applied to all selected prayers
  - **Per-prayer:** Individual target count fields for each selected prayer
- **Generated slots:** Based on timing + selected prayers:
  - If "Before" + Fajr: creates slot `before_fajr`
  - If "After" + Fajr: creates slot `after_fajr`
  - If "Both" + Fajr: creates both `before_fajr` and `after_fajr`
  - Same pattern for all 5 prayers

#### ADVANCED Form

- Target count input field (numeric keyboard)
- Duration toggle (optional):
  - When enabled, shows duration input field (days)
  - Sets `endDate = startDate + durationDays`
- Notification toggle (optional):
  - When enabled, shows time picker (hour and minute)
  - Sets `notificationHour` and `notificationMinute`

**Requirements:**
- R-GOAL-010: Default goal type is DAILY.
- R-GOAL-011: Target count must be a positive integer. The input field should only accept digits.
- R-GOAL-012: For PRAYER_BASED, at least one prayer must be selected. Disable "Create" button if none selected.
- R-GOAL-013: For PRAYER_BASED uniform mode, the single target count is applied to every generated slot.
- R-GOAL-014: For PRAYER_BASED per-prayer mode, each prayer's count can differ.
- R-GOAL-015: For PRAYER_BASED "Both" timing, before and after slots for the same prayer share the same count.
- R-GOAL-016: Start date is always today (effective today considering day reset preference).
- R-GOAL-017: The "Create" button is disabled while creating (to prevent duplicates).
- R-GOAL-018: On successful creation:
  1. Insert the Goal record
  2. Insert all GoalSlot records
  3. If notification is enabled, schedule the reminder alarm
  4. Navigate back (pop the creation screen)
- R-GOAL-019: If the creation wizard was opened from a specific dhikr (via `dhikrId` param), pre-select that dhikr.

---

## Goal Slot Generation Rules

| Goal Type | Timing | Selected Prayers | Generated Slots |
|-----------|--------|------------------|-----------------|
| DAILY | - | - | 1 slot: `anytime` |
| ONE_TIME | - | - | 1 slot: `anytime` |
| ADVANCED | - | - | 1 slot: `anytime` |
| PRAYER_BASED | Before | Fajr, Dhuhr | 2 slots: `before_fajr`, `before_dhuhr` |
| PRAYER_BASED | After | All 5 | 5 slots: `after_fajr`, `after_dhuhr`, `after_asr`, `after_maghrib`, `after_isha` |
| PRAYER_BASED | Both | Fajr | 2 slots: `before_fajr`, `after_fajr` |

---

## Goals Screen

### UI Elements

- **Header:** "Goals" title + Add button (navigates to Create Goal wizard)
- **Active Goals section:** List of currently active goals
- **Completed Goals section:** Collapsible list of finished goals

### Goal List Item

- Dhikr name (transliteration, ellipsis)
- Target badge showing goal type and daily target
- Today's count / daily target
- Progress bar
- 3-dot menu with:
  - Delete (destructive, with confirmation)

### Requirements

- R-GOAL-030: Active goals are sorted by creation date (newest first).
- R-GOAL-031: Completed goals are sorted by creation date (newest first).
- R-GOAL-032: The completed section is collapsible (defaults to collapsed if there are active goals).
- R-GOAL-033: Tapping a goal item navigates to the Counting screen.
- R-GOAL-034: Deleting a goal:
  1. Cancel any scheduled reminders for this goal
  2. Delete the goal (cascades to slots and count entries)
- R-GOAL-035: If no goals exist, show empty state with hint text and link to create one.
- R-GOAL-036: Today's count is the sum of all count entries for this goal on the effective today date.
- R-GOAL-037: Daily target is the sum of all slot target counts for the goal (minimum 1).
- R-GOAL-038: Progress bar = todayCount / dailyTarget (clamped to 0.0 - 1.0).
- R-GOAL-039: Target badge format varies by type:
  - DAILY: "X/day"
  - PRAYER_BASED: "N prayers · X total"
  - ONE_TIME: "X total"
  - ADVANCED: "X/day"

---

## Goal Due-Today Logic

A goal is "due today" when:
1. `isActive == true` AND `isCompleted == false`
2. `effectiveToday >= startDate`
3. If `endDate` is set: `effectiveToday <= endDate`
4. If `durationDays` is set: days elapsed since startDate < durationDays
5. Type-specific:
   - DAILY: Always due (if conditions 1-4 pass)
   - PRAYER_BASED: Always due (if conditions 1-4 pass)
   - ONE_TIME: Only due on the start date
   - ADVANCED: Always due (if conditions 1-4 pass)
