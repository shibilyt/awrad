# Mockup — Goal counter

**Primary route:** `counting/{goalId}?slotId={slotId}`.

```text
┌──────────────────────────────────────┐
│ [Back] [Goal name] [Goal details]    │
│ [Slot selector] [Current slot state] │
│                                      │
│              [current count]         │
│                / [target]            │
│         [progress indication]        │
│                                      │
│        ┌──────────────────┐          │
│        │   TAP TO COUNT   │          │
│        └──────────────────┘          │
│                                      │
│ [History] [Session] [Audio] [More]   │
│ [Count estimate / goal context]     │
└──────────────────────────────────────┘

Potential overlays / sheets:
  • Slot details and availability warning
  • Session target / elapsed or remaining context
  • Count history and historical adjustment
  • Playback speed
  • Text size / full dhikr text
  • Goal reached / allow past target / subtract confirmation
  • Confirm stop audio when leaving while playback is active
```

Exact typography, count-button shape, control labels, and overlay presentation are not asserted. Requirements for slot choice, local persistence, count caps, completion, and audio are in [FEAT-COUNT-001](../prd/features/FEAT-COUNT-001.md).

