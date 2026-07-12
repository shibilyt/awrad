# 05 - Dhikr Library

## Overview

The Dhikr Library is a browsable, searchable catalog of all dhikrs in the app. Users can explore by category, search by text, preview audio, and navigate to detailed views or goal creation.

---

## Library Screen

### UI Elements

- **Title:** "Library" (in header)
- **Search field:** Text input with clear button
- **Category filter chips:** Horizontal scrollable row of filter chips (one per category, plus "All")
- **Dhikr list:** Scrollable list of dhikr items

### Dhikr List Item

Each item displays:
- Title (transliteration, 1 line, ellipsis on overflow)
- Arabic text (1 line, ellipsis on overflow)
- Audio play/pause button (if audio is available)

### Display Modes

1. **All (no search, no category filter):** Dhikrs grouped by category with sticky section headers.
2. **Category filtered:** Flat list of dhikrs in the selected category.
3. **Search filtered:** Flat list of matching dhikrs across all categories.

### Requirements

- R-LIB-001: Show all dhikrs from the database, ordered by category then by transliteration.
- R-LIB-002: Search matches against: title, transliteration, translation, and Arabic text. Case-insensitive, substring match.
- R-LIB-003: Category filter chips show only categories that contain at least one dhikr.
- R-LIB-004: Selecting a category chip filters the list to that category. Selecting "All" removes the filter.
- R-LIB-005: Search and category filter can be combined.
- R-LIB-006: If no results match the current search/filter, show "No matches found" empty state.
- R-LIB-007: If the library is completely empty (no dhikrs), show "No dhikrs in library" empty state.
- R-LIB-008: Tapping a dhikr item navigates to the Dhikr Detail screen.
- R-LIB-009: The audio play/pause button plays a preview of the dhikr audio. Only one dhikr can preview at a time (playing a new one stops the previous).

---

## Category Screen

Accessed when tapping a category from the Home screen's "Explore" grid.

### UI Elements

- **Top bar:** Category name (localized), back button
- **Dhikr list:** Same item format as Library screen

### Requirements

- R-LIB-020: Display all dhikrs in the selected category.
- R-LIB-021: Category name should be localized (e.g., "Morning" in English, "الصباح" in Arabic).
- R-LIB-022: Each category has a subtitle/description (hardcoded per category).
- R-LIB-023: Tapping a dhikr navigates to the Dhikr Detail screen.
- R-LIB-024: Audio preview button works the same as in the Library screen.

---

## Dhikr Detail Screen

Shows the full details of a single dhikr with audio controls, benefits, and goal suggestions.

### UI Elements

- **Top bar:** Dhikr title, back button, "Create Goal" button
- **Arabic text box:** Large, centered Arabic text in Naskh Arabic font
- **Transliteration section:** Label + italicized text
- **Translation section:** Label + body text
- **Audio player row:**
  - Play/pause button
  - Download button (if not yet downloaded)
  - Playback progress indicator
- **Benefits section:** Bulleted list of benefits with optional hadith sources
- **Suggested Goals section:** Cards showing pre-configured goal templates

### Suggested Goal Card

Each card shows:
- Goal label (e.g., "Daily 100x")
- Description
- Target count
- Goal type
- "Add Goal" button

### Requirements

- R-LIB-030: Display the full Arabic text prominently, using an Arabic Naskh font.
- R-LIB-031: Show transliteration in italics below the Arabic.
- R-LIB-032: Show translation/meaning if it differs from the title.
- R-LIB-033: Audio player shows play/pause and progress. If audio is not downloaded, show a download button.
- R-LIB-034: Benefits are loaded from a registry (see Built-in Content doc). Not all dhikrs have benefits.
- R-LIB-035: Suggested goals are pre-configured templates with specific target counts and goal types.
- R-LIB-036: Tapping "Add Goal" on a suggested goal shows a confirmation dialog with the goal details.
- R-LIB-037: On confirmation, create the goal immediately (without going through the full creation wizard).
- R-LIB-038: If a suggested goal with the same type and target already exists for this dhikr, show it as "Already Added" (disabled).
- R-LIB-039: "Create Goal" button in the top bar navigates to the full Create Goal wizard with this dhikr pre-selected.
- R-LIB-040: If the dhikr is not found (deleted), show a centered error message.
- R-LIB-041: The detail screen shows existing active goals for this dhikr.

---

## Audio Preview System

### Requirements

- R-LIB-050: Only one audio preview can play at a time across the entire app.
- R-LIB-051: If audio is playing and the user taps the same dhikr, pause playback.
- R-LIB-052: If audio is playing and the user taps a different dhikr, stop the current and start the new one.
- R-LIB-053: Audio preview prefers local file if downloaded, otherwise streams from remote URL.
- R-LIB-054: Show playback progress (current position / duration) while playing.
- R-LIB-055: Audio does not loop in preview mode (plays once).
- R-LIB-056: Playback state resets when audio reaches the end.
