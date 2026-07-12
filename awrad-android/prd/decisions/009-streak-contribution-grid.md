# 009 — Streak & Contribution Grid

**Status:** Accepted
**Date:** 2025-02
**Context:** Home Screen, Progress Visualization, User Motivation

---

## Context

Consistency is the most important factor in building a dhikr habit. We needed a way to visualize the user's practice consistency over time — something that motivates daily engagement and makes "breaking the streak" feel costly.

## Options Considered

### Option A: Simple streak counter only
- "12-day streak" text with a flame icon
- Minimal, clear
- Doesn't show historical patterns or gaps

### Option B: Calendar heatmap (30-day view)
- Calendar grid colored by activity
- Shows exactly which days were active
- Familiar from fitness apps
- Only 1 month of history

### Option C: GitHub-style contribution grid (15-week view)
- 15 columns × 7 rows = 105 days (~3.5 months)
- Color indicates activity (active/inactive)
- Combined with streak counter
- Proven motivational UX from GitHub, fitness apps, language learning apps

## Decision

**Option C** — 15-week contribution grid combined with a streak counter.

## Reasoning

1. **Proven effectiveness.** GitHub's contribution graph is one of the most effective engagement features ever designed. It creates a visual commitment device — seeing green squares fills users with satisfaction, and seeing gaps creates gentle pressure to stay consistent.

2. **15 weeks is the sweet spot for mobile.** 52 weeks (GitHub's default) is too wide for a phone screen. 15 weeks (~3.5 months) fits horizontally while showing enough history to reveal patterns. It captures seasonal changes (e.g., a Ramadan burst of activity).

3. **Binary coloring (active/inactive) is sufficient.** We considered intensity-based coloring (light green = few counts, dark green = many counts) but decided against it. The user's goal is consistency, not volume. Whether they did 10 or 1,000 counts on a given day, the point is they showed up. Binary coloring reinforces this.

4. **Streak counter for quick glance.** The grid shows the full picture, but the streak number with a flame icon gives an instant read: "Am I on track?" This dual display serves both the analytical user (grid) and the quick-glance user (number).

## Streak Algorithm

```
1. Collect all dates with any count entry > 0 into a set.
2. Check if today is in the set.
   - If yes: start streak at today, count = 1.
   - If no: check yesterday. If yesterday is in the set, start there.
   - If neither: streak = 0.
3. Walk backward day by day. For each consecutive day in the set, increment streak.
4. Stop at the first gap.
```

**Key design choice:** Today counts if it has activity. This means the streak doesn't break just because it's still morning and the user hasn't started yet. The streak only breaks when a full day passes with no activity.

## Grid Layout

```
     Week 1   Week 2   ...   Week 15
Mon  [ ][ ]              ...  [ ]
Tue  [ ][ ]              ...  [ ]
Wed  [ ][ ]              ...  [ ]
Thu  [ ][ ]              ...  [ ]
Fri  [ ][ ]              ...  [ ]
Sat  [ ][ ]              ...  [ ]
Sun  [ ][ ]              ...  [■]  ← most recent day
```

- Rows = days of week (Monday at top)
- Columns = weeks (oldest left, newest right)
- Most recent day is bottom-right
- Future dates are empty/transparent
- Active days use primary color (sage green)
- Inactive days use neutral/muted color

## Consequences

- The home screen queries all dates with progress to build the active dates set.
- The grid component must handle edge cases: partial first week, partial last week, future dates.
- Streak count is displayed next to a fire icon for visual emphasis.
- The active dates set is shared between the streak calculation and the grid coloring — computed once, used twice.
