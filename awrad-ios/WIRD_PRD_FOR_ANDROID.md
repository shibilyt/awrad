# Wird Feature — Product Requirements & Data Model (for Android port)

> Source of truth: the Awrad iOS app. This document describes the **behavior and schema**
> so the Android app can reproduce it faithfully. Per project rule: **port the iOS
> behavior/logic exactly; render it with native Android (Material/Compose) styling** — do
> not copy SwiftUI visuals 1:1, copy the *interaction model* and *data semantics*.

---

## 1. What a "Wird" is

A **Wird** (Arabic: ورد) is a structured devotional routine — an ordered collection of
remembrances (dhikr), supplications (dua), salawat, and Qur'anic passages that a user
recites on a schedule (e.g. daily, after a prayer, in Ramadan). Think of it as a
"playlist" of sacred texts with per-item repeat counts and a guided, page-by-page reading
experience that tracks completion and streaks.

Two origins:
- **Library wirds** (`isCustom = false`) — shipped with the app, seeded from bundled JSON,
  read-only, auto-updated by version.
- **Custom wirds** (`isCustom = true`) — created/edited/deleted by the user in-app.

### Core hierarchy

```
Wird  (the collection: name, schedule, reminders)
 └─ WirdPart   (a "section" — e.g. "Morning portion"; has its own occasion + block-repeat)
     └─ WirdSegment  (a single line: dhikr/dua/salah/quran/heading/instruction + repeat count)

WirdSession  (runtime progress: per-day, per-part, per-occasion completion record)
```

**Critical design rule:** progress is keyed by **stable UUIDs** of parts and segments —
never by positional index. Editing a custom wird (reordering, inserting, deleting items)
must never corrupt history, completion, or streaks. Preserve this when designing the
Android persistence (use the same UUIDs; do not regenerate them on edit).

---

## 2. Data Model (schema)

All IDs are UUID (`AwradID = UUID`). All user-facing text uses **localized string maps**:
`{ "en": "...", "ar": "...", "ml": "..." }`. Supported languages: English (`en`),
Arabic (`ar`), Malayalam (`ml`). Arabic is RTL.

### Localized-string resolution rule
Given a requested language:
1. Return the value for that language if present and non-blank.
2. Else fall back to English (`en`) if present and non-blank.
3. Else return the first non-empty value in the map (or empty string).

`localizedOptional` returns `null` instead of empty string when nothing resolves.

### 2.1 Wird

| field | type | default | notes |
|---|---|---|---|
| `id` | UUID | new | stable |
| `slug` | String | — | unique kebab-case; for custom wirds auto-generated as `custom-<first8ofid>` |
| `isCustom` | Bool | false | user-created vs library |
| `version` | Int | 1 | library wirds: bump to push updates to installed users |
| `sortOrder` | Int | 0 | ascending; lower first. Custom wird gets `max(existing)+1` on create |
| `localizedName` | Map<String,String> | {} | display name |
| `localizedDescription` | Map<String,String> | {} | |
| `author` | String | "" | |
| `sourceAttribution` | String? | null | book / compiler; shown in preference to `author` |
| `tags` | [WirdTag] | [] | |
| `estimatedMinutes` | Int? | null | |
| `schedule` | WirdSchedule | default | when it's active + default timing |
| `parts` | [WirdPart] | [] | ordered sections |
| `reminders` | [WirdReminder] | [] | notifications |

Derived:
- `displayName(lang)`, `displayDescription(lang)` — via localized resolution.
- `arabicName` — `localizedName["ar"]` (falls back via resolution to `.arabic`).
- `occasion(for part)` → `part.occasion ?? schedule.defaultOccasion`.
- `part(id)` → lookup by UUID.

### 2.2 WirdTag (enum, lowercase raw values)
`morning, evening, salawat, protection, quran, forgiveness, praise, general`

### 2.3 WirdSchedule

| field | type | default | notes |
|---|---|---|---|
| `cadence` | WirdCadence | `.everyDay` | which days active |
| `hijriAnchor` | HijriAnchor? | null | optional Islamic-calendar gating |
| `defaultOccasion` | WirdOccasion | `.anytime` | timing for parts without their own |

#### WirdCadence (sum type / sealed class)
- `everyDay`
- `daysOfWeek(Set<Int>)` — Calendar weekday ints, **Sunday = 1 … Saturday = 7**
- `interval(days: Int, anchor: String)` — every N days from `anchor` (a `yyyy-MM-dd` dateKey)
- `rotation` — exactly **one part per active day**, cycling through `parts` in order

