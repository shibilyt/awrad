# 13 - Progress & Streaks

## Overview

The app tracks counting progress across dates, calculates streaks, and visualizes activity in a contribution grid. This document specifies how progress is computed, stored, and displayed.

---

## Daily Progress Tracking

### Requirements

- R-PROG-001: Progress is tracked per goal, per date, per slot (optional).
- R-PROG-002: The "effective today" date respects the day reset preference:
  - If day_reset_time = MIDNIGHT: today = current calendar date
  - If day_reset_time = MAGHRIB: today = current date if before Maghrib, tomorrow if after Maghrib
- R-PROG-003: All counting operations use the effective today date.
- R-PROG-004: Count entries use the upsert pattern: if (goalId, date, slotId) already exists, increment the count; otherwise insert a new entry.

### Daily Target Calculation

- R-PROG-010: Daily target for a goal = sum of all slot target counts (minimum 1).
- R-PROG-011: For goals with one "anytime" slot, daily target = that slot's targetCount.
- R-PROG-012: For prayer-based goals, daily target = sum of all prayer slot targets.

### Daily Progress Percentage

- R-PROG-013: `dailyProgress = todayCount / dailyTarget` (float, 0.0 to 1.0, clamped).
- R-PROG-014: `todayCount` = sum of all count entries for this goal on today's date.

### Remaining Count

- R-PROG-015: `remaining = dailyTarget - todayCount` (minimum 0).

---

## Streak Calculation

### Algorithm

- R-PROG-020: Streak = number of consecutive days ending at today (or yesterday) where the user had at least one count entry with count > 0.
- R-PROG-021: Process:
  1. Get all dates that have at least one count entry with count > 0, sorted descending.
  2. Start from today (effective today):
     - If today has activity, include it and check yesterday.
     - If today has no activity but yesterday does, start from yesterday.
     - If neither has activity, streak = 0.
  3. Walk backward through consecutive dates, counting each day that appears in the active dates set.
  4. Stop at the first gap.

### Active Dates

- R-PROG-022: Active dates = the set of all unique dates that have any count entry with count > 0.
- R-PROG-023: This set is used for:
  - Streak calculation
  - Contribution grid coloring

---

## Contribution Grid (Streak Card)

### Specification

- R-PROG-030: Display a 15-week (105-day) grid, organized as 15 columns x 7 rows.
- R-PROG-031: Each cell represents one day.
- R-PROG-032: The grid is oriented so that the most recent day is in the bottom-right corner.
- R-PROG-033: Rows represent days of the week (Monday at top, Sunday at bottom - or locale-appropriate).
- R-PROG-034: Columns represent weeks (oldest on left, newest on right).
- R-PROG-035: Cell coloring:
  - **Active day** (date exists in active dates set): Primary color (sage green)
  - **Inactive day** (no activity): Neutral/muted color
- R-PROG-036: Future dates should not be shown (use empty/transparent for days after today).
- R-PROG-037: The streak count number is displayed prominently next to a fire/flame icon.

---

## Overall Progress (Home Screen)

- R-PROG-040: Overall progress on the home screen = average daily progress across all active goals that are due today.
- R-PROG-041: If no goals are due today, overall progress = 0.

---

## Goal History

### Requirements

- R-PROG-050: For each goal, maintain a history of all count entries with count > 0.
- R-PROG-051: History is sorted by date descending, then by lastUpdated descending.
- R-PROG-052: History is accessible from the counting screen (bottom sheet or similar).
- R-PROG-053: Each history entry shows: date, count, slot name (if applicable).

---

## Goal Completion

### Requirements

- R-PROG-060: A ONE_TIME goal is "completed" when `totalCompletedCount >= dailyTarget` (the one-time target).
- R-PROG-061: When a ONE_TIME goal is completed:
  - Set `isCompleted = true` and `isActive = false`.
  - Cancel associated reminders.
  - The goal moves from the "Active" list to the "Completed" list on the Goals screen.
- R-PROG-062: DAILY, PRAYER_BASED, and ADVANCED goals are never auto-completed (they recur). They are only manually deactivated or reach their end date.
- R-PROG-063: If an ADVANCED goal has a duration and the current date exceeds `startDate + durationDays`, it should no longer be "due today" but remains in the active list unless manually completed.

---

## Progress Map

### Requirements

- R-PROG-070: A "progress map" is a mapping of goalId -> total count for a given date.
- R-PROG-071: Used by the home screen and goals screen to efficiently show all goals' daily progress without querying each goal individually.
- R-PROG-072: Query: for a given date, group count entries by goalId and sum their counts.
