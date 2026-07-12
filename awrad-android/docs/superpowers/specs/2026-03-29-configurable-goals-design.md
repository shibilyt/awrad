# Configurable Goals System — Design Spec

## Problem

The current `GoalType` enum (DAILY, PRAYER_BASED, ONE_TIME, ADVANCED) is a flat list that doesn't compose. Adding weekly schedules, monthly schedules, Hijri calendar support, time-based slots, and minimum streak thresholds requires bolting fields onto the Goal table with no clear structure. The system needs a composable configuration model.

## Solution

Decompose goal configuration into 4 orthogonal axes, each independently selectable:

| Axis | Options | What it controls |
|------|---------|-----------------|
| **Frequency** | daily, weekly, monthly, interval, yearly, specific_dates | When the goal is due |
| **Timing** | anytime, prayer_based, time_based | When within the day to count |
| **Target** | none, fixed, custom | What to count toward |
| **Duration** | ongoing, fixed | How long the goal lasts |

Complex frequency rules (which days, which month, interval length, calendar system) are stored in a typed JSON config column using a sealed class with a discriminator field.

---

## Data Model

### 1. Goals Table

```
goals
├── id                  LONG PK AUTO
├── dhikrId             LONG FK → dhikrs
├── frequencyType       TEXT NOT NULL DEFAULT 'daily'
├── timingType          TEXT NOT NULL DEFAULT 'anytime'
├── targetType          TEXT NOT NULL DEFAULT 'fixed'
├── durationType        TEXT NOT NULL DEFAULT 'ongoing'
├── minimumCount        INTEGER          -- min count for streak (nullable)
├── configJson          TEXT             -- typed JSON config (nullable, null = daily)
├── startDate           TEXT NOT NULL
├── endDate             TEXT             -- for fixed duration (nullable)
├── durationDays        INTEGER          -- alternative to endDate (nullable)
├── totalCompletedCount LONG DEFAULT 0
├── isActive            BOOLEAN DEFAULT 1
├── isCompleted         BOOLEAN DEFAULT 0
├── createdAt           LONG
├── notificationEnabled BOOLEAN DEFAULT 0
├── notificationHour    INTEGER
├── notificationMinute  INTEGER
```

**Removed columns** (vs current schema):
- `goalType` — replaced by frequencyType + timingType + targetType + durationType
- `scheduleDays` — absorbed into configJson

**Kept as-is:**
- `durationDays`, `endDate` — used when durationType = "fixed"
- `totalCompletedCount`, `isActive`, `isCompleted`, `startDate`, `createdAt`
- Notification fields

### 2. Goal Slots Table

```
goal_slots
├── id              LONG PK AUTO
├── goalId          LONG FK → goals ON DELETE CASCADE
├── targetCount     INTEGER NOT NULL
├── timingType      TEXT NOT NULL       -- "anytime", "prayer", "time_window"
├── timingValue     TEXT                -- null for anytime, "after_fajr", "06:00-09:00"
├── label           TEXT                -- display name: "After Fajr", "Morning", etc.
├── sortOrder       INTEGER DEFAULT 0
```

**Changes from current `goal_slots`:**
- `slotKey` removed — replaced by `timingType` + `timingValue`
- `timingType` added — declares what kind of slot this is
- `timingValue` added — the specific value (prayer name, time range)
- `label` added — human-readable display name

### 3. Count Entries Table (unchanged)

```
count_entries
├── id              LONG PK AUTO
├── goalId          LONG FK → goals
├── slotId          LONG FK → goal_slots (nullable)
├── count           LONG DEFAULT 0
├── date            TEXT NOT NULL
├── lastUpdated     LONG
├── UNIQUE(goalId, date, slotId)
```

No changes. `slotId` still references `goal_slots.id`.

---

## Typed Config JSON

A sealed class with a `type` discriminator. Stored as JSON TEXT in the `configJson` column. `null` means daily (no config needed).

```kotlin
sealed class GoalConfig {
    abstract val type: String

    data class Weekly(
        val days: List<String>,                 // ["MON", "THU", "FRI"]
    ) : GoalConfig() {
        override val type = "weekly"
    }

    data class Monthly(
        val daysOfMonth: List<Int>,             // [1, 13, 14, 15]
        val calendar: String = "gregorian",     // "gregorian" or "hijri"
    ) : GoalConfig() {
        override val type = "monthly"
    }

    data class Interval(
        val intervalDays: Int,                  // 3
    ) : GoalConfig() {
        override val type = "interval"
    }

    data class Yearly(
        val month: Int,                         // 1-12
        val days: List<Int>,                    // [1, 2, 3, ..., 10]
        val calendar: String = "gregorian",     // "gregorian" or "hijri"
    ) : GoalConfig() {
        override val type = "yearly"
    }
}
```

### Config Examples