#### HijriAnchor (sum type)
- `ramadan` — Hijri month == 9
- `lastTenNights` — Hijri month == 9 AND day >= 21
- `hijriMonth(Int)` — months 1…12
- `hijriDate(month: Int, day: Int)`

Use Umm al-Qura calendar for Hijri conversion (iOS uses `islamicUmmAlQura`).

#### WirdOccasion (sum type) — *when within a day a part should be performed*
- `anytime`
- `afterPrayer(Prayer)` — Prayer ∈ {fajr, dhuhr, asr, maghrib, isha}
- `morning`
- `evening`
- `beforeSleep`
- `timeWindow(startMinute: Int, endMinute: Int)` — minutes from midnight (0…1440)

Each occasion has a **stable string `key`** used to distinguish sessions of the same part
on the same day (e.g. a morning vs evening completion). **Match these exactly** — they are
persisted in `WirdSession.occasionKey`:

| occasion | key |
|---|---|
| anytime | `"anytime"` |
| afterPrayer(p) | `"after-<prayerRaw>"` e.g. `"after-fajr"` |
| morning | `"morning"` |
| evening | `"evening"` |
| beforeSleep | `"before-sleep"` |
| timeWindow(s,e) | `"window-<s>-<e>"` e.g. `"window-300-420"` |

### 2.4 WirdPart

