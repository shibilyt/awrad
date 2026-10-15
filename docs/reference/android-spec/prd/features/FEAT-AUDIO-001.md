# FEAT-AUDIO-001 — Audio download, preview, and assisted counting

**Status:** implemented with app-owned storage and Media3.  
**Entry points:** onboarding, Settings, dhikr detail, and goal counter.

## Goal

Let a user obtain supported audio, preview it, and optionally count completed audio plays toward a goal.

## Audio preview

- **AUDIO-001 [OBSERVED]** Preview state tracks the active dhikr, playing state, playback position, and duration.
- **AUDIO-002 [OBSERVED]** Resolve an available local downloaded file or remote audio URL, then play using the app's Media3 player. Toggle and stop actions must address the active dhikr; stopping/error releases the preview player and resets visible playback state.
- **AUDIO-003 [OBSERVED]** Download selected audio sequentially, expose progress, and report per-file failures. Downloads use app-owned storage; no broad shared-media permission is used.

## Assisted counting

- **AUDIO-004 [OBSERVED]** The counter service owns playback while a goal is being counted. Start receives the audio source and requested/remaining play context; the foreground media-playback service keeps lifecycle and notification ownership while active.
- **AUDIO-005 [OBSERVED]** Each completed audio play contributes the goal's configured `audioCountPerPlay`, not an arbitrary elapsed-time tick. Loop completion is detected by the Media3 player/service and forwarded to the counting path.
- **AUDIO-006 [OBSERVED]** Playback supports pause/resume and a user-selectable speed control. The valid speed range is **[UNKNOWN]** from the Phase 1 inventory.
- **AUDIO-007 [OBSERVED]** When the goal cap/hard maximum is reached, or the next audio increment applies zero, stop audio. Do not report a count for an incomplete playback.
- **AUDIO-008 [OBSERVED]** Leaving the counter while audio is active requests confirmation before stopping playback.
- **AUDIO-009 [UNKNOWN]** Restoring exact playback position and remaining repetitions across process death/restart is not established.

## Custom audio import

- **AUDIO-010 [OBSERVED]** Accept supported MP4/M4A/AAC/MP3/WAV MIME families only. Current validation limit is less than 10,000,000 bytes and at most 10 minutes duration. Validate metadata and stage/commit into app-specific storage; reject invalid MIME, size, duration, or probe failures.
- **AUDIO-011 [OBSERVED]** Store references to owned app files, not arbitrary external paths; cleanup orphaned owned audio asynchronously at startup.
- **AUDIO-012 [OBSERVED]** Do not read/write shared storage or request media-library permissions for the app-owned audio path.

## Acceptance examples

1. A completed loop adds the configured audio count exactly once.
2. Pause does not increment until a play completes.
3. Reaching a hard cap stops the player and leaves count at the accepted limit.
4. An invalid/oversized/too-long import is rejected without replacing the previously committed audio.
5. Preview and counting playback do not run two independently visible players for the same operation.

## Open decisions

Confirm retry behavior for remote failures, playback-speed bounds, whether downloads may use metered networks, and process-death resume expectations.

