# 003 — Audio Counting Architecture

**Status:** Accepted
**Date:** 2025-01
**Context:** Counting Screen, Audio System, Background Playback

---

## Context

A key differentiator of the app is audio-assisted counting: the user plays a dhikr audio recording in a loop, and each loop automatically increments the count. This must work while the screen is off and the app is backgrounded — users often listen with earbuds during commute or before sleep.

## Options Considered

### Option A: In-activity audio playback (MediaPlayer in ViewModel)
- Audio plays in the UI layer
- Stops when activity is destroyed (rotation, backgrounding)
- Cannot survive configuration changes or backgrounding

### Option B: Bound service with ExoPlayer
- Audio runs in a bound service with foreground notification
- Survives backgrounding and screen-off
- Notification provides play/pause control
- Service exposes state via StateFlow for UI binding

### Option C: WorkManager with audio playback
- Long-running WorkManager task
- WorkManager is not designed for real-time audio; inexact execution timing
- No persistent notification control

## Decision

**Option B** — Foreground service with ExoPlayer, exposed via local binding.

## Reasoning

1. **Background survival.** A foreground service with `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK` is the only reliable way to keep audio playing when the app is backgrounded. The OS will not kill a foreground service with an active notification.

2. **ExoPlayer over MediaPlayer.** ExoPlayer (Media3) provides:
   - Precise loop detection via `onPositionDiscontinuity()` — this is how we know a play cycle completed
   - Built-in speed control (`PlaybackParameters`) for the 0.75x–3.0x range
   - Better error handling and state management
   - The modern standard for Android media playback

3. **Notification as remote control.** The persistent notification shows progress ("67/100 · 0:18/0:42") and a Play/Pause action button. Users can control playback without opening the app.

4. **StateFlow for UI binding.** The service exposes `countingState: StateFlow<CountingState>` which the ViewModel collects. This gives reactive UI updates (count, progress, audio position) without tight coupling.

5. **Speed range 0.75x–3.0x.** Below 0.75x the audio becomes unnaturally slow and wastes time. Above 3.0x the recitation becomes unintelligible — the spiritual purpose is lost. This range balances productivity with meaningfulness.

## The `audioCountPerPlay` Design

Some audio recordings contain 2 complete recitations in one file (e.g., the Tahleel recording says "La ilaha illallah" twice). Rather than creating two separate audio files, the `audioCountPerPlay` field on each Dhikr records how many counts one full play equals.

**Impact on loop calculation:**
```
remaining plays = ceil((targetCount - currentCount) / audioCountPerPlay)
```
If target is 100, current is 0, and audioCountPerPlay is 2, we play the audio 50 times.

**Impact on final count:** The last increment is capped so the count never exceeds the target.

## Consequences

- The app requires `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions.
- A notification channel ("Dhikr Counting") with low importance is created for the service notification.
- The counting screen must handle service binding/unbinding lifecycle.
- Audio errors (network failure, corrupt file) set an `audioError` flag on the state, and the UI offers a fallback to manual counting.
- When the user navigates away with audio playing, a confirmation dialog warns them. If they confirm exit, audio stops and the service is destroyed.
