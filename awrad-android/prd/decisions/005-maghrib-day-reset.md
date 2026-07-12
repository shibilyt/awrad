# 005 — Maghrib Day Reset

**Status:** Accepted
**Date:** 2025-02
**Context:** Date Handling, Islamic Calendar, Progress Tracking

---

## Context

In Islamic tradition, the new day begins at Maghrib (sunset), not midnight. A user who completes their evening dhikr at 9 PM considers it part of that evening's practice — but a midnight-based system would count it as the same calendar day as their morning practice. This misalignment was confusing for observant users.

## Options Considered

### Option A: Midnight only (standard behavior)
- Simple: date = current calendar date
- Familiar to all users
- Misaligns with Islamic day concept

### Option B: Maghrib only (forced Islamic day)
- Always use Maghrib as day boundary
- Requires location for Maghrib calculation
- Confusing for users who think in calendar days

### Option C: User-configurable day reset (Midnight or Maghrib)
- Default: Midnight (familiar)
- Option: Maghrib (for users who want Islamic day alignment)
- Requires DateProvider abstraction to compute "effective today"

## Decision

**Option C** — Configurable day reset with Midnight as default.

## Reasoning

1. **Respects Islamic tradition without forcing it.** Some users prefer Islamic day boundaries; others don't. A preference gives each user the right behavior.

2. **Default to Midnight.** Most users (even Muslim) are accustomed to midnight-based days from every other app. This avoids confusion for new users.

3. **Maghrib requires location.** Calculating Maghrib time needs latitude/longitude and a prayer calculation method. If no location is set, the app falls back to Midnight. This graceful degradation prevents broken behavior.

4. **"Effective today" abstraction.** The DateProvider component computes the effective date considering the user's preference. Every part of the app that needs "today's date" uses this abstraction — counting, streaks, goal due-today checks, Wird section assignment, home screen display.

## Implementation

The DateProvider computes effective today as:

```
if day_reset = MIDNIGHT:
    effective_today = current calendar date

if day_reset = MAGHRIB:
    if location is set:
        calculate Maghrib time for today
        if current time > Maghrib:
            effective_today = current calendar date + 1 day
        else:
            effective_today = current calendar date
    else:
        effective_today = current calendar date  (fallback)
```

The effective today is exposed as a reactive stream that recombines whenever preferences change (day reset setting, location, calculation method, madhab).

## Consequences

- Every date-dependent operation must use `effectiveToday` instead of `LocalDate.now()`.
- Count entries store dates as strings ("YYYY-MM-DD"), which makes date comparison simple regardless of reset mode.
- If a user switches from Midnight to Maghrib mid-day (after Maghrib), their effective date jumps forward. Today's counts now belong to "tomorrow." This is correct behavior but could be surprising — no mitigation needed since the user intentionally changed the setting.
- Streak calculation uses the same effective dates, so streaks are consistent with the chosen day boundary.