| Goal | frequencyType | configJson |
|------|--------------|------------|
| Every day | daily | null |
| Mon & Thu | weekly | `{"type":"weekly","days":["MON","THU"]}` |
| White days (Hijri) | monthly | `{"type":"monthly","daysOfMonth":[13,14,15],"calendar":"hijri"}` |
| 1st of each month | monthly | `{"type":"monthly","daysOfMonth":[1],"calendar":"gregorian"}` |
| Every 3 days | interval | `{"type":"interval","intervalDays":3}` |
| Dhul Hijjah 1-10 | yearly | `{"type":"yearly","month":12,"days":[1,2,3,4,5,6,7,8,9,10],"calendar":"hijri"}` |
| Ramadan last 10 | yearly | `{"type":"yearly","month":9,"days":[21,22,23,24,25,26,27,28,29,30],"calendar":"hijri"}` |
| Specific dates | specific_dates | `{"type":"yearly","month":7,"days":[1,4,15],"calendar":"gregorian"}` |

### TypeConverter

Room TypeConverter handles serialization. Reads the `type` field first to determine which subclass to deserialize into. Uses Gson or kotlinx.serialization.

---

## Slot Creation Per Goal Configuration

### target=fixed, timing=anytime (most goals)

One slot:

| targetCount | timingType | timingValue | label |
|------------|------------|-------------|-------|
| 100 | anytime | null | null |

### target=custom, timing=prayer_based

One slot per selected prayer:

| targetCount | timingType | timingValue | label |
|------------|------------|-------------|-------|
| 10 | prayer | after_fajr | After Fajr |
| 33 | prayer | after_dhuhr | After Dhuhr |
| 100 | prayer | after_maghrib | After Maghrib |

### target=custom, timing=time_based

One slot per time window:

| targetCount | timingType | timingValue | label |
|------------|------------|-------------|-------|
| 50 | time_window | 06:00-09:00 | Morning |
| 50 | time_window | 18:00-21:00 | Evening |

### target=none (tracker)

Zero slots. No rows in goal_slots.

---

## isDueToday() Logic

```
isDueToday(goal, date):
    if not active or completed → false
    if before startDate → false
    if durationType=fixed and past endDate/durationDays → false

    match goal.frequencyType:
        "daily"          → true
        "weekly"         → date.dayOfWeek.name.take(3) in config.days
        "monthly"        → if config.calendar == "hijri":
                               hijriDate(date).dayOfMonth in config.daysOfMonth
                           else:
                               date.dayOfMonth in config.daysOfMonth
        "interval"       → daysBetween(startDate, date) % config.intervalDays == 0
        "yearly"         → if config.calendar == "hijri":
                               hijriDate(date).month == config.month
                               AND hijriDate(date).day in config.days
                           else:
                               date.monthValue == config.month
                               AND date.dayOfMonth in config.days
        "specific_dates" → date.toString() in config.dates
```

---

## Streak Calculation

### Three-State Grid

Each day in the streak grid has one of three states:

| State | Condition | Color |
|-------|-----------|-------|
| COMPLETE | count >= threshold | Gold (full) |
| PARTIAL | 0 < count < threshold | Gold (45% alpha) |
| INACTIVE | count == 0 | Empty |

Where `threshold = goal.minimumCount ?: totalDailyTarget(goal)`.

### Streak Count

