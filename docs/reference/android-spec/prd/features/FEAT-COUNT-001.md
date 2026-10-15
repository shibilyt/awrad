# FEAT-COUNT-001 — Goal counter

**Status:** implemented. This is the primary practice interaction.  
**Route:** `counting/{goalId}?slotId={slotId}`.  
**Related:** [Goals](FEAT-GOAL-001.md), [Audio](FEAT-AUDIO-001.md), [Progress](FEAT-PROGRESS-001.md).

## Goal

Allow the user to record dhikr repetitions against the correct goal, slot, session, and practice date, with prompt feedback and durable local progress.

## Counter behavior

1. **Enter and restore [OBSERVED].** Bind to the counting service and reconcile the goal/slot with persisted repository state. Prefer a valid route-provided slot; otherwise select a slot using goal schedule, active-time, partially complete ended-slot, and upcoming-slot context. The route goal ID must resolve before counting is enabled.
2. **Show context [OBSERVED].** Expose current count/target, slot availability and selection, session target/context, goal details, and counter controls. The screen reads preferences for vibration, keep-screen-on, click sound, text size, and line spacing; keep-screen-on is an Activity window flag while the screen is active.
3. **Manual increment [OBSERVED].** A valid tap requests one count. The service applies the current goal/slot cap policy, updates visible state, writes through the local repository, then corrects the service state to the amount actually persisted. Offline counting does not wait for API access.
4. **Enforce availability [OBSERVED].** Disable or gate actions when the selected slot is not currently countable. For non-active time slots, show the configured warning/confirmation path where the policy allows continuation. At-target policy may block, warn, or allow over-target counting according to goal policy. Do not apply one global rule to every goal.
5. **Handle completion [OBSERVED].** Evaluate target transitions after persisted count changes. Emit the completion sound/vibration once for the target-reaching transition. When all slots are complete and the target has just been reached, cancel associated reminders. Re-entry reads local progress and must not replay a past completion signal.
6. **Inspect and correct [OBSERVED].** Provide history, estimates, slot details, goal detail/edit paths, past-date count adjustment, and explicit confirmations for subtract/reset/restart or other destructive adjustments. Preserve the original record basis for sync; corrections cannot create negative debt.
7. **Sessions and controls [OBSERVED].** Provide session target/context, playback speed controls when using audio, text size/full-text controls, and an option that confirms before audio is stopped by navigating away.

## Counter requirements

- **COUNT-001** Persist each accepted local mutation before treating it as durable progress.
- **COUNT-002** Use Android `Long` and shared signed 64-bit count semantics; never overflow or wrap a count.
- **COUNT-003** Compute cap from canonical plus pending local progress. Offline devices can independently exceed a shared cap before sync convergence; the server preserves accepted credits and the client blocks further positive counts after convergence.
- **COUNT-004** An audio completion increments by the goal's configured `audioCountPerPlay`; manual taps increment by one.
- **COUNT-005** At hard maximum/cap, stop active audio. A zero applied audio increment also stops playback to prevent uncontrolled repeat attempts.
- **COUNT-006** Keep the counter screen awake only when the user preference requests it and the screen is active; restore the original window behavior on exit.
- **COUNT-007** Bind vibration/click sound behavior to the user's counter preferences.

## Empty, unavailable, and failure states

Missing goal/slot must not display a count control that can mutate unrelated data. Persistence failure must not report a durable accepted count. Denied vibration/notification permission does not block manual counting. Exact process-death restoration of active audio/session UI is **[UNKNOWN]**.

## Acceptance examples

1. One permitted manual tap adds one persisted count to the selected goal/slot/date.
2. Selecting a valid route slot takes precedence over fallback slot choice.
3. A slot outside its active time follows its configured availability policy and communicates the result.
4. A hard count limit stops audio and prevents an additional positive increment.
5. Opening history/goal details and returning preserves local count and selected valid context.
6. A count made offline remains present after process restart and becomes eligible for later sync.

## Open decisions

Confirm exact count date boundary labels, session timer lifecycle, process-death treatment for unfinished sessions, and accessibility semantics for the primary count surface.