| field | type | default | notes |
|---|---|---|---|
| `id` | UUID | new | stable |
| `localizedTitle` | Map<String,String> | {} | |
| `localizedSubtitle` | Map<String,String> | {} | |
| `occasion` | WirdOccasion? | null | overrides wird's `defaultOccasion` when set |
| `blockRepeat` | Int | 1 | repeat the *whole part* N times (multiplies every segment's target) |
| `segments` | [WirdSegment] | [] | ordered |

Derived: `countableSegments` = segments where `kind.isCountable`.

### 2.5 WirdSegment

| field | type | default | notes |
|---|---|---|---|
| `id` | UUID | new | stable |
| `kind` | SegmentKind | `.dhikr` | |
| `arabic` | String | "" | the sacred text (RTL) |
| `transliteration` | Map<String,String> | {} | |
| `translation` | Map<String,String> | {} | |
| `localizedText` | Map<String,String> | {} | **primary text for heading/instruction kinds** |
| `repeatSpec` | RepeatSpec | count=1 | how many times recited |
| `sourceDhikrID` | UUID? | null | link to a library Dhikr (text is *denormalized*/copied in) |
| `quranRef` | QuranRef? | null | for `kind = quran` (text not bundled) |
| `fadl` | Map<String,String> | {} | benefit/virtue note |
| `audioFileName` | String? | null | |
| `audioURL` | URL? | null | |

Derived: `isCountable = kind.isCountable`, `hasAudio = audioURL != null || audioFileName non-empty`.

#### SegmentKind (enum, lowercase raw values)
| kind | countable? | meaning |
|---|---|---|
| `heading` | **no** | sub-title within a part (display only) |
| `instruction` | **no** | rubric, e.g. "recite silently" (display only) |
| `dhikr` | yes | a remembrance line |
| `dua` | yes | a supplication |
| `salah` | yes | salawat on the Prophet ﷺ |
| `quran` | yes | a Qur'anic passage (see `quranRef`) |

Only countable kinds count toward completion/progress.

#### RepeatSpec

| field | type | default | notes |
|---|---|---|---|
| `count` | Int | 1 | clamped to min 1 |
| `min` | Int? | null | range lower bound |
| `max` | Int? | null | range upper bound |

- `target` = `max(min ?? count, 1)` → the count required to mark the segment complete.
- `isRange` = `min != null && max != null && max > lower`.
- `displayText()` = `"<min>–<max>"` if range else `"<target>"`.

#### QuranRef
`surah: Int`, `ayahStart: Int`, `ayahEnd: Int?`.
`displayText()` = `"Qur'an <surah>:<start>-<end>"` or `"Qur'an <surah>:<start>"`.

### 2.6 WirdReminder

| field | type | default | notes |
|---|---|---|---|
| `id` | UUID | new | |
| `reminderType` | ReminderType | `.fixedTime` | `fixedTime` or `prayerOffset` (UI exposes these two; `timeWindowStart` exists in enum) |
| `hour` | Int? | null | for fixed time (0…23) |
| `minute` | Int? | null | for fixed time (0…59) |
| `prayer` | Prayer? | null | for prayerOffset |
| `offsetMinutes` | Int? | null | for prayerOffset (0…120, step 5 in UI) |
| `enabled` | Bool | true | |

### 2.7 WirdSession (runtime progress — the most important table)

Per-day, per-part, per-occasion completion record, keyed by **stable segment IDs**.

| field | type | default | notes |
|---|---|---|---|
| `id` | UUID | new | |
| `wirdID` | UUID | — | |
| `partID` | UUID | — | |
| `occasionKey` | String | `"anytime"` | the occasion key (see table above) |
| `dateKey` | String | — | `yyyy-MM-dd` (gregorian, en_US_POSIX) |
| `segmentProgress` | Map<String,Int> | {} | **key = segmentID.uuidString**, value = current count |
| `lastSegmentID` | UUID? | null | reading position (resume point) |
| `isComplete` | Bool | false | |
| `startedAt` | Date | now | |
| `completedAt` | Date? | null | |

A session is uniquely identified at runtime by the tuple
**(wirdID, partID, occasionKey, dateKey)**. Use that as the lookup/upsert key.

`count(for segmentID)` = `segmentProgress[segmentID.uuidString] ?? 0`.

---

## 3. Business Logic (must match exactly)

### 3.1 Effective target
The completion target for a segment includes the part's block-repeat:

```
effectiveTarget(segment, part) = max(segment.repeatSpec.target, 1) * max(part.blockRepeat, 1)
```

### 3.2 Completion & progress (per part)
- `completedCount(part, session)` = number of **countable** segments whose current count
  `>= effectiveTarget`.
- `progressSummary(part, session)` = `{ completedItems: completedCount, totalItems: countableSegments.count }`.
  - `progress` = `min(completed/total, 1)` (0 if total == 0).
  - `isComplete` = `total > 0 && completed >= total`.
- A part `isComplete` when it has ≥1 countable segment and all countable segments hit target.

### 3.3 Aggregate progress (per wird, "today")
Sum `progressSummary` across all of **today's active parts**.

### 3.4 Which days a wird is active — `isActive(wird, date)`
1. Must pass `hijriAnchor` gate (if set). Hijri gate logic:
   - `ramadan`: hijriMonth == 9
   - `lastTenNights`: hijriMonth == 9 && hijriDay >= 21
   - `hijriMonth(m)`: hijriMonth == m
   - `hijriDate(m,d)`: hijriMonth == m && hijriDay == d
2. Then by cadence:
   - `everyDay` / `rotation`: always true
   - `daysOfWeek(set)`: set contains the gregorian weekday (Sun=1..Sat=7)
   - `interval(days, anchor)`: `days > 0` and `(date - anchorDate) in days % days == 0`
     (diff in whole days; if anchor unparseable, treat as active)

### 3.5 Active parts for a day — `activeParts(wird, date)`
- If not active or no parts → `[]`.
- If cadence == `rotation` → exactly one part: `parts[rotationIndex]`.
- Otherwise → all parts.

**Rotation index** (deterministic across devices — keep the reference date):
```
reference = 2001-01-01 (startOfDay)
diff = whole days from reference to date
index = ((diff % parts.count) + parts.count) % parts.count
```

### 3.6 Occasion windows (for "is this active right now" + ordering)
`window(occasion, prayerTimes, now)` resolves a (start, end) for today:
- `anytime` → (nil, nil) → always active.
- `timeWindow(s,e)` → (midnight+s min, midnight+e min).
- `afterPrayer(p)` → (prayer time p, next prayer time) — last prayer ends at day end.
- `morning` → (fajr, dhuhr) if prayer times known, else (04:00, 12:00).
- `evening` → (asr, isha) if known, else (15:00, 20:00).
- `beforeSleep` → (isha, end-of-day) if known, else (20:00, end-of-day).
- `isActiveNow` = `start <= now < end` (true if no bounds).

Prayer order: fajr, dhuhr, asr, maghrib, isha.

### 3.7 Incrementing a segment — `incrementSegment(wirdID, partID, occasionKey, segmentID, target)`
1. Resolve wird + part; if missing return 0.
2. `cappedTarget = max(target, 1)`.
3. Upsert the session for (wird, part, occasionKey, **todayKey**):
   - existing: `newCount = min(current + 1, cappedTarget)`; store; set `lastSegmentID`; refresh completion.
   - new: `newCount = min(1, cappedTarget)`; create session with that single progress entry + `lastSegmentID`; compute `isComplete`; set `completedAt` if complete.
4. Persist. Return `newCount`.

**Counting is capped at target** — you cannot exceed `effectiveTarget` per segment.

`refreshCompletion`: recompute `isComplete`; set `completedAt = now` when it flips complete
(and only if not already set); clear `completedAt` when it flips incomplete.

### 3.8 Reading position — `updateWirdReadingPosition(...)`
Upsert session, set `lastSegmentID` (used to resume the reader). No-op if unchanged.

### 3.9 Reset — `resetSession(wirdID, partID, occasionKey)`
Remove the session for that tuple + today's dateKey (the "Read again" action).

### 3.10 Streak — `streak(wird, sessions, todayKey)`
Consecutive **scheduled** days (walking back from today) on which **every active part was
completed**. Algorithm:
1. Build set of completed `(partID|dateKey)` pairs for this wird (sessions where `isComplete`).
2. A day is "satisfied" if it has active parts AND every active part for that day is in the set.
3. Walk back from today (cap 800 iterations):
   - Skip days where the wird is not active (don't count, don't break).
   - On an active day: if satisfied → `streak += 1`; else if it's **today** → don't count, don't break (today pending is OK); else → **break**.
4. Return streak.

`todayKey` / all dateKeys: `yyyy-MM-dd`, gregorian, `en_US_POSIX` locale.

---

## 4. Persistence & seeding

### 4.1 Snapshot
Everything persists in a single JSON snapshot (current `schemaVersion = 4`) containing:
`dhikrs, goals, countEntries, wirds, wirdSessions, preferences`. On Android, model these
as separate Room tables but keep the same import/export JSON shape if backup interop matters.

### 4.2 Seeding library wirds
- Library wirds are loaded from bundled JSON files (`Resources/Wirds/*.json`). On Android,
  bundle the same JSON in `assets/`.
- Merge rule (`mergedWirds`):
  - Custom wirds (`isCustom`) are **never** matched or replaced — carried through untouched.
  - For each seed: if a non-custom persisted wird with the same `slug` exists, replace it
    **only if `seed.version > persisted.version`**, preserving the persisted `id` and `sortOrder`.
  - If no wird with that slug exists, append the seed.

### 4.3 CRUD rules
- `createWird`: force `isCustom = true`; generate slug if empty; assign `sortOrder = max+1` if 0.
- `updateWird`: only matches **custom** wirds; preserves `version`.
- `deleteWird`: only deletes **custom** wirds; also deletes all that wird's sessions; cancels its reminders.

### 4.4 Bundled JSON schema (asset format)
The on-disk JSON uses **UPPER_SNAKE_CASE** discriminators (distinct from the in-memory
lowercase enum raw values). Reuse this exact format so the same asset files work on both
platforms.

Top level: `slug, version, sortOrder, name{}, description{}, author, sourceAttribution,
tags[], estimatedMinutes, schedule{}, parts[]`.

```jsonc
// schedule
{
  "cadence": "EVERY_DAY | ROTATION | DAYS_OF_WEEK | INTERVAL",
  "daysOfWeek": [2, 5],            // DAYS_OF_WEEK; Sun=1..Sat=7
  "intervalDays": 2,               // INTERVAL
  "intervalAnchor": "2024-01-01",  // INTERVAL anchor (yyyy-MM-dd)
  "hijriAnchor": "RAMADAN | LAST_TEN_NIGHTS | HIJRI_MONTH:9 | HIJRI_DATE:9:27",
  "defaultOccasion": { "type": "ANYTIME" }
}

// occasion (schedule.defaultOccasion and part.occasion)
{ "type": "ANYTIME | AFTER_PRAYER | MORNING | EVENING | BEFORE_SLEEP | TIME_WINDOW",
  "prayer": "fajr|dhuhr|asr|maghrib|isha",  // AFTER_PRAYER
  "startMinute": 300, "endMinute": 420 }    // TIME_WINDOW (minutes from midnight)

// part
{ "title": {"en":"…","ar":"…"}, "subtitle": {"en":"…"},
  "occasion": { "type": "MORNING" },        // optional, overrides default
  "blockRepeat": 1,
  "segments": [ /* Segment */ ] }

// segment
{ "kind": "dhikr|dua|salah|quran|heading|instruction",
  "arabic": "…",
  "transliteration": {"en":"…"}, "translation": {"en":"…"},
  "text": {"en":"…"},                       // heading/instruction
  "repeat": { "count": 3 },                 // or { "min": 33, "max": 100 }
  "fadl": {"en":"virtue note"},
  "quran": { "surah": 2, "ayahStart": 255, "ayahEnd": 255 } }  // kind=quran
}
```

Defaults when fields absent: cadence→EVERY_DAY, occasion→ANYTIME, kind→dhikr,
blockRepeat→1 (min 1), repeat→count 1 (or `min` if only min given), version→1, sortOrder→0.

> ⚠️ **Sacred text integrity:** never paraphrase, translate, or AI-generate Arabic text.
> Only ship wirds whose Arabic comes from an authenticated source.

---

## 5. UX / Screens & Flows

### 5.1 Wird List
- Two sections: **"Your wirds"** (custom, shown first if any) then **"Library"**.
- Each row = a card: cover image, name (localized), Arabic name, description (2 lines),
  and if a part is active today: a "Today" pill, the occasion label, completion pill,
  today's part title, a progress bar, and "X / Y" reading progress.
- `+` toolbar action → Create Wird.
- Long-press / context menu on a **custom** wird → Edit, Delete.

### 5.2 Wird Detail
- Header card: Arabic name, name, description, source/author, **streak** (flame), cadence
  label, today's active section with progress bar + **"Start Reading"** button.
- List of **all parts**, each a tappable row showing title, subtitle (or occasion label),
  "Today" badge if active today, completion badge, progress bar + "X / Y".
- Tapping a part (or "Start Reading") → Reader.
- For custom wirds: overflow menu → Edit / Delete.

### 5.3 Reader (the signature experience)
Full-screen, **one segment per page**, swipeable pager, cinematic dark green gradient
background (theme-independent — the reader is always dark/immersive). Per page:
- Top bar: close (X), part title, "page / total", a thin overall progress bar.
- Content (centered): for countable kinds — optional Qur'an pill or audio icon, large
  Arabic text (RTL), transliteration (gold), translation, italic fadl note. For
  heading/instruction — the heading text / info layout.
- Bottom control:
  - **Countable, target > 1:** a counter "count / target (or range)" + progress capsule +
    a **"Recite"** button. Each tap increments. Button reads "Recited" when done.
  - **Countable, target <= 1 (single):** no counter, just **"Mark as recited"** button.
  - **Non-countable (heading/instruction):** a **"Continue"** button.

Reader behavior:
- **Resume:** on open, jump to the first not-yet-complete countable segment; if all done,
  land on the last page.
- **Auto-advance:** when a tap brings a segment from `< target` to `>= target`, play a
  success haptic and after ~0.45s auto-advance to the next page. Otherwise play a light tap
  haptic. Respect a `vibrateOnCount` preference.
- Swiping pages updates `lastSegmentID` (reading position).
- Finishing the **last** segment reveals a **Completion screen**: checkmark seal,
  "Section Complete", wird name, current streak chip, **"Done"** and **"Read again"**
  (which calls resetSession and restarts at page 0).
- Counting is capped at target (no over-counting).

### 5.4 Create / Edit Wird (custom only)
A form with sections:
1. **Details:** Name (EN), Name (AR, RTL), Description, Source (book/compiler).
2. **Schedule:** Repeats picker (Every day / Rotating sections / Specific days / Every N
   days). If specific days → weekday toggle row (default Mon+Thu = {2,5}). If interval →
   stepper 1…60 (default 2). If rotation → explanatory note. Season picker (All year /
   Ramadan only / Last ten nights). Default-time occasion picker.
3. **Sections (parts):** list with add/reorder/delete; each navigates to a **Part editor**.
4. **Reminders:** list with add/delete; each row toggles enabled, type (Fixed time /
   After prayer), time picker or prayer+offset stepper (0…120 step 5).
5. **Save** button (disabled until valid).

**Validation (`canSave`):** name (EN) non-empty AND at least one part has at least one
countable segment with non-empty Arabic.

**Part editor:** title (EN/AR/subtitle); timing toggle "Custom time for this section"
(when on, occasion picker); block-repeat stepper 1…20; items list (add/reorder/delete);
"Type a new item" (blank dhikr segment) and "Add from library" (dhikr picker — copies the
library dhikr's text into a new segment, `kind = salah` if the dhikr category is
`swalaths`, else `dhikr`, with `sourceDhikrID` set).

**Segment editor:** kind picker; for countable kinds — Arabic (RTL), transliteration,
translation, benefit; repetitions (single count stepper 1…1000, or "Use a range" → min
1…990 + max). For non-countable — heading/instruction text field.

**On save:** build the Wird, create or update via store, (re)schedule its reminders, then
navigate to its detail (replacing the editor in the back stack).

### 5.5 Reminders (notifications)
- Daily-repeating local notifications per enabled reminder.
- `fixedTime` → fires at hour:minute.
- `prayerOffset` → resolves to today's prayer time + offset minutes (fallback 07:00 when
  prayer times unavailable), then repeats daily at that clock time.
