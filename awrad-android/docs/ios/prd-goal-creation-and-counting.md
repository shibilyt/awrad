# PRD — Goal Creation & Goal Counting (iOS, Liquid Glass)

**Product:** Awrad — Dhikr Goals Tracker (iOS port)
**Scope:** Two flows only — (1) Goal Creation, (2) Goal Counting page
**Source of truth:** Android implementation (Kotlin/Compose). This PRD restates that behavior as platform-neutral requirements and adds the iOS visual language.
**Status:** Draft for implementation
**Date:** 2026-06-13

---

## 1. Overview & Goals

Awrad helps Muslims set and complete dhikr (remembrance/supplication) counting goals. The iOS app must reproduce the Android feature behavior of two core flows with full functional parity, while adopting Apple's **Liquid Glass** design language (translucent, layered, light-bending materials introduced in the iOS 26 design system).

### Objectives
- **Functional parity** with Android for goal creation and counting — same data model, same options, same validation, same persistence semantics.
- **Native iOS feel** — Liquid Glass surfaces, SF Symbols, native sheets, haptics (Core Haptics / `UIImpactFeedbackGenerator`), Dynamic Type, RTL (Arabic) support.
- **Offline-first** — local store is the source of truth; no network dependency to create a goal or count.

### Non-goals (this PRD)
- Home/dashboard, wird reader, prayer-time settings screens, onboarding cinematic scenes, notifications scheduling UI. (Counting coach marks ARE in scope as part of the counting page.)
- Cloud sync mechanics.

---

## 2. Design Language — Liquid Glass

Apply consistently across both flows.

### Materials & surfaces
- Use system glass materials (`.regularMaterial` / `.ultraThinMaterial` equivalents, or the iOS 26 `Glass` effect) for: top bars, the count hero panel, bottom sheets, preset chips, and the floating primary button.
- Cards float above a soft, content-aware background tinted with the brand palette. Avoid flat opaque fills; prefer translucency with a subtle specular edge highlight and adaptive shadow.
- Concentric corner radii: outer containers ~28–32pt, inner controls ~16–20pt, chips fully rounded (capsule).

### Brand palette (carry over from Android)
- Primary: **Sage green `#4B7C5A`**
- Accent: **Gold `#D4A843`**
- Glass tints derive from these; progress fills use primary, completion/celebration uses gold.

### Typography
- Headers: **Manrope** (bundle the font; fall back to SF Pro Rounded Semibold if unavailable).
- Body: **Plus Jakarta Sans** (fall back to SF Pro Text).
- Arabic: a legible naskh face at large size, RTL-correct.
- Support Dynamic Type; the large counter number scales but never truncates.

### Motion & feedback
- Spring-based transitions; glass surfaces should feel like they "lift" on press.
- Count tap: light impact haptic; optional sound. Goal/session completion: success haptic + celebratory accent.
- Progress animates smoothly (~260ms equivalent spring).

### Localization
- English + Arabic. Full RTL mirroring. All copy uses string keys; reuse the Android keys listed in §6 so translations are shared.

---

## 3. Flow A — Goal Creation

### 3.1 Entry points
1. **Standard**: user opens Create Goal → starts at **Select Dhikr**.
2. **Deep-link from a Dhikr detail** (`dhikrId` provided): skip Select Dhikr, open **Quick Create** with the dhikr **locked** (no "Change dhikr" affordance; back returns to the previous screen).
3. **Edit existing goal**: open Quick Create with all fields pre-populated.

State is preserved navigating back and forth. Changing the selected dhikr resets goal config to defaults.

### 3.2 Step 1 — Select Dhikr
- Searchable list of all dhikrs.
- Search filters live across `title`, `transliteration`, `translation` (case-insensitive) and `arabic` (case-sensitive).
- Each row: Arabic (RTL), transliteration, translation. Tapping a row advances to Quick Create with that dhikr selected.
- Dhikr model fields: `id, title, arabic, transliteration, translation, audioUrl?, audioFileName?`.

