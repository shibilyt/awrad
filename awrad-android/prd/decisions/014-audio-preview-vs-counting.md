# 014 — Audio Preview vs Counting Separation

**Status:** Accepted
**Date:** 2025-01
**Context:** Audio System, Architecture

---

## Context

The app plays audio in two very different contexts:
1. **Preview:** Browsing the library, listening to a dhikr before creating a goal. Short-lived, in-activity.
2. **Counting:** Active dhikr counting session with looped audio. Long-lived, must survive backgrounding.

## Options Considered

### Option A: Single audio system for both
- One player instance shared between preview and counting
- Counting mode just enables looping
- Simpler codebase (one component)
- **Problem:** Preview and counting have conflicting lifecycles. If the user is counting in the background and opens the library to preview a different dhikr, they'd stop their counting session.

### Option B: Two separate audio subsystems
- **AudioPreviewPlayer:** Singleton, lightweight, plays once, no looping, in-app only
- **DhikrCountingService:** Foreground service, looped playback, background-capable, count tracking
- Complete isolation between the two

## Decision

**Option B** — Two separate audio subsystems.

## Reasoning

1. **Lifecycle isolation.** The counting service must survive app backgrounding and screen-off. The preview player should NOT survive navigation — when you leave the library, preview stops. These are opposite requirements.

2. **No interference.** A user counting "La ilaha illallah" in the background while browsing the library and previewing "Swalath al Fatih" should hear both conceptually (though in practice, one has headphones). More importantly, preview shouldn't affect the counting state.

3. **Different state models.**
   - Preview state: dhikrId, isPlaying, position, duration, progress
   - Counting state: goalId, currentCount, targetCount, slots, slotCounts, speed, audioError, etc.

   Mixing these in one component would create a confusing state machine.

4. **Different playback behavior.**
   - Preview: plays once (`REPEAT_MODE_OFF`), auto-stops at end
   - Counting: loops indefinitely (`REPEAT_MODE_ONE`), counts on each loop, stops at target
   - Preview prefers local file, falls back to stream
   - Counting requires reliable local file for looping accuracy

5. **Singleton preview across screens.** The preview player is a singleton shared across Library, Category, Detail, and Create Goal screens. Only one preview plays at a time. This is simpler than managing per-screen player instances.

## Consequences

- Two separate audio codebases to maintain.
- The preview player must stop when navigating to the counting screen (to avoid audio collision).
- The counting service notification and preview playback don't interfere.
- Each component can be tested independently.
