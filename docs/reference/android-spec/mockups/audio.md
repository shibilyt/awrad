# Mockup — Audio

## Dhikr preview

```text
┌──────────────────────────────────────┐
│ [Dhikr title]                        │
│ [Arabic / translation]               │
│                                      │
│ [Local/download status]              │
│ [◀]       [Play / Pause]       [▶]    │
│ [position ━━━━━━━━━○ duration]        │
│                                      │
│ [Download / remove action]           │
└──────────────────────────────────────┘
```

Preview state identifies one dhikr and tracks playing state, position, and duration. Stopping or player error releases the preview player and resets its state.

## Audio-assisted counting

```text
┌──────────────────────────────────────┐
│ [Goal / selected slot]               │
│                                      │
│              [count / target]        │
│                                      │
│ [audio title]                        │
│ [◀]       [Play / Pause]       [▶]    │
│ [Playback speed]                     │
│ [Current loop / remaining context]   │
│                                      │
│ [Stop]                               │
└──────────────────────────────────────┘
```

A completed playback loop increments by `audioCountPerPlay`. Reaching a hard goal cap stops playback. Leaving with active audio asks for confirmation. Remaining-loop display is shown here as an optional context slot: its exact production presentation is **[UNKNOWN]**.

## Custom audio import

```text
[Choose audio file] -> [Validate type / size / duration]
                     -> [Stage temporary app-owned file]
                     -> [Confirm / commit]
                     -> [Available in dhikr audio actions]
```

Invalid files must not replace a prior committed file. Current supported MIME families and limits are in [FEAT-AUDIO-001](../prd/features/FEAT-AUDIO-001.md).

