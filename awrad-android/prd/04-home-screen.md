# 04 - Home Screen

## Overview

The home screen is the main dashboard showing a summary of the user's daily practice. It displays a greeting, prayer times, streak information, active goals, today's Wird assignments, and a category explorer.

---

## Sections (Top to Bottom)

### 1. Header

**UI Elements:**
- Greeting text (e.g., "Good morning")
- User's name
- Primary date (based on preferred calendar system)
- Secondary date (the other calendar system)
- Settings icon button (navigates to Settings)

**Requirements:**
- R-HOME-001: Display a time-of-day greeting:
  - Before 12:00 -> "Good morning"
  - 12:00 to 17:00 -> "Good afternoon"
  - After 17:00 -> "Good evening"
- R-HOME-002: Display the user's name from preferences.
- R-HOME-003: Show primary date formatted in the user's preferred calendar system (Gregorian or Hijri).
- R-HOME-004: Show secondary date in the other calendar system.
- R-HOME-005: Gregorian format: "Wednesday, March 26, 2025"
- R-HOME-006: Hijri format: "15 Ramadan 1445 AH" (using standard Hijri month names: Muharram, Safar, Rabi Al Awwal, Rabi Al Thani, Jumada Al Ula, Jumada Al Thani, Rajab, Sha'ban, Ramadan, Shawwal, Dhul Qa'dah, Dhul Hijjah).
- R-HOME-007: Settings icon in the top-right corner navigates to the Settings screen.

---

### 2. Prayer Time Card

**UI Elements:**
- Next prayer name (e.g., "Dhuhr")
- Formatted time (e.g., "12:30 PM")
- Countdown (e.g., "in 2h15m")
- City name
- Prayer icon

**Requirements:**
- R-HOME-010: Show the next upcoming prayer from: Fajr, Dhuhr, Asr, Maghrib, Isha.
- R-HOME-011: If all 5 prayers have passed for today, show Fajr of the next day.
- R-HOME-012: Format time in 12-hour format with AM/PM (e.g., "5:30 AM").
- R-HOME-013: Show countdown as "in XhYm" (hours and minutes). If less than 1 hour, show "in Ym" (minutes only).
- R-HOME-014: Display the user's city name from preferences.
- R-HOME-015: The prayer card is only visible if the user has set a location (latitude/longitude in preferences).
- R-HOME-016: Prayer times update in real-time (countdown decreases every minute).

---

### 3. Streak Card (Contribution Grid)

**UI Elements:**
- Fire/flame icon with current streak count
- 15-week contribution grid (GitHub-style heatmap)
- Grid cells colored by activity level

**Requirements:**
- R-HOME-020: Display a 15-week grid (15 columns x 7 rows = 105 days).
- R-HOME-021: Each cell represents one day. The most recent day is in the bottom-right corner.
- R-HOME-022: Cell color intensity indicates whether the user made any progress that day:
  - No activity: neutral/empty color
  - Activity: primary color (sage green)
- R-HOME-023: The streak count is the number of consecutive days (ending today or yesterday) where the user had at least one count entry.
- R-HOME-024: If today has progress, include today in the streak. If not, the streak ended yesterday.
- R-HOME-025: Display the streak count next to a fire icon.

---

### 4. Resume Counting Section

**UI Elements:**
- Section header: "Resume Counting" with "View All" link
- Vertical list of active goal cards (filtered for today)

**Goal Card Contents:**
- Dhikr transliteration name
- Today's count / daily target
- Linear progress bar

**Requirements:**
- R-HOME-030: Show only goals that are "due today" (active, not completed, within date range, appropriate for goal type).
- R-HOME-031: For each goal, show today's count out of the daily target.
- R-HOME-032: Progress bar fills proportionally: `todayCount / dailyTarget`.
- R-HOME-033: Tapping a goal card navigates to the Counting screen for that goal.
- R-HOME-034: "View All" navigates to the Goals tab.
- R-HOME-035: If no active goals exist, show an empty state with a message.
- R-HOME-036: Daily target is the sum of all slot targets for the goal.

---

### 5. Wirds for Today Section

**UI Elements:**
- Section header: "Wirds for Today" with "View All" link
- Horizontal or vertical list of Wird collection cards

**Wird Card Contents:**
- Collection name (English or Arabic based on locale)
- Streak count (if > 0, with fire icon)
- Today's section subtitle and title
- Progress bar or "Complete" badge
- Progress text (e.g., "3/7 items")

**Requirements:**
- R-HOME-040: Show all Wird collections with their today's progress.
- R-HOME-041: "Today's section" is determined by the collection's schedule type:
  - DAILY: Always section 0
  - WEEKLY_SPLIT: Day of week (Monday=0 through Sunday=6), capped at totalSections-1
  - MORNING_EVENING: Section 0 if before noon, section 1 (or last section) if afternoon
  - FREE: Section 0 (or last read section)
- R-HOME-042: If today's section is fully completed, show a "Complete" badge instead of progress bar.
- R-HOME-043: Show section progress: completedItems / totalItems.
- R-HOME-044: Show streak count for the collection (consecutive days/weeks of completion).
- R-HOME-045: Tapping a card navigates to the Wird Detail screen.
- R-HOME-046: "View All" navigates to the Wird List screen.

---

### 6. Explore Collections (Category Grid)

**UI Elements:**
- Section header: "Explore"
- 2-column grid of category cards
- Each card shows: category name, dhikr count in that category

**Requirements:**
- R-HOME-050: Show only categories that contain at least one dhikr.
- R-HOME-051: Display the count of dhikrs in each category.
- R-HOME-052: Tapping a category card navigates to the Category screen filtered for that category.

---

## State & Data Requirements

- R-HOME-060: The effective "today" date respects the user's day reset preference (midnight or Maghrib). If reset is set to Maghrib and current time is after Maghrib, the effective date is tomorrow.
- R-HOME-061: All progress data (counts, streaks, prayer times) must be reactive - updating in real-time as the user returns to the home screen or as time passes.
- R-HOME-062: Overall progress is calculated as the average daily progress across all active goals that are due today.
