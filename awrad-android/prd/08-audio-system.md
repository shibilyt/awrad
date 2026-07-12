# 08 - Audio System

## Overview

The app has two distinct audio subsystems: a **preview player** for browsing the library, and a **counting service** for active dhikr counting with background playback.

---

## Audio Preview Player

Used in: Library screen, Category screen, Create Goal screen, Dhikr Detail screen.

### Requirements

- R-AUDIO-001: The preview player is a singleton - only one instance exists across the entire app.
- R-AUDIO-002: Only one dhikr can be previewing at any time.
- R-AUDIO-003: Toggling playback on the same dhikr pauses/resumes it.
- R-AUDIO-004: Starting playback on a different dhikr stops the current one and starts the new one.
- R-AUDIO-005: Audio does NOT loop in preview mode (plays once, then stops).
- R-AUDIO-006: Playback state includes: dhikrId, isPlaying, currentPositionMs, durationMs, progress (0.0-1.0).
- R-AUDIO-007: Progress updates at ~200ms intervals while playing.
- R-AUDIO-008: When audio reaches the end, state resets to not-playing.
- R-AUDIO-009: Prefer local audio file if downloaded; otherwise stream from remote URL.

---

## Audio Counting Service

Used in: Counting screen (background-capable foreground service).

### Requirements

- R-AUDIO-010: The counting service runs as a foreground service with a persistent notification.
- R-AUDIO-011: Audio playback continues even when the app is in the background or the screen is off.
- R-AUDIO-012: The service type is "media playback" to prevent the OS from killing it.
- R-AUDIO-013: Audio plays in a loop. Each complete play cycle increments the count by `audioCountPerPlay`.
- R-AUDIO-014: The service tracks: goalId, currentCount, targetCount, isPlaying, isAudioMode, audioPosition, audioDuration, playbackSpeed, slot info, and error state.

### Playback Loop Logic

- R-AUDIO-020: When starting audio counting:
  1. Calculate remaining plays: `(targetCount - currentCount) / audioCountPerPlay`
  2. Set up looped playback
  3. On each loop completion (audio plays fully once): increment count by `audioCountPerPlay`
  4. On the final play: disable looping so audio ends naturally
  5. When count reaches target: stop playback, play celebration sound
- R-AUDIO-021: If `audioCountPerPlay > 1`, each loop counts as that many (e.g., if `audioCountPerPlay = 2`, each play adds 2 to the count).
- R-AUDIO-022: The final increment is capped so the count never exceeds the target.

### Playback Speed

- R-AUDIO-023: Speed range: 0.75x to 3.0x (inclusive).
- R-AUDIO-024: Speed changes take effect immediately on the currently playing audio.
- R-AUDIO-025: Default speed is 1.0x.

### Foreground Notification

- R-AUDIO-030: Notification channel: "Dhikr Counting" with low importance (no sound/vibration).
- R-AUDIO-031: Notification title: dhikr transliteration.
- R-AUDIO-032: Notification content:
  - Manual mode: "currentCount / targetCount"
  - Audio mode: "currentCount / targetCount · currentTime / totalDuration" with a progress bar
- R-AUDIO-033: Notification has a Play/Pause action button in audio mode.
- R-AUDIO-034: Notification is ongoing (cannot be swiped away).
- R-AUDIO-035: Notification is removed when counting stops.
- R-AUDIO-036: Tapping the notification opens the counting screen for the active goal.
- R-AUDIO-037: Position updates in the notification at ~200ms intervals.

### Service Lifecycle

- R-AUDIO-040: The service starts when the user opens the Counting screen.
- R-AUDIO-041: The service stops when:
  - The user explicitly stops counting
  - The goal target is reached
  - The user navigates away without active audio (service stays alive with audio playing)
- R-AUDIO-042: Guard against duplicate initialization (starting counting for the same goal twice).
- R-AUDIO-043: On service destroy, release all audio resources.

---

## Audio Download System

### Requirements

- R-AUDIO-050: Audio files are downloaded from remote URLs and stored locally.
- R-AUDIO-051: Downloaded files are stored in a dedicated subdirectory (e.g., `dhikr_audio/`).
- R-AUDIO-052: Download uses HTTP with timeouts: 15s connect, 30s read.
- R-AUDIO-053: Buffer size: 8KB for streaming downloads.
- R-AUDIO-054: If a download fails, delete the partial file.
- R-AUDIO-055: Track download progress as a reactive stream with: completed count, total count, current filename.
- R-AUDIO-056: Batch download support: download multiple files sequentially, tracking overall progress.
- R-AUDIO-057: After successful download, update the dhikr record: set `isDownloaded = true`, store `audioFileName`.
- R-AUDIO-058: Provide methods to check if a file exists locally and to get the full file path for playback.

---

## Audio Error Handling

- R-AUDIO-060: If audio fails to load (network error, corrupt file), set an error flag on the counting state.
- R-AUDIO-061: The UI should display an error message and allow the user to:
  - Retry loading the audio
  - Fall back to manual counting
- R-AUDIO-062: Clear the error flag when the user dismisses the error or retries.
