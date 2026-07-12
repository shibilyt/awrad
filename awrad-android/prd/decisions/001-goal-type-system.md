# 001 — Goal Type System

**Status:** Accepted
**Date:** 2025-01
**Context:** Goal System, Data Model

---

## Context

Users perform dhikr in fundamentally different patterns. A simple "daily target" model would force all users into the same mold. We needed to understand how Muslims actually practice and design a system that maps to real behavior.

## Options Considered

### Option A: Single goal type with a daily target
- Simple data model (one `targetCount` per goal)
- All goals repeat daily
- User adjusts behavior manually

### Option B: Freeform goal with configurable recurrence rules (like calendar events)
- RRULE-style recurrence (daily, weekly, monthly, custom)
- Highly flexible
- Complex to implement and explain to users

### Option C: 4 distinct goal types mapped to real practice patterns
- DAILY: Simple recurring daily target
- PRAYER_BASED: Tied to specific prayers with before/after timing
- ONE_TIME: Large cumulative target (e.g., 70,000x)
- ADVANCED: Daily recurring with optional duration and notifications

## Decision

**Option C** — 4 distinct goal types.

## Reasoning

1. **Maps to real behavior.** Muslims practice dhikr in exactly these patterns:
   - "I say SubhanAllah 100 times every day" → DAILY
   - "I say Isthighfar 33 times after each prayer" → PRAYER_BASED
   - "I want to complete 70,000 La ilaha illallah" → ONE_TIME
   - "I say Swalath 500 times daily for 40 days" → ADVANCED

2. **Simpler than freeform.** Users don't need to think about recurrence rules. They pick a type and the app handles the scheduling logic.

3. **Different UI per type.** Each type can have a tailored creation form:
   - PRAYER_BASED shows a prayer selector with before/after timing
   - ADVANCED shows duration and notification options
   - DAILY/ONE_TIME are clean and simple

4. **Different progress semantics.** ONE_TIME goals track cumulative progress across all dates. DAILY goals reset each day. PRAYER_BASED goals have per-slot progress. These differences need to be first-class, not bolted on.

5. **Extensible.** ADVANCED serves as a catch-all for future patterns without breaking the simple types.

## Consequences

- Goal creation wizard adapts its form based on selected type.
- The "due today" logic differs per type (ONE_TIME only due on start date; DAILY always due).
- Progress display differs per type (daily count vs. cumulative count).
- The slot system (see Decision 002) was co-designed with PRAYER_BASED to handle per-prayer targets.