### 3.3 Step 2 — Quick Create (primary path)
A single scrolling screen on glass:
1. **Dhikr header card** — Arabic, transliteration, translation, inline audio preview; "Change" affordance unless locked.
2. **Type selector** — 4 glass cards (2×2): **Daily** (default), **One-Time**, **Tracker**, **Advanced**.
3. **Contextual count input** — changes per type with a crossfade keyed on input type:
   - **Daily** — "How many times each day?" Default `33`. Quick-value capsule chips: `33 · 70 · 100 · 313`.
   - **One-Time** — "Total count to complete." Default `1000`. Chips: `100 · 1000 · 10000`.
   - **Tracker** — no input; caption "Just counting — no target set."
   - **Advanced** — opens the full editor (§3.5).
4. **Create Goal button** — full-width, floating glass, pinned at bottom.

### 3.4 The 4-axis goal model (parity-critical)
Every goal is defined across four orthogonal axes. Quick presets set all four at once; Advanced exposes them.

**Axis 1 — Frequency** (when the goal recurs): `DAILY, WEEKLY, MONTHLY, INTERVAL, YEARLY, SPECIFIC_DATES` (plus `SEASON` templates).
- Weekly → set of weekdays (≥1).
- Monthly → set of days 1–31 + calendar `gregorian | hijri`.
- Interval → every N days (default 3) + anchor date.
- Yearly → month (1–12) + days + calendar.
- Season → `SeasonTemplateCode`: `RAMADAN, RAMADAN_LAST_10, DHUL_HIJJAH_1_10, WHITE_DAYS, ASHURA, ARAFAH`.
- Specific dates → free-text list (comma/newline separated, parsed).

**Axis 2 — Timing** (when during a due day counting happens): `ANYTIME, PRAYER_BASED, TIME_BASED`.
- UI drafts: `Anytime, PrayerBased, MorningEvening, CustomSlots`.
- Prayer-based → relation `BEFORE | AFTER | BOTH`; prayers `FAJR, DHUHR, ASR, MAGHRIB, ISHA` (≥1); optional per-prayer counts; lead-before minutes for BEFORE/BOTH.
- Custom slots → list of time windows (label, start time, duration minutes; default Session 1, 8:00, 60min).
- Morning/Evening preset → fixed windows (Morning 5–11, Evening 17–22).

**Axis 3 — Count rule** (how counting is governed). UI mode `CountRuleMode`: `Tracker, Minimum, Target, Stretch, Exact, Bounded`.
- Persisted as `CountPolicy { minimumCount?, targetCount?, maximumCount?, streakThreshold, reminderThreshold, completionThreshold, capBehavior }`.
- Cap behavior: `AllowOverTarget, WarnOverTarget, BlockAtTarget, BlockAtMaximum`.

**Axis 4 — Target/Progress scope** (how progress aggregates & completion): `TargetPolicy = PER_DUE_DATE, CUMULATIVE_TOTAL, PERIOD_TOTAL, NONE` → `ProgressScope = DueDate, Period, Lifetime`.

**Presets** (`GoalPreset`) populate all axes:
- `DAILY` — Daily / Anytime / Target(100) / PerDueDate
- `PRAYER_BASED` — Daily / Prayer(33 each) / PerDueDate
- `ONE_TIME` — Daily / Anytime / Target(70k) / Cumulative
- `TRACKER` — Daily / Anytime / None / None
- `WEEKLY` — Weekly(Fri) / Anytime / Target(1000) / Period
- `ISLAMIC_SEASON` — Season(Ramadan) / Anytime / Target(10k) / Period
- `MORNING_EVENING` — Daily / Time(Morning+Evening) / Target(100) / PerDueDate
- `CUSTOM` + `ADV_*` variants — fully editable in Advanced editor.

