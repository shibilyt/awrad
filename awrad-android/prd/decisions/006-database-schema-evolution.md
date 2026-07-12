# 006 — Database Schema Evolution

**Status:** Accepted
**Date:** 2025-01 through 2025-03
**Context:** Data Model, Migrations, Backwards Compatibility

---

## Context

The app shipped with a v1 schema and has evolved through 8 versions. Each migration added features while preserving existing user data. This log documents the evolution and the reasoning behind each step.

## Migration History

### v1 → v2: Notification Fields
**What:** Added `notificationEnabled`, `notificationHour`, `notificationMinute` to `goals`.
**Why:** Users requested per-goal reminders. The initial release had no notification support. Adding nullable hour/minute fields lets us schedule per-goal alarms.

### v2 → v3: Audio Count Per Play
**What:** Added `audioCountPerPlay` (default 1) to `dhikrs`.
**Why:** Some audio recordings contain 2 complete recitations. We need to tell the audio service how many counts one play equals, rather than hardcoding 1. This avoids splitting audio files or creating duplicate entries.

### v3 → v4: The Slot Restructure (Major)
**What:** Complete restructuring of goal, slot, and progress tables.
**Why:** The original single `targetValue` on goals couldn't support prayer-based counting. See Decision 002 for full reasoning.

**Migration steps:**
1. Rename `goals` → `goals_old`
2. Create new `goals` with `goalType` (mapped from `recurrenceType`), `startDate`/`endDate` as LocalDate
3. Create `goal_slots` — seed one "anytime" slot per existing goal from old `targetValue`
4. Create `count_entries` — migrate from `daily_progress` with `slotId = NULL`

**Data mapping:**
- Old `DAILY` recurrence → new `DAILY` type
- Old `ONE_TIME` recurrence → new `ONE_TIME` type
- All others → `DAILY` (safe default)

### v4 → v5: Dhikr Titles
**What:** Added `title` (default "") to `dhikrs`.
**Why:** Originally dhikrs were identified by transliteration only. Adding a separate title field allows display names like "Surah Ikhlas" while keeping transliteration ("Qul huwa Allahu ahad") for pronunciation.

### v5 → v6: Count Entry Deduplication
**What:** Recreated `count_entries` with a UNIQUE constraint on `(goalId, date, slotId)`.
**Why:** A bug allowed duplicate entries for the same goal/date/slot combination. The migration consolidates duplicates by SUM(count) and MAX(timestamp), then enforces uniqueness going forward.

**This enabled the upsert pattern** (see Decision 012): try UPDATE first, INSERT if no row matched.

### v6 → v7: Wird System
**What:** Added 4 new tables: `wird_collections`, `wird_sections`, `wird_items`, `wird_reading_progress`.
**Why:** New feature: structured Islamic text reading (e.g., Dalail al-Khayrat). See Decision 007 for full reasoning. This was a pure addition — no existing tables modified.

### v7 → v8: Date-Aware Wird Progress
**What:** Recreated `wird_reading_progress` with `date` field and `completedItems` JSON. Added `scheduleType` to `wird_collections`.
**Why:** The v7 progress table had no date awareness — progress was global per section. Users couldn't track "did I read today's section?" The new schema tracks progress per (collection, section, date), enabling daily reset and schedule-based section assignment.

**Fields added:**
- `date` (TEXT, for daily reset)
- `lastScrollIndex` (INT, resume position)
- `completedItems` (TEXT/JSON, per-item counts)
- `completedItemCount` / `totalItems` (INT, denormalized for fast queries)
- `scheduleType` on collections (DAILY, WEEKLY_SPLIT, MORNING_EVENING, FREE)

## Design Principles

1. **Never lose user data.** Every migration preserves existing counts, goals, and progress. Destructive operations (dropping tables) only happen after data is copied to new structures.

2. **Additive when possible.** v2, v3, v4, v5 added columns with defaults. No existing data is modified unless necessary (v6 consolidation was an exception to fix a bug).

3. **Progressive complexity.** Schema started simple (v1: dhikrs + goals + progress) and grew to support slots, wirds, and date-aware progress as features were validated.

4. **String dates over date types.** All date fields use TEXT in "YYYY-MM-DD" format. This avoids platform-specific date serialization issues, makes migrations simpler, and supports direct string comparison for ordering.

## Consequences

- The app must handle all 7 migration paths (1→2, 2→3, ..., 7→8) for users upgrading from any version.
- New installs create the v8 schema directly (no migrations needed).
- Schema is exported to JSON files for verification and testing.
