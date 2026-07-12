# 007 — Wird Reading System

**Status:** Accepted
**Date:** 2025-02
**Context:** Wird Feature, Content Model, Reading Experience

---

## Context

Beyond simple counting, many Muslims follow structured reading programs — collections of prayers/texts read in sequence over days or weeks. The most well-known is Dalail al-Khayrat (7 daily sections, one per day of the week). The app needed to support these reading practices alongside counting goals.

## Key Decisions

### Why 4 Schedule Types?

Each schedule type maps to a real Islamic reading tradition:

| Type | Real-World Example | Behavior |
|------|-------------------|----------|
| DAILY | Ratib al-Haddad | Same section every day; read the full collection daily |
| WEEKLY_SPLIT | Dalail al-Khayrat | 7 sections, one per day of the week (Mon=0, Sun=6) |
| MORNING_EVENING | Daily Adhkar | 2 sections: morning (before noon) and evening (after noon) |
| FREE | Any collection | No schedule; user reads at their own pace |

**Why not just one type with configurable days?** Each type has distinct UX implications: WEEKLY_SPLIT highlights "today's section" with the day name; MORNING_EVENING switches automatically at noon; DAILY shows the same section daily. Modeling them explicitly keeps the logic clean.

### Why JSON-Bundled Content?

**Options considered:**
1. Hardcoded in source code — not maintainable, can't update without code change
2. Remote API — requires server, network dependency, latency
3. Bundled JSON files in assets — offline, versionable, editable

**Decision: Bundled JSON.** Reasons:
- **Offline-first.** Content is available immediately, no network needed.
- **Versionable.** Each JSON has a `version` field. On app update, if the bundled version is higher, the content is re-imported.
- **Human-editable.** Islamic scholars or translators can edit JSON without touching source code.
- **Extensible.** Adding a new collection is as simple as adding a new `.json` file to `assets/wirds/`.

### Why Per-Item Repeat Counts?

Authentic Islamic texts specify that certain phrases should be repeated a specific number of times (e.g., "recite 3 times" or "recite 10 times"). Rather than duplicating the item N times in the data, we store `repeatCount: N` on each item.

**Impact on the reader:**
- The user sees "2/3" on an item, meaning they've recited it 2 out of 3 required times.
- Tapping increments the count. At 3/3, the item is marked complete and the reader auto-advances.
- This feels natural — like a tasbih (prayer beads) counter per item.

### Why `completedItems` as JSON String?

The progress table stores per-item counts as a JSON string: `{"0": 3, "2": 1, "5": 3}` — a map of itemIndex to currentCount.

**Options considered:**
1. Separate table `wird_item_progress(progressId, itemIndex, count)` — clean relational model, but creates thousands of rows for large sections
2. Bitmask for completion — can't track partial progress (2/3 repeats)
3. JSON string — compact, flexible, handles variable items per section

**Decision: JSON string.** Reasons:
- **Sparse representation.** A section with 50 items where only 5 are started stores just 5 entries, not 50 rows.
- **Atomic upsert.** The entire progress state is written in one row update, not 50 individual writes.
- **Good enough for reads.** We never need to query "all sections where item 5 is completed." Progress is always read per-section.
- **Trade-off acknowledged:** JSON inside a relational database is generally a code smell, but here the data is write-heavy, read-as-blob, and never queried across rows — making JSON the pragmatic choice.

## Streak Calculation Per Schedule Type

Streaks mean different things for different schedules:

| Type | Streak Definition |
|------|------------------|
| DAILY / MORNING_EVENING | Consecutive days with at least one section completed |
| WEEKLY_SPLIT | Consecutive weeks with at least one reading session |
| FREE | Total completed dates (not necessarily consecutive) |

**Why different?** A WEEKLY_SPLIT user who reads Monday and Thursday is consistent for that week. Requiring every day would be unfair. FREE collections have no natural period, so we just count total active dates.

## Consequences

- The Wird reader needs two view modes (pager for focused reading, scroll for overview).
- Progress resets daily — each date gets fresh progress records.
- The section assignment logic (`getTodaySectionIndex`) must be consistent across home screen, detail screen, and reader.
- Adding new collections is a data-only change (new JSON file + version bump).