Quick presets shown in Quick Create: `DAILY, PRAYER_BASED, ONE_TIME, TRACKER, WEEKLY, ISLAMIC_SEASON, MORNING_EVENING`.

### 3.5 Advanced editor (full configuration)
Sectioned glass form exposing all axes. Sections appear conditionally:
- **Schedule** — frequency type + its sub-fields (above).
- **Timing** — timing draft + its sub-fields; `SlotTargetMode = Same | PerSlot` to share or per-slot override targets.
- **Count rule** — mode selector switching visible inputs; per-mode fields and validation per table below; cap behavior for Bounded/Exact.
- **Extras** — duration (on/off + days), minimum streak (on/off + count), notifications (on/off + time for Anytime), `slotCountingPolicy = WARN_AND_ALLOW | STRICT_ACTIVE_ONLY | SILENT_FLEXIBLE`.

### 3.6 Slots
Slots are the atomic counting buckets; every goal has ≥1. `GoalSlotType = ANYTIME, PRAYER, TIME_WINDOW`.
- Anytime → 1 slot.
- Prayer-based → one slot per prayer × relation (e.g., "After Fajr"), with optional per-prayer target and lead minutes.
- Time windows → one slot per window with start/end minute-of-day, label, target.

Slot fields: `slotType, minimumCount?, targetCount?, maximumCount?, capBehavior, prayerName?, prayerRelation?, startMinute?, endMinute?, startLeadMinutesOverride?, label?, sortOrder, isActive, archivedAt?`.

### 3.7 Validation rules
Block "Create Goal" and show inline errors until resolved:
- Dhikr selected; type/template chosen.
- Targets > 0 (except Tracker). Tracker must NOT have a target.
- Counts ordered: `min ≤ target ≤ max`; Stretch requires target > min; Bounded requires min < target < max; Exact > 0.
- Weekly ≥1 weekday; Monthly ≥1 day; Yearly ≥1 day; Specific dates ≥1 date; Season selected; Interval > 0.
- Prayer-based ≥1 prayer; custom slots ≥1 valid window; valid time window/prayer slot.
- Reminder time valid (hour 0–23, minute 0–59) when fixed + Anytime.
- Duration > 0 if enabled; minimum streak > 0 if enabled.

Map to messages: `SelectDhikr, ChooseTemplate, PositiveTotalTarget, PositiveSlotTarget, PositiveMinimumCount, PositiveExactCount, PositiveMaximumCount, TargetMustExceedMinimum, BoundedCountsOrdered, TrackerCannotHaveTarget, SelectWeekday, SelectMonthDay, SelectYearDay, AddDate, SelectSeason, PositiveInterval, AddSlot, SelectPrayer, AddTimeSlot, InvalidTimeWindow, InvalidPrayerSlot, InvalidReminderTime, PositiveDuration, PositiveMinimumStreak`.

### 3.8 Persistence (on Create)
Build a `CreateGoalCommand { dhikrId, startDate, schedule, timing, slotCountingPolicy, countPolicy, progressScope, completionPolicy, reminders[], durationDays? }`, validate, and write to the local store. Tables/records to mirror: `goals`, `goal_recurrences` (+ weekday/month-day/dates junctions), `goal_slots`, `goal_reminders`, `count_entries`. On success, navigate to goal detail/home.

---

## 4. Flow B — Goal Counting page

The screen is driven by a counting state object kept alive by a background/foreground counting service (audio + persistence) on Android. On iOS, reproduce with an `ObservableObject` counting engine backed by a background audio session (`AVAudioSession` `.playback`) and `BGTask`/foreground continuation so counts persist and audio keeps playing.

### 4.1 Layout (glass, top → bottom)
- **Top bar** (glass): back button (confirm if audio playing), dhikr transliteration title (centered, truncates), overflow menu: *Goal details · Estimates · Adjust count*.
- **Hero panel** (the centerpiece glass card), two modes:
  - **Simple goal**: large current count, denominator (`2,350 / 5,000`), animated linear progress, `Minimum: N` chip when `minimumCount` set (`counting_min_for_streak`). When a session is active: shows session count + `X / Y overall` + "End session".
  - **Slot goal**: slot title/timing, counter + progress, footer with "Next slot: …" / "No slots left today", timing text, and a **Slots** button.