Walk backward from today. Skip days where `isDueToday() == false` (they don't break the streak). Count consecutive due days where `count >= threshold`.

---

## UI Presets and Create Goal Flow

### Step 1: Select Dhikr

Same as current — search and select a dhikr.

### Step 2: Configure Goal

#### Quick Presets (always visible as chips)

| Chip | Sets | Inline field |
|------|------|-------------|
| Daily | freq=daily, timing=anytime, target=fixed, duration=ongoing | `[___] per day` |
| Prayer-based | freq=daily, timing=prayer_based, target=custom, duration=ongoing | Prayer selector + counts |
| One-time | freq=daily, timing=anytime, target=fixed, duration=fixed | `[___] total` |
| Tracker | freq=daily, timing=anytime, target=none, duration=ongoing | (no target field) |

Target field is visible inline immediately (except Tracker).

#### Advanced Section (expandable)

Shown after tapping "Advanced" toggle/button. Contains template chips:

| Chip | Frequency details shown |
|------|------------------------|
| Daily | (none — same as quick but with extra options below) |
| Prayer-based | Prayer selector + counts |
| Weekly | Day-of-week picker (M T W T F S S) |
| Monthly (Gregorian) | Day-of-month picker (1-31) |
| Monthly (Hijri) | Day-of-month picker (1-30) |
| Every X days | Number input for interval |
| Yearly (Gregorian) | Month dropdown + day-of-month picker |
| Yearly (Hijri) | Hijri month dropdown + day picker |
| Specific dates | Calendar date picker (multi-select) |
| Tracker | (no target) |

After selecting any advanced template, the form shows:

1. **Timing chips:** Anytime | Prayer-based | Time-based
   - Prayer-based → prayer selector + per-prayer counts
   - Time-based → time window inputs + per-window counts
   - Anytime → single target count field
2. **Target count** (unless target=none)
3. **Minimum for streak** toggle + count input
4. **Duration** toggle (ongoing vs fixed days/date)
5. **Notification** toggle + time picker

#### Preset-to-Config Mapping

| Preset | frequencyType | timingType | targetType | durationType |
|--------|--------------|------------|------------|-------------|
| Daily (quick) | daily | anytime | fixed | ongoing |
| Prayer-based (quick) | daily | prayer_based | custom | ongoing |
| One-time (quick) | daily | anytime | fixed | fixed |
| Tracker (quick) | daily | anytime | none | ongoing |
| Daily (advanced) | daily | (user picks) | (user picks) | (user picks) |
| Prayer-based (advanced) | daily | prayer_based | custom | (user picks) |
| Weekly | weekly | (user picks) | (user picks) | (user picks) |
| Monthly (Gregorian) | monthly | (user picks) | (user picks) | (user picks) |
| Monthly (Hijri) | monthly | (user picks) | (user picks) | (user picks) |
| Every X days | interval | (user picks) | (user picks) | (user picks) |
| Yearly (Gregorian) | yearly | (user picks) | (user picks) | (user picks) |
| Yearly (Hijri) | yearly | (user picks) | (user picks) | (user picks) |
| Specific dates | specific_dates | (user picks) | (user picks) | fixed |
| Tracker (advanced) | (user picks) | anytime | none | (user picks) |

---

## Migration Path

### Room Migration (version 9 → 10)

**Goals table changes:**
1. Add columns: `frequencyType`, `timingType`, `targetType`, `durationType`, `minimumCount`, `configJson`
2. Populate from existing data:
   - `goalType=DAILY` → freq=daily, timing=anytime, target=fixed, duration=ongoing
   - `goalType=PRAYER_BASED` → freq=daily, timing=prayer_based, target=custom, duration=ongoing
   - `goalType=ONE_TIME` → freq=daily, timing=anytime, target=fixed, duration=fixed
   - `goalType=ADVANCED` → freq=daily, timing=anytime, target=fixed, duration=ongoing
   - If `scheduleDays` is non-null → freq=weekly, configJson=`{"type":"weekly","days":[...]}`
   - If `minimumStreakCount` is non-null → copy to `minimumCount`
3. Drop columns: `goalType`, `scheduleDays`, `minimumStreakCount` (via table rebuild)

**Goal slots table changes:**
1. Add columns: `timingType`, `timingValue`, `label`
2. Populate from existing `slotKey`:
   - `slotKey="anytime"` → timingType="anytime", timingValue=null, label=null
   - `slotKey="after_fajr"` → timingType="prayer", timingValue="after_fajr", label="After Fajr"
   - Same pattern for all prayer slot keys
3. Drop column: `slotKey` (via table rebuild)

### Kotlin Model Changes

- Remove `GoalType` enum
- Remove `scheduleDays` and `minimumStreakCount` from Goal/GoalEntity
- Add `frequencyType`, `timingType`, `targetType`, `durationType`, `minimumCount`, `configJson` to Goal/GoalEntity
- Add `GoalConfig` sealed class with TypeConverter
- Update `GoalSlot`/`GoalSlotEntity`: replace `slotKey` with `timingType`, `timingValue`, `label`
- Update `GoalProgressCalculator`: rewrite `isDueToday()`, `calculateStreak()`, `getFormattedTarget()`
- Update `CreateGoalViewModel`/`CreateGoalScreen`: new preset/template UI
- Update `CountingViewModel`/`CountingScreen`: use new slot model
- Update `GoalsViewModel`: use new config for display
- Update `HomeViewModel`: `isDueToday()` changes propagate automatically

### GoalType Removal

The `GoalType` enum is fully removed from the codebase. Anywhere that currently switches on `GoalType` switches on the relevant axis instead:

| Current code | New code |
|-------------|----------|
| `goal.goalType == GoalType.PRAYER_BASED` | `goal.timingType == "prayer_based"` |
| `goal.goalType == GoalType.ONE_TIME` | `goal.durationType == "fixed" && goal.durationDays == 1` |
| `goal.goalType == GoalType.DAILY` | `goal.frequencyType == "daily"` |
| `getFormattedTarget()` switch on GoalType | Switch on targetType + timingType |

---

## Scope Boundaries

**In scope:**
- New data model (goals table, goal_slots table, GoalConfig sealed class)
- Room migration
- isDueToday() rewrite
- Streak calculation (three-state, schedule-aware)
- Create goal UI (presets + advanced templates)
- Counting screen updates for new slot model
- Goals list display updates
- Hijri calendar support in isDueToday() (using existing HijrahDate)

**Out of scope:**
- Time-based slot enforcement (showing notifications at specific time windows) — slots are tracked but not auto-triggered
- Hijri calendar date picker UI (users enter day numbers, not a visual Hijri calendar)
- Recurring yearly goal auto-renewal (goals with yearly frequency are always active during their configured period)
