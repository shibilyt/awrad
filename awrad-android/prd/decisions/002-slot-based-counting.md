# 002 — Slot-Based Counting Model

**Status:** Accepted
**Date:** 2025-01 (Migration 3→4)
**Context:** Data Model, Goal System, Prayer-Based Goals

---

## Context

The original data model had a single `targetValue` on each goal. This worked for daily and one-time goals, but couldn't express "33 times after Fajr, 33 times after Dhuhr, ..." — a common Islamic practice where the same dhikr has different targets tied to different prayer times.

## Options Considered

### Option A: Multiple goals per dhikr (one per prayer)
- Create 5 separate goals: "Isthighfar after Fajr (33)", "Isthighfar after Dhuhr (33)", etc.
- Simple data model
- Poor UX: user sees 5 goals for one dhikr; no unified view

### Option B: JSON targets field on the goal
- Store `{"after_fajr": 33, "after_dhuhr": 33, ...}` as a JSON string on the goal
- Single goal entity
- Messy to query; no relational integrity; hard to track per-slot progress

### Option C: Separate GoalSlot entity with foreign key to Goal
- `goal_slots` table: (id, goalId, slotKey, targetCount, sortOrder)
- One goal has many slots
- Count entries reference a specific slotId
- Full relational integrity; clean queries

## Decision

**Option C** — GoalSlot as a separate entity.

## Reasoning

1. **Relational integrity.** GoalSlot has a foreign key to Goal with CASCADE delete. CountEntry has a foreign key to GoalSlot with SET_NULL. The database enforces consistency.

2. **Per-slot progress tracking.** Each CountEntry records which slot the count belongs to via `(goalId, date, slotId)`. We can query "how many did you do after Fajr today?" directly.

3. **Flexible prayer configuration.** Users choose:
   - Which prayers (any subset of 5)
   - Timing: before, after, or both
   - Uniform count vs. per-prayer count

   The slot model naturally generates the right number of slots with the right keys.

4. **Backwards compatible.** For DAILY/ONE_TIME/ADVANCED goals, we create a single slot with key `anytime`. The rest of the system doesn't need special cases — it always works with slots.

5. **Migration was clean.** The 3→4 migration mapped each existing goal's `targetValue` to a new `anytime` slot. Existing `daily_progress` entries became `count_entries` with `slotId = NULL`.

## Slot Key Design

The 11 slot keys form a complete matrix:

```
anytime
before_fajr    after_fajr
before_dhuhr   after_dhuhr
before_asr     after_asr
before_maghrib after_maghrib
before_isha    after_isha
```

This supports all common Islamic dhikr timing patterns. The naming convention is systematic (`{timing}_{prayer}`) so slot keys can be parsed programmatically to determine the associated prayer time for reminders.

## Consequences

- The counting screen shows slot cards for prayer-based goals, allowing users to switch between slots.
- The daily target for a goal is the sum of all slot targets.
- Reminder scheduling maps slot keys to prayer times with ±10 minute offsets.
- The `sortOrder` field allows displaying slots in prayer chronological order.