- **Arabic text card**: dhikr Arabic (2-line truncate) + "See full" → bottom sheet.
- **Controls row**: Audio button (wide; `counting_start_audio` / `counting_stop_audio`; turns red/error while active; disabled when goal reached); **Session target** icon button (target/`scope` symbol; hidden when session active or goal reached); **History** icon button (chart symbol → history/streak sheet).
- **Audio player row** (only in audio mode): play/pause, position progress (4pt, animated), `M:SS / M:SS`, speed button (`1×`, `1.25×`, … presets 0.75–3.0), ETA (`counting_session_ends_at`).
- **Slot complete banner** (conditional): "Session complete!" + "Select next slot".
- **COUNT button** (only in manual mode): large circular floating-glass button, `counting_count_button`; disabled when `canManualCount` is false.

### 4.2 Tap-to-count
- Tap COUNT → +1 via the counting engine.
- **Slot timing guard** per `slotCountingPolicy`:
  - `STRICT_ACTIVE_ONLY`: only when slot status `ACTIVE`/`ANYTIME`.
  - `WARN_AND_ALLOW`: allow but confirm on `UPCOMING` ("starts at …, count now anyway?") or `ENDED` ("ended at …, keep counting / switch to next").
  - `SILENT_FLEXIBLE`: allow silently.
- **Feedback**: light impact haptic if enabled; short beep if sound enabled.
- **Cap** via cap calculator: `AllowOverTarget` unlimited; `WarnOverTarget` warns once before crossing target (`count_over_target_warning`); `BlockAtTarget`/`BlockAtMaximum` reject with snackbar (`count_hard_cap_reached`).
- **Undo / adjust**: no inline undo; menu → "Adjust count" opens numeric add/subtract; subtraction requires confirmation (`subtract_warning`). Adjustments affect daily count only, not session count.

### 4.3 Audio-assisted counting
- Tap audio button → engine loads file (local cache or URL), plays looped (repeat-one).
- Each loop completion increments count by `audioCountPerPlay` (default 1, per-dhikr). Remaining plays = `ceil(remaining / countPerPlay)`. When the last play is reached, switch off repeat; final completion does the last increment and exits audio mode.
- Controls: play/pause, speed 0.75×–3.0× (presets 0.75/1.0/1.25/1.5/1.75/2.0 + ±5% stepper), position display.
- Duration pre-read for ETA estimates. Load failure → error flag + snackbar (`error_audio_load`).
- If a session COUNT target is active, cap plays to session remaining.
- On goal completion: audio stops, success sound, `goalReached = true`, completion dialog.
- Back while audio playing → confirm (`audio_playing_back_title` / `audio_playing_back_message`): "Keep counting" / "Stop and go back".

### 4.4 Sessions
A session is an optional mini-goal within one sitting; it does NOT change daily progress and can be restarted.
- Types: **COUNT** (target count; presets `33/100/500/1000` filtered by remaining) or **TIMER** (minutes; presets `5/10/15/30` + slider).
- Set via "Set session target" → bottom sheet with **Count** / **Timer** tabs; shows estimated time/count; "Start Session" activates.
- While active: hero shows session count + target, with `X / Y overall` daily progress and an "End session" control. Manual taps and audio increment both daily and session counts.
- Completion: COUNT when session count ≥ target; TIMER when elapsed ≥ minutes×60. Dialog (`counting_session_complete_title` + body / body_timer): "Another session" (restart) or "Done" (clear).

