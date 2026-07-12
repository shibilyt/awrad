# 012 — Count Entry Upsert Pattern

**Status:** Accepted
**Date:** 2025-02 (Migration 5→6)
**Context:** Data Integrity, Progress Tracking

---

## Context

Early versions of the app occasionally created duplicate count entries for the same (goalId, date, slotId) combination. This caused inflated progress counts and inconsistent UI. We needed a robust pattern to ensure exactly one row per goal/date/slot.

## Options Considered

### Option A: Always INSERT, aggregate on read
- Insert a new row for every count operation
- Use SUM() queries to compute totals
- Correct but creates many rows; performance degrades over time

### Option B: SELECT then INSERT or UPDATE (application-level check)
- Check if row exists, then insert or update
- Race condition: two concurrent increments could both see "no row" and both insert
- Requires application-level locking

### Option C: Database UNIQUE constraint + upsert pattern
- UNIQUE constraint on `(goalId, date, slotId)` prevents duplicates at the database level
- Upsert: try UPDATE first (returns affected row count), INSERT if 0 rows updated
- Atomic within a database transaction

## Decision

**Option C** — UNIQUE constraint with transaction-based upsert.

## Reasoning

1. **Database-enforced integrity.** The UNIQUE constraint on `(goalId, date, slotId)` makes it physically impossible to create duplicate entries. This is stronger than application-level checks.

2. **Atomic upsert.** The operation runs in a database transaction:
   ```
   BEGIN TRANSACTION
     UPDATE count_entries SET count = count + :increment
       WHERE goalId = :goalId AND date = :date AND slotId = :slotId
     -- If 0 rows updated:
     INSERT INTO count_entries (goalId, slotId, count, date, lastUpdated)
       VALUES (:goalId, :slotId, :increment, :date, :now)
   COMMIT
   ```
   No race condition possible.

3. **Handles NULL slotId correctly.** For non-prayer-based goals, slotId is NULL. SQL's `NULL != NULL`, so the WHERE clause uses `slotId IS NULL` instead of `slotId = :slotId` for the null case. Two separate UPDATE queries handle this.

4. **Migration cleaned up existing data.** The v5→v6 migration consolidated duplicate rows by summing counts and taking the latest timestamp, then recreated the table with the unique constraint. No data was lost.

## Consequences

- Every count increment is a single database call (upsert), not a read-then-write.
- The goal's `totalCompletedCount` is incremented separately (denormalized for fast access).
- No application-level locking or deduplication needed.
- The pattern naturally handles the effective-date change at Maghrib: same goal, new date = new row.
