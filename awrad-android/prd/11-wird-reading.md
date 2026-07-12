# 11 - Wird Reading

## Overview

Wirds are structured collections of Islamic texts meant to be read sequentially. The app supports loading Wird collections from bundled data, tracking reading progress per section per day, and offering two reading modes (pager/card flip and scroll/list).

---

## Data Structure

A **Wird Collection** contains multiple **Sections**, each containing multiple **Items** (texts). Collections have a **schedule type** determining which section is assigned to each day.

See the Data Model doc for full entity specifications.

---

## Schedule Types

### DAILY
- Same section (section 0) every day.
- Progress resets daily.

### WEEKLY_SPLIT
- 7 sections mapped to days of the week: Monday = section 0, Tuesday = section 1, ..., Sunday = section 6.
- If the collection has fewer sections than 7, the day-of-week index is capped at `totalSections - 1`.
- Progress resets daily (each day has its own section).

### MORNING_EVENING
- 2 sections: section 0 for morning, section 1 for evening.
- Boundary is noon (12:00 PM).
- Before noon: today's section = section 0.
- After noon: today's section = `min(1, totalSections - 1)`.
- Progress resets daily.

### FREE
- No automatic section assignment.
- User reads at their own pace, starting from section 0.
- Progress persists across days (date-based, but user controls pace).

---

## Wird List Screen

Shows all available Wird collections.

### UI Elements
- Top bar: "Wird Collections", back button
- List of collection cards

### Collection Card
- Arabic name
- English name
- Author
- Progress text: "X/Y sections" (completed sections for today)
- Progress bar

### Requirements

- R-WIRD-001: Show all collections sorted by `sortOrder`.
- R-WIRD-002: For each collection, show today's progress (how many sections completed today).
- R-WIRD-003: Tapping a collection card navigates to the Wird Detail screen.

---

## Wird Detail Screen

Shows the sections of a specific collection with progress.

### UI Elements
- Header card: Arabic name, author, description, overall progress bar, section count, "Start Reading" button
- Section list: cards for each section

### Section Card
- Section title (English)
- Section subtitle (e.g., "Monday" for weekly split)
- Progress: completedItems / totalItems
- Progress bar or "Complete" badge
- Highlight border if this is today's assigned section and not yet completed

### Requirements

- R-WIRD-010: Show the collection header with overall progress.
- R-WIRD-011: List all sections with their today's progress.
- R-WIRD-012: Highlight today's assigned section based on the schedule type logic.
- R-WIRD-013: Show "Complete" badge for sections fully completed today.
- R-WIRD-014: "Start Reading" button navigates to the reader for today's assigned section.
- R-WIRD-015: Tapping any section card navigates to the reader for that section.
- R-WIRD-016: Calculate and display the collection's streak (consecutive completion days/weeks).

---

## Wird Reader Screen

The main reading experience for a single section.

### Two View Modes

#### Pager Mode (Card Flip)
- Full-screen cards, one item per card.
- User swipes or taps to advance.
- Current item displayed prominently with Arabic text.

#### Scroll Mode (List)
- Vertical scrollable list of all items.
- Each item visible with its Arabic text and count.

### UI Elements (Both Modes)

**Top Bar:**
- Section title (English) + subtitle
- Progress count: "X / Y completed"
- View mode toggle button (switch between pager and list)

**Item Display:**
- Arabic text (large, centered, Arabic font)
- Transliteration (if available)
- Translation (if available)
- Count display: "currentCount / repeatCount" (e.g., "2/3" for an item to be repeated 3 times)

**Bottom Bar:**
- Overall progress bar
- Previous section button (if not first section)
- Next section button (if not last section)

**Completion Overlay:**
- Shown when all items in the section are completed.
- Celebration animation.
- "Next Section" button (if available).
- Dismiss button.

### Requirements

- R-WIRD-020: The reader loads all items for the selected section.
- R-WIRD-021: For each item, track a count from 0 to `repeatCount`.
- R-WIRD-022: Tapping an item increments its count by 1, up to `repeatCount`.
- R-WIRD-023: An item is "completed" when its count equals its `repeatCount`.
- R-WIRD-024: Progress is: number of fully completed items / total items in section.
- R-WIRD-025: The user can switch between Pager and Scroll modes at any time.
- R-WIRD-026: In Pager mode:
  - Display one item per page.
  - Tap to increment count.
  - Auto-advance to next item when current item reaches its `repeatCount`.
  - Provide haptic feedback on completion.
- R-WIRD-027: In Scroll mode:
  - Display all items in a vertical list.
  - Each item shows its count and completion status.
  - Tap to increment.

### Progress Persistence

- R-WIRD-030: Save progress automatically when:
  - The user navigates away (back button)
  - An item count changes (debounced)
  - The app goes to background
- R-WIRD-031: Saved state includes:
  - Scroll/page position (for resume)
  - Per-item counts as a JSON map: `{"itemIndex": currentCount}`
  - Completed item count (denormalized)
  - Total items (denormalized)
  - Completion flag
- R-WIRD-032: Progress is keyed by (collectionId, sectionIndex, date).
- R-WIRD-033: When the user returns to a section on the same day, resume from saved position and counts.
- R-WIRD-034: Progress resets each day (new date = fresh progress).

### Section Navigation

- R-WIRD-040: "Previous Section" navigates to the reader for the previous section (sectionIndex - 1).
- R-WIRD-041: "Next Section" navigates to the reader for the next section (sectionIndex + 1).
- R-WIRD-042: These buttons are hidden when at the first/last section respectively.
- R-WIRD-043: On the completion overlay, "Next Section" advances to the next section.

---

## Streak Calculation for Wirds

- R-WIRD-050: Streak is calculated differently per schedule type:
  - **DAILY / MORNING_EVENING:** Count consecutive days backward from today where at least one section was completed.
  - **WEEKLY_SPLIT:** Count consecutive weeks where the Wird was read at least once.
  - **FREE:** Total number of dates with any completion (not necessarily consecutive).
- R-WIRD-051: Include today in the streak count if today has any completion.

---

## Built-in Collections

- R-WIRD-060: Built-in Wird collections are loaded from bundled JSON data files on first launch (or app update).
- R-WIRD-061: JSON structure per collection:
  ```
  {
    slug, version, nameAr, nameEn, description, author, scheduleType, sortOrder,
    sections: [{ sectionIndex, titleAr, titleEn, subtitle, items: [{ itemIndex, arabic, transliteration?, translation?, repeatCount }] }]
  }
  ```
- R-WIRD-062: On app update, if the bundled version is higher than the stored version, update the collection (re-import sections and items).
- R-WIRD-063: New collections that don't exist in the database are inserted.
- R-WIRD-064: Collections are identified by `slug` (unique identifier).