### 4.5 Slots & switching
- Slot status: `ACTIVE, UPCOMING, ENDED, ANYTIME, UNKNOWN`.
- Default active slot selection priority: requested → restored → currently active (by start, then sort) → earliest ended with progress → earliest upcoming → latest ended incomplete → first uncompleted.
- "Slots" button → bottom sheet: overall `X/Y` + progress, then per-slot rows (● active / ✓ complete indicator, title/subtitle, `count/target`, "(Active)"/"(Recommended)" badge, per-slot progress). Tap to activate.
  - `STRICT_ACTIVE_ONLY` allows selecting only ACTIVE/ANYTIME slots; other policies allow any (warn on count).
- On switch: engine updates active slot, counter & progress switch to that slot, audio stops if active slot changes.
- Slot completion: count ≥ slot target marks complete; if current complete but others remain → banner (`counting_slot_complete`) prompting next slot.
- A 60-second ticker detects a time-window ending mid-count; under `WARN_AND_ALLOW` show switch/keep dialog (`slot_ended_*`), dismissal remembered per goal/slot/date.

### 4.6 Progress, minimum-for-streak, completion
- Daily progress = `currentCount / targetCount` (clamped). Multi-slot overall = `Σ slot counts / Σ slot targets`.
- `minimumCount` per goal → `Minimum: N` chip (`counting_min_for_streak`); a day counts toward streak if count ≥ minimum (or ≥ target).
- Goal complete when `currentCount ≥ targetCount` (and all slots complete for slot goals). On completion: full progress bar, COUNT + audio disabled, success sound, completion dialog (`goal_reached_title` / `goal_reached_body`: "You've completed X counts." → "Done" returns). If slots remain → "Session complete!" banner instead.

### 4.7 Counting coach marks (first run)
Shown first time the screen is opened (`hasSeenCountingGuide == false`). Non-interactive scrim — taps pass through to the COUNT button. Liquid Glass spotlight: dimmed glass scrim (~62% black equivalent), spotlight punch-out (circle for COUNT, rounded-rect others) with 12pt padding + gentle pulse; hint card placed opposite the spotlight; ~420ms transitions. "Skip" always available (top-trailing) → marks seen.

Steps (conditional ones skipped if N/A):
1. **Tap to count** (COUNT, circular) — `coach_tap_title/body`; gated: requires 3 real taps; shows `X of 3`.
2. **Watch progress** (hero) — `coach_progress_title/body`; manual advance.
3. **Set session target** (session button) — `coach_session_title/body`; only if sessions supported.
4. **Review history** (history button) — `coach_history_title/body`; only if visible.
5. **Audio counting** (audio button) — `coach_audio_title/body`; only if dhikr has audio; gated: requires 3 audio plays; finishing marks guide seen.

### 4.8 Counting engine (iOS mapping of the foreground service)
Maintain a published `CountingState`:
```
goalId, currentCount, targetCount, maximumCount?, capBehavior,
goalMaximumCount?, goalCapBehavior, isPlaying, isAudioMode, goalReached,
dhikrArabic, dhikrTransliteration, audioPositionMs, audioDurationMs,
audioCountPerPlay, playbackSpeed, isPrayerBased,
slots[], activeSlotId?, slotCounts{slotId:count}, audioError
```
Responsibilities: persist counts to local store (optimistic UI + reconcile with persisted delta), manage `AVPlayer`/`AVQueuePlayer` looped playback with per-loop increments, show a Now Playing / Live Activity surface with count + audio position + play/pause, handle slot switching (recompute effective count/target; stop audio on slot change). Counts and session state must survive app backgrounding/termination (persist to store + restore on relaunch).

---

## 5. Acceptance criteria (high level)
- Can create each preset goal end-to-end and see it persisted with correct slots, recurrence, and count policy.
- Advanced editor can produce every axis combination; invalid combinations are blocked with the correct inline message.
- Counting: manual tap, audio counting, sessions (count + timer), slot switching, caps/warnings, minimum chip, and completion all behave as specified.
- Coach marks appear once, gate on the 3-tap and 3-play steps, and never block real taps.
- Full RTL/Arabic rendering; Dynamic Type; light & dark with correct Liquid Glass materials.
- Works fully offline.

