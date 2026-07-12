# 07 - Counting Screen

## Overview

The counting screen is where users actually perform their dhikr counting. It supports both manual tap counting and audio-assisted counting, with special handling for prayer-based goals that have multiple time slots.

---

## Screen Layout

### Top Bar
- Centered dhikr transliteration name
- Back button (with exit confirmation if audio is playing)

### Main Content Area
- Large circular count display showing current count / target
- Dhikr Arabic text
- Count interaction area (tap zone for manual counting)

### Slot Cards (Prayer-Based Goals Only)
- Scrollable list of prayer slot cards
- Each card shows: prayer name + timing (before/after), current count / target, progress bar, active/complete indicator
- Tapping a slot switches the active counting slot

### Bottom Action Area
- Manual count button (if no audio)
- Audio controls (if audio available)
- Adjust count button (opens manual adjustment dialog)

---

## Counting Modes

### Manual Counting

**Requirements:**
- R-COUNT-001: Tapping the main content area increments the count by 1.
- R-COUNT-002: If `vibrateOnCount` is enabled in preferences, trigger haptic feedback on each count.
- R-COUNT-003: If `soundOnCount` is enabled in preferences, play a short tick sound on each count.
- R-COUNT-004: If `keepScreenOn` is enabled in preferences, prevent the screen from turning off.
- R-COUNT-005: Count cannot exceed the target (capped at target value).

### Audio Counting

**Requirements:**
- R-COUNT-010: If the dhikr has downloaded audio, show audio playback controls.
- R-COUNT-011: Starting audio counting plays the dhikr audio in a loop.
- R-COUNT-012: Each time the audio completes one full play, the count increments by `audioCountPerPlay` (configured per dhikr, typically 1 or 2).
- R-COUNT-013: Audio playback continues in the background even if the user navigates away or the screen turns off.
- R-COUNT-014: A persistent foreground notification shows counting progress during audio playback.
- R-COUNT-015: The foreground notification displays:
  - Title: dhikr transliteration
  - Content: "count / target" in manual mode, or "count / target · time / duration" in audio mode
  - Progress bar (in audio mode)
  - Play/Pause action button (in audio mode)
- R-COUNT-016: Audio playback speed is adjustable (range: 0.75x to 3.0x).
- R-COUNT-017: When the count reaches the target, audio playback stops automatically.
- R-COUNT-018: When the count reaches the target, play a celebration sound.
- R-COUNT-019: If audio fails to load, show an error state and allow fallback to manual counting.
- R-COUNT-020: The user can toggle between play and pause at any time.

### Exit Behavior with Audio

- R-COUNT-025: If audio is playing and the user presses back, show a confirmation dialog:
  - "Audio is playing" with options to stop and exit, or continue counting.
- R-COUNT-026: If the user confirms exit, stop audio and release resources.

---

## Prayer-Based Goal Counting

**Requirements:**
- R-COUNT-030: For PRAYER_BASED goals, display all slots as cards below the main counter.
- R-COUNT-031: One slot is "active" at a time. The active slot is highlighted.
- R-COUNT-032: Tapping a slot card makes it the active slot.
- R-COUNT-033: When switching active slot:
  - The current count display updates to show the new slot's count
  - The target updates to the new slot's target count
  - If audio is playing, stop playback
- R-COUNT-034: Each slot's progress is tracked independently.
- R-COUNT-035: Slot cards show their own progress bar and completion status.
- R-COUNT-036: A slot is "complete" when its count reaches its target.
- R-COUNT-037: Display an indicator when all slots are complete.

---

## Count Persistence

**Requirements:**
- R-COUNT-040: Every count increment is saved to the database immediately (not batched).
- R-COUNT-041: Count entries are keyed by (goalId, date, slotId):
  - For non-prayer-based goals: slotId is null
  - For prayer-based goals: slotId matches the active slot
- R-COUNT-042: The goal's `totalCompletedCount` is incremented by 1 for each count.
- R-COUNT-043: Date used for count entries is the effective today date (respecting day reset preference).

---

## Manual Count Adjustment

**Requirements:**
- R-COUNT-050: An "Adjust" button opens a dialog for manual count adjustment.
- R-COUNT-051: The dialog contains:
  - A numeric input field
  - "Add" and "Subtract" mode selection
  - Confirm and Cancel buttons
- R-COUNT-052: Adding increases the count by the entered amount (capped at target).
- R-COUNT-053: Subtracting decreases the count (floored at 0). Show a warning before confirming subtraction.
- R-COUNT-054: The adjustment is saved to the database immediately.

---

## Session Targets (Optional)

**Requirements:**
- R-COUNT-060: Users can optionally set a session target (separate from the goal target).
- R-COUNT-061: Session target types:
  - **Count-based:** A number of counts for this session (e.g., "I want to do 50 right now")
  - **Timer-based:** A time duration for this session (e.g., "I want to count for 10 minutes")
- R-COUNT-062: Session progress is tracked separately:
  - Session count: number of counts since session started
  - Session elapsed time: seconds since session started
- R-COUNT-063: When the session target is reached, show a completion indicator.
- R-COUNT-064: Session targets do not affect the goal target or persistence. They are ephemeral.
- R-COUNT-065: Session state survives navigation (saved in transient state).

---

## Additional Display

**Requirements:**
- R-COUNT-070: Show the dhikr's Arabic text prominently.
- R-COUNT-071: Show the dhikr's transliteration in the top bar.
- R-COUNT-072: Show the dhikr's translation (accessible via bottom sheet or detail view).
- R-COUNT-073: For ONE_TIME goals, show the total cumulative count (across all dates) in addition to today's count.
- R-COUNT-074: Show daily progress as a percentage.
- R-COUNT-075: Show remaining count (target - todayCount, minimum 0).