- Notification id pattern: `awrad.wird.<wirdID>.<reminderID>`. Title = wird name; body =
  "Time for <name>." Localized.
- Reschedule on create/update; cancel all (`awrad.wird.<wirdID>.` prefix) on delete.

### 5.6 Home & Widget integration
- Home shows daily wirds (sorted by `sortOrder`).
- Widget snapshot exposes: `wirdTitle` (today's part title or wird name), `wirdSubtitle`
  (wird name), `wirdDetail`, `wirdProgress` (today's aggregate progress), `wirdDeepLink`.
- Empty state when no wird: "Daily Wird" / "Add a wird collection" → deep link to wird list.

### 5.7 Deep links
- `awrad://wirds` → wird list.
- `awrad://todays-wird` (alias `today-wird`) → today's wird.
- In-app routes also include: wird detail, wird reader `(wirdID, partID)`, create wird,
  edit wird.

---

## 6. Localization & RTL notes
- Three languages: `en`, `ar`, `ml`. Arabic content + Arabic UI = RTL layout.
- Arabic sacred text always renders RTL regardless of UI language.
- All wird/part/segment display text goes through the localized-map resolution rule (§2).
- Reading-progress string is a localized "completed / total" format; streak and "Every N
  days" are localized formats too.

---

## 7. Android implementation guidance (suggested, not prescriptive)
- **Persistence:** Room entities for `Wird`, `WirdPart`, `WirdSegment` (or store parts/
  segments as JSON columns to mirror the nested model — simpler and matches the snapshot),
  plus a `WirdSession` table keyed by `(wirdID, partID, occasionKey, dateKey)`. Keep UUID
  PKs stable across edits.
- **Sum types:** model `WirdCadence`, `HijriAnchor`, `WirdOccasion` as Kotlin sealed
  classes; serialize with `kotlinx.serialization` (a polymorphic/`type`-discriminated form)
  — but use the **UPPER_SNAKE_CASE asset JSON format** in §4.4 for bundled files so assets
  are shared.
- **Localized maps:** `Map<String, String>`; implement the resolution helper once.
- **Hijri:** use `UmmalquraCalendar` (ICU) or an Umm al-Qura library; match month/day gates.
- **Dates:** all dateKeys are `yyyy-MM-dd` in the **gregorian** calendar with a fixed POSIX
  locale — do not localize the key format.
- **Reader:** `HorizontalPager` (Compose) one-segment-per-page; replicate resume,
  auto-advance + haptics, target cap, and completion screen.
- **Reminders:** WorkManager/AlarmManager daily repeating; same id scheme so cancel-by-
  prefix works.
- **Styling:** native Material 3 — do not copy SwiftUI chrome; keep the *interaction model*.

---

## 8. Acceptance checklist (parity)
- [ ] Library wirds seed from shared JSON assets and version-merge correctly; custom wirds untouched.
- [ ] Create/edit/delete custom wirds; validation matches §5.4.
- [ ] Reader: resume point, per-tap counting capped at effectiveTarget (= repeat × blockRepeat), auto-advance + haptics, completion screen, "Read again" resets today's session.
- [ ] Progress + completion computed by stable segment IDs; editing a wird never corrupts past sessions.
- [ ] Cadence (everyDay/daysOfWeek/interval/rotation) + hijriAnchor gating produce identical "active today" results; rotation uses the 2001-01-01 reference.
- [ ] Occasion keys exactly match §2.3 (per-occasion sessions per day).
- [ ] Streak matches §3.10 (today-pending doesn't break; inactive days skipped).
- [ ] Reminders fire per type with the same id scheme; deleted wird cancels reminders.
- [ ] Deep links + widget/home summary reflect today's part + aggregate progress.
- [ ] Full en/ar/ml localization with correct RTL for Arabic.
</content>
</invoke>