---

## 6. String keys (reuse from Android for shared localization)
`counting_min_for_streak, counting_count_button, counting_start_audio, counting_stop_audio, counting_view_history, counting_set_session_target, counting_session_overall, counting_session_target, counting_session_count_tab, counting_session_timer_tab, counting_session_complete_title, counting_session_complete_body, counting_session_complete_body_timer, counting_session_ends_at, counting_slot_complete, counting_select_next_slot, slot_not_started_title, slot_not_started_body, slot_ended_title, slot_ended_body, slot_ended_body_with_switch, goal_reached_title, goal_reached_body, audio_playing_back_title, audio_playing_back_message, count_over_target_warning, count_hard_cap_reached, slot_count_blocked_outside_active, subtract_warning, adjust_count, error_audio_load, coach_tap_title, coach_tap_body, coach_progress_title, coach_progress_body, coach_session_title, coach_session_body, coach_history_title, coach_history_body, coach_audio_title, coach_audio_body, coach_count_progress`

---

## 7. Enum reference (verbatim, for parity)
- **GoalPreset**: `DAILY, PRAYER_BASED, ONE_TIME, TRACKER, WEEKLY, ISLAMIC_SEASON, MORNING_EVENING, CUSTOM, ADV_DAILY, ADV_PRAYER_BASED, ADV_WEEKLY, ADV_MONTHLY_GREGORIAN, ADV_MONTHLY_HIJRI, ADV_INTERVAL, ADV_YEARLY_GREGORIAN, ADV_YEARLY_HIJRI, ADV_SPECIFIC_DATES, ADV_TRACKER`
- **FrequencyType**: `DAILY, WEEKLY, MONTHLY, INTERVAL, YEARLY, SPECIFIC_DATES`
- **RecurrenceFrequency**: `DAILY, WEEKLY, MONTHLY, INTERVAL, YEARLY, SEASON, SPECIFIC_DATES`
- **TimingType**: `ANYTIME, PRAYER_BASED, TIME_BASED`
- **GoalTimingDraft**: `Anytime, PrayerBased, MorningEvening, CustomSlots`
- **TargetType**: `NONE, FIXED, CUSTOM`
- **TargetPolicy**: `PER_DUE_DATE, CUMULATIVE_TOTAL, PERIOD_TOTAL, NONE`
- **ProgressScope**: `DueDate, Period, Lifetime`
- **CountRuleMode**: `Tracker, Minimum, Target, Stretch, Exact, Bounded`
- **CapBehavior / CountCapBehavior**: `AllowOverTarget, WarnOverTarget, BlockAtTarget, BlockAtMaximum`
- **SlotCountingPolicy**: `WARN_AND_ALLOW, STRICT_ACTIVE_ONLY, SILENT_FLEXIBLE`
- **GoalSlotType**: `ANYTIME, PRAYER, TIME_WINDOW`
- **SlotTimeStatus**: `ACTIVE, UPCOMING, ENDED, ANYTIME, UNKNOWN`
- **SlotTargetMode**: `Same, PerSlot`
- **Prayer**: `FAJR, DHUHR, ASR, MAGHRIB, ISHA`
- **PrayerRelation**: `BEFORE, AFTER` · **PrayerTiming (draft)**: `BEFORE, AFTER, BOTH`
- **SeasonTemplateCode**: `RAMADAN, RAMADAN_LAST_10, DHUL_HIJJAH_1_10, WHITE_DAYS, ASHURA, ARAFAH`
- **ReminderType**: `FIXED_TIME, PRAYER_OFFSET, TIME_WINDOW_START`
- **CompletionPolicy**: `Never, WhenTargetReached, DurationEnded`
- **SessionTargetType**: `COUNT, TIMER`
- **GoalCreationMode**: `SelectDhikr, QuickCreate`
