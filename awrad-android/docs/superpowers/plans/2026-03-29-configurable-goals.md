# Configurable Goals System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `GoalType` enum with a composable 4-axis goal configuration system (frequency, timing, target, duration), typed JSON config for schedule rules, generalized goal slots, and a new create-goal wizard with quick presets and advanced templates.

**Architecture:** New columns on goals table (frequencyType, timingType, targetType, durationType, minimumCount, configJson) with GoalConfig sealed class for typed JSON. GoalSlot gets timingType/timingValue/label replacing slotKey. Room migration rebuilds both tables. GoalProgressCalculator rewired to use new axes. CreateGoalScreen rebuilt with preset chips + advanced templates. All consuming screens updated.

**Tech Stack:** Room 2.6.1, Kotlin, Jetpack Compose, Hilt, Material3, Gson (for JSON serialization)

**Spec:** `docs/superpowers/specs/2026-03-29-configurable-goals-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `data/model/GoalConfig.kt` | Sealed class for typed JSON config |
| Create | `data/model/FrequencyType.kt` | Frequency enum |
| Create | `data/model/TimingType.kt` | Timing enum |
| Create | `data/model/TargetType.kt` | Target enum |
| Create | `data/model/DurationType.kt` | Duration enum |
| Create | `data/model/GoalPreset.kt` | UI preset enum with config mappings |
| Modify | `data/model/Goal.kt` | Replace goalType with 4 axes + configJson |
| Modify | `data/model/GoalSlot.kt` | Replace slotKey with timingType/timingValue/label |
| Delete | `data/model/GoalType.kt` | Removed — replaced by 4 axes |
| Modify | `data/database/entity/GoalEntity.kt` | New columns, remove goalType |
| Modify | `data/database/entity/GoalSlotEntity.kt` | New columns, remove slotKey |
| Modify | `data/database/Converters.kt` | Add GoalConfig TypeConverter, remove GoalType converter |
| Modify | `data/database/AwradDatabase.kt` | Bump version to 10 |
| Modify | `di/DatabaseModule.kt` | Migration 9→10 |
| Modify | `data/repository/GoalRepositoryImpl.kt` | Update toDomain/toEntity mappings |
| Modify | `util/GoalProgressCalculator.kt` | Rewrite isDueToday, getFormattedTarget |
| Modify | `ui/screens/goals/CreateGoalViewModel.kt` | New preset/template state + build logic |
| Modify | `ui/screens/goals/CreateGoalScreen.kt` | Preset chips + advanced templates UI |
| Modify | `ui/screens/goals/GoalsViewModel.kt` | Replace GoalType checks |
| Modify | `ui/screens/counting/CountingViewModel.kt` | Replace GoalType checks |
| Modify | `ui/screens/counting/CountingScreen.kt` | Replace slotKey display |
| Modify | `ui/screens/home/HomeViewModel.kt` | Replace GoalType checks |
| Modify | `res/values/strings.xml` | New string resources |
| Modify | `res/values-ar/strings.xml` | Arabic translations |
| Modify | `res/values-ml/strings.xml` | Malayalam translations |

---

### Task 1: Create enums and GoalConfig sealed class

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/FrequencyType.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/TimingType.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/TargetType.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/DurationType.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalConfig.kt`

- [ ] **Step 1: Create FrequencyType enum**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

enum class FrequencyType {
    DAILY, WEEKLY, MONTHLY, INTERVAL, YEARLY, SPECIFIC_DATES
}
```

- [ ] **Step 2: Create TimingType enum**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

enum class TimingType {
    ANYTIME, PRAYER_BASED, TIME_BASED
}
```

- [ ] **Step 3: Create TargetType enum**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

enum class TargetType {
    NONE, FIXED, CUSTOM
}
```

- [ ] **Step 4: Create DurationType enum**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

enum class DurationType {
    ONGOING, FIXED
}
```

- [ ] **Step 5: Create GoalConfig sealed class**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

sealed class GoalConfig {
    abstract val type: String

    data class Weekly(
        val days: List<String>,
    ) : GoalConfig() {
        override val type = "weekly"
    }

    data class Monthly(
        val daysOfMonth: List<Int>,
        val calendar: String = "gregorian",
    ) : GoalConfig() {
        override val type = "monthly"
    }

    data class Interval(
        val intervalDays: Int,
    ) : GoalConfig() {
        override val type = "interval"
    }

    data class Yearly(
        val month: Int,
        val days: List<Int>,
        val calendar: String = "gregorian",
    ) : GoalConfig() {
        override val type = "yearly"
    }
}
```

- [ ] **Step 6: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS (new files, no dependencies yet)

- [ ] **Step 7: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/FrequencyType.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/TimingType.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/TargetType.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/DurationType.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalConfig.kt
git commit -m "feat: add goal configuration enums and GoalConfig sealed class"
```

---

### Task 2: Create GoalPreset enum

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalPreset.kt`

- [ ] **Step 1: Create GoalPreset enum with config mappings**

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

enum class GoalPreset {
    // Quick presets
    DAILY,
    PRAYER_BASED,
    ONE_TIME,
    TRACKER,
    // Advanced templates
    ADV_DAILY,
    ADV_PRAYER_BASED,
    ADV_WEEKLY,
    ADV_MONTHLY_GREGORIAN,
    ADV_MONTHLY_HIJRI,
    ADV_INTERVAL,
    ADV_YEARLY_GREGORIAN,
    ADV_YEARLY_HIJRI,
    ADV_SPECIFIC_DATES,
    ADV_TRACKER;

    val isQuickPreset: Boolean
        get() = this in listOf(DAILY, PRAYER_BASED, ONE_TIME, TRACKER)

    val frequencyType: FrequencyType
        get() = when (this) {
            DAILY, PRAYER_BASED, ONE_TIME, TRACKER -> FrequencyType.DAILY
            ADV_DAILY, ADV_PRAYER_BASED -> FrequencyType.DAILY
            ADV_WEEKLY -> FrequencyType.WEEKLY
            ADV_MONTHLY_GREGORIAN, ADV_MONTHLY_HIJRI -> FrequencyType.MONTHLY
            ADV_INTERVAL -> FrequencyType.INTERVAL
            ADV_YEARLY_GREGORIAN, ADV_YEARLY_HIJRI -> FrequencyType.YEARLY
            ADV_SPECIFIC_DATES -> FrequencyType.SPECIFIC_DATES
            ADV_TRACKER -> FrequencyType.DAILY
        }

    val defaultTimingType: TimingType
        get() = when (this) {
            PRAYER_BASED, ADV_PRAYER_BASED -> TimingType.PRAYER_BASED
            else -> TimingType.ANYTIME
        }

    val defaultTargetType: TargetType
        get() = when (this) {
            TRACKER, ADV_TRACKER -> TargetType.NONE
            PRAYER_BASED, ADV_PRAYER_BASED -> TargetType.CUSTOM
            else -> TargetType.FIXED
        }

    val defaultDurationType: DurationType
        get() = when (this) {
            ONE_TIME -> DurationType.FIXED
            else -> DurationType.ONGOING
        }

    val showTimingPicker: Boolean
        get() = !isQuickPreset && this != ADV_TRACKER

    val showTargetField: Boolean
        get() = this != TRACKER && this != ADV_TRACKER
}
```

- [ ] **Step 2: Compile and commit**

Run: `./gradlew compileDebugKotlin`

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalPreset.kt
git commit -m "feat: add GoalPreset enum with config mappings"
```

---

### Task 3: Update GoalSlot and GoalSlotEntity

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalSlot.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalSlotEntity.kt`

- [ ] **Step 1: Update GoalSlot domain model**

Replace the entire file:

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

data class GoalSlot(
    val id: Long = 0,
    val goalId: Long,
    val targetCount: Int,
    val timingType: String = "anytime",    // "anytime", "prayer", "time_window"
    val timingValue: String? = null,       // null, "after_fajr", "06:00-09:00"
    val label: String? = null,             // "After Fajr", "Morning"
    val sortOrder: Int = 0,
)

object SlotTimingTypes {
    const val ANYTIME = "anytime"
    const val PRAYER = "prayer"
    const val TIME_WINDOW = "time_window"
}

object PrayerTimingValues {
    const val BEFORE_FAJR = "before_fajr"
    const val AFTER_FAJR = "after_fajr"
    const val BEFORE_DHUHR = "before_dhuhr"
    const val AFTER_DHUHR = "after_dhuhr"
    const val BEFORE_ASR = "before_asr"
    const val AFTER_ASR = "after_asr"
    const val BEFORE_MAGHRIB = "before_maghrib"
    const val AFTER_MAGHRIB = "after_maghrib"
    const val BEFORE_ISHA = "before_isha"
    const val AFTER_ISHA = "after_isha"
}
```

- [ ] **Step 2: Update GoalSlotEntity**

Replace the entity:

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "goal_slots",
    foreignKeys = [
        ForeignKey(
            entity = GoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("goalId")]
)
data class GoalSlotEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val goalId: Long,
    val targetCount: Int,
    val timingType: String = "anytime",
    val timingValue: String? = null,
    val label: String? = null,
    val sortOrder: Int = 0,
)
```

- [ ] **Step 3: Compile — expect failures**

Run: `./gradlew compileDebugKotlin`
Expected: FAIL — code still references `slotKey` and `SlotKeys`. These will be fixed in later tasks.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalSlot.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalSlotEntity.kt
git commit -m "feat: replace slotKey with timingType/timingValue/label in GoalSlot"
```

---

### Task 4: Update Goal and GoalEntity

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/Goal.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalEntity.kt`
- Delete: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalType.kt`

- [ ] **Step 1: Update Goal domain model**

Replace the entire file:

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.model

import java.time.LocalDate

data class Goal(
    val id: Long = 0,
    val dhikrId: Long,
    val dhikr: Dhikr? = null,
    val frequencyType: FrequencyType = FrequencyType.DAILY,
    val timingType: TimingType = TimingType.ANYTIME,
    val targetType: TargetType = TargetType.FIXED,
    val durationType: DurationType = DurationType.ONGOING,
    val minimumCount: Int? = null,
    val config: GoalConfig? = null,
    val slots: List<GoalSlot> = emptyList(),
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val durationDays: Int? = null,
    val totalCompletedCount: Long = 0,
    val isActive: Boolean = true,
    val isCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val notificationEnabled: Boolean = false,
    val notificationHour: Int? = null,
    val notificationMinute: Int? = null,
) {
    val isPrayerBased: Boolean get() = timingType == TimingType.PRAYER_BASED
    val isOneTime: Boolean get() = durationType == DurationType.FIXED && durationDays == 1
    val isTracker: Boolean get() = targetType == TargetType.NONE
}
```

- [ ] **Step 2: Update GoalEntity**

Replace the entire file:

```kotlin
package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import app.awrad.awrad_dhikrgoalstracker.data.model.DurationType
import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalConfig
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetType
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import java.time.LocalDate

@Entity(
    tableName = "goals",
    foreignKeys = [
        ForeignKey(
            entity = DhikrEntity::class,
            parentColumns = ["id"],
            childColumns = ["dhikrId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("dhikrId")]
)
data class GoalEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val dhikrId: Long,
    val frequencyType: FrequencyType = FrequencyType.DAILY,
    val timingType: TimingType = TimingType.ANYTIME,
    val targetType: TargetType = TargetType.FIXED,
    val durationType: DurationType = DurationType.ONGOING,
    val minimumCount: Int? = null,
    val configJson: GoalConfig? = null,
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val durationDays: Int? = null,
    val totalCompletedCount: Long = 0,
    val isActive: Boolean = true,
    val isCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val notificationEnabled: Boolean = false,
    val notificationHour: Int? = null,
    val notificationMinute: Int? = null,
)
```

- [ ] **Step 3: Delete GoalType.kt**

```bash
rm app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalType.kt
```

- [ ] **Step 4: Commit (will not compile yet)**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/Goal.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalEntity.kt
git rm app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/GoalType.kt
git commit -m "feat: replace GoalType with 4-axis config on Goal and GoalEntity"
```

---

### Task 5: Update Converters and TypeConverter for GoalConfig

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/Converters.kt`

- [ ] **Step 1: Read the current Converters file**

Read the file to understand existing converters and imports.

- [ ] **Step 2: Replace GoalType converters with new enum + GoalConfig converters**

Remove the `fromGoalType`/`toGoalType` converters. Add converters for the 4 new enums and GoalConfig:

```kotlin
// FrequencyType
@TypeConverter fun fromFrequencyType(value: FrequencyType): String = value.name
@TypeConverter fun toFrequencyType(value: String): FrequencyType = FrequencyType.valueOf(value)

// TimingType
@TypeConverter fun fromTimingType(value: TimingType): String = value.name
@TypeConverter fun toTimingType(value: String): TimingType = TimingType.valueOf(value)

// TargetType
@TypeConverter fun fromTargetType(value: TargetType): String = value.name
@TypeConverter fun toTargetType(value: String): TargetType = TargetType.valueOf(value)

// DurationType
@TypeConverter fun fromDurationType(value: DurationType): String = value.name
@TypeConverter fun toDurationType(value: String): DurationType = DurationType.valueOf(value)

// GoalConfig (JSON)
@TypeConverter
fun fromGoalConfig(config: GoalConfig?): String? {
    if (config == null) return null
    val obj = JsonObject()
    obj.addProperty("type", config.type)
    when (config) {
        is GoalConfig.Weekly -> {
            val arr = JsonArray(); config.days.forEach { arr.add(it) }
            obj.add("days", arr)
        }
        is GoalConfig.Monthly -> {
            val arr = JsonArray(); config.daysOfMonth.forEach { arr.add(it) }
            obj.add("daysOfMonth", arr)
            obj.addProperty("calendar", config.calendar)
        }
        is GoalConfig.Interval -> {
            obj.addProperty("intervalDays", config.intervalDays)
        }
        is GoalConfig.Yearly -> {
            obj.addProperty("month", config.month)
            val arr = JsonArray(); config.days.forEach { arr.add(it) }
            obj.add("days", arr)
            obj.addProperty("calendar", config.calendar)
        }
    }
    return obj.toString()
}

@TypeConverter
fun toGoalConfig(json: String?): GoalConfig? {
    if (json == null) return null
    val obj = JsonParser.parseString(json).asJsonObject
    return when (obj.get("type").asString) {
        "weekly" -> GoalConfig.Weekly(
            days = obj.getAsJsonArray("days").map { it.asString },
        )
        "monthly" -> GoalConfig.Monthly(
            daysOfMonth = obj.getAsJsonArray("daysOfMonth").map { it.asInt },
            calendar = obj.get("calendar")?.asString ?: "gregorian",
        )
        "interval" -> GoalConfig.Interval(
            intervalDays = obj.get("intervalDays").asInt,
        )
        "yearly" -> GoalConfig.Yearly(
            month = obj.get("month").asInt,
            days = obj.getAsJsonArray("days").map { it.asInt },
            calendar = obj.get("calendar")?.asString ?: "gregorian",
        )
        else -> null
    }
}
```

Add imports for `com.google.gson.JsonArray`, `com.google.gson.JsonObject`, `com.google.gson.JsonParser`, and the new model types.

- [ ] **Step 3: Compile — expect failures from other files**

Run: `./gradlew compileDebugKotlin`

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/Converters.kt
git commit -m "feat: add TypeConverters for new goal config enums and GoalConfig JSON"
```

---

### Task 6: Room migration 9→10

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/di/DatabaseModule.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AwradDatabase.kt`

- [ ] **Step 1: Add migration9To10 in DatabaseModule.kt**

This is a complex migration that rebuilds both tables. Add after `migration8To9`:

```kotlin
val migration9To10 = object : Migration(9, 10) {
    override fun migrate(db: SupportSQLiteDatabase) {
        // === GOALS TABLE REBUILD ===
        db.execSQL("ALTER TABLE goals RENAME TO goals_old")

        db.execSQL("""
            CREATE TABLE IF NOT EXISTS goals (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                dhikrId INTEGER NOT NULL,
                frequencyType TEXT NOT NULL DEFAULT 'DAILY',
                timingType TEXT NOT NULL DEFAULT 'ANYTIME',
                targetType TEXT NOT NULL DEFAULT 'FIXED',
                durationType TEXT NOT NULL DEFAULT 'ONGOING',
                minimumCount INTEGER,
                configJson TEXT,
                startDate TEXT NOT NULL,
                endDate TEXT,
                durationDays INTEGER,
                totalCompletedCount INTEGER NOT NULL DEFAULT 0,
                isActive INTEGER NOT NULL DEFAULT 1,
                isCompleted INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                notificationEnabled INTEGER NOT NULL DEFAULT 0,
                notificationHour INTEGER,
                notificationMinute INTEGER,
                FOREIGN KEY(dhikrId) REFERENCES dhikrs(id) ON DELETE CASCADE
            )
        """.trimIndent())
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goals_dhikrId ON goals (dhikrId)")

        // Migrate data: map old goalType to new 4 axes
        // DAILY → freq=DAILY, timing=ANYTIME, target=FIXED, duration=ONGOING
        db.execSQL("""
            INSERT INTO goals (id, dhikrId, frequencyType, timingType, targetType, durationType,
                minimumCount, configJson, startDate, endDate, durationDays,
                totalCompletedCount, isActive, isCompleted, createdAt,
                notificationEnabled, notificationHour, notificationMinute)
            SELECT id, dhikrId,
                CASE
                    WHEN scheduleDays IS NOT NULL THEN 'WEEKLY'
                    ELSE 'DAILY'
                END,
                CASE goalType
                    WHEN 'PRAYER_BASED' THEN 'PRAYER_BASED'
                    ELSE 'ANYTIME'
                END,
                CASE goalType
                    WHEN 'PRAYER_BASED' THEN 'CUSTOM'
                    ELSE 'FIXED'
                END,
                CASE goalType
                    WHEN 'ONE_TIME' THEN 'FIXED'
                    ELSE 'ONGOING'
                END,
                minimumStreakCount,
                CASE
                    WHEN scheduleDays IS NOT NULL THEN
                        '{"type":"weekly","days":["' || REPLACE(scheduleDays, ',', '","') || '"]}'
                    ELSE NULL
                END,
                startDate, endDate, durationDays,
                totalCompletedCount, isActive, isCompleted, createdAt,
                notificationEnabled, notificationHour, notificationMinute
            FROM goals_old
        """.trimIndent())

        db.execSQL("DROP TABLE goals_old")

        // === GOAL_SLOTS TABLE REBUILD ===
        db.execSQL("ALTER TABLE goal_slots RENAME TO goal_slots_old")

        db.execSQL("""
            CREATE TABLE IF NOT EXISTS goal_slots (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                goalId INTEGER NOT NULL,
                targetCount INTEGER NOT NULL,
                timingType TEXT NOT NULL DEFAULT 'anytime',
                timingValue TEXT,
                label TEXT,
                sortOrder INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(goalId) REFERENCES goals(id) ON DELETE CASCADE
            )
        """.trimIndent())
        db.execSQL("CREATE INDEX IF NOT EXISTS index_goal_slots_goalId ON goal_slots (goalId)")

        // Migrate slots: map slotKey to timingType + timingValue + label
        db.execSQL("""
            INSERT INTO goal_slots (id, goalId, targetCount, timingType, timingValue, label, sortOrder)
            SELECT id, goalId, targetCount,
                CASE
                    WHEN slotKey = 'anytime' THEN 'anytime'
                    ELSE 'prayer'
                END,
                CASE
                    WHEN slotKey = 'anytime' THEN NULL
                    ELSE slotKey
                END,
                CASE
                    WHEN slotKey = 'anytime' THEN NULL
                    WHEN slotKey = 'before_fajr' THEN 'Before Fajr'
                    WHEN slotKey = 'after_fajr' THEN 'After Fajr'
                    WHEN slotKey = 'before_dhuhr' THEN 'Before Dhuhr'
                    WHEN slotKey = 'after_dhuhr' THEN 'After Dhuhr'
                    WHEN slotKey = 'before_asr' THEN 'Before Asr'
                    WHEN slotKey = 'after_asr' THEN 'After Asr'
                    WHEN slotKey = 'before_maghrib' THEN 'Before Maghrib'
                    WHEN slotKey = 'after_maghrib' THEN 'After Maghrib'
                    WHEN slotKey = 'before_isha' THEN 'Before Isha'
                    WHEN slotKey = 'after_isha' THEN 'After Isha'
                    ELSE slotKey
                END,
                sortOrder
            FROM goal_slots_old
        """.trimIndent())

        db.execSQL("DROP TABLE goal_slots_old")
    }
}
```

- [ ] **Step 2: Register migration and bump version**

Add `migration9To10` to the `addMigrations()` call.

In `AwradDatabase.kt`, change `version = 9` to `version = 10`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/di/DatabaseModule.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AwradDatabase.kt
git commit -m "feat: Room migration 9→10 — rebuild goals and goal_slots tables"
```

---

### Task 7: Update repository mapping

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt`

- [ ] **Step 1: Read the current file to find toDomain/toEntity functions**

- [ ] **Step 2: Update GoalEntity.toDomain()**

```kotlin
private fun GoalEntity.toDomain(dhikr: Dhikr? = null, slots: List<GoalSlot> = emptyList()) = Goal(
    id = id,
    dhikrId = dhikrId,
    dhikr = dhikr,
    frequencyType = frequencyType,
    timingType = timingType,
    targetType = targetType,
    durationType = durationType,
    minimumCount = minimumCount,
    config = configJson,
    slots = slots,
    startDate = startDate,
    endDate = endDate,
    durationDays = durationDays,
    totalCompletedCount = totalCompletedCount,
    isActive = isActive,
    isCompleted = isCompleted,
    createdAt = createdAt,
    notificationEnabled = notificationEnabled,
    notificationHour = notificationHour,
    notificationMinute = notificationMinute,
)
```

- [ ] **Step 3: Update Goal.toEntity()**

```kotlin
private fun Goal.toEntity() = GoalEntity(
    id = id,
    dhikrId = dhikrId,
    frequencyType = frequencyType,
    timingType = timingType,
    targetType = targetType,
    durationType = durationType,
    minimumCount = minimumCount,
    configJson = config,
    startDate = startDate,
    endDate = endDate,
    durationDays = durationDays,
    totalCompletedCount = totalCompletedCount,
    isActive = isActive,
    isCompleted = isCompleted,
    createdAt = createdAt,
    notificationEnabled = notificationEnabled,
    notificationHour = notificationHour,
    notificationMinute = notificationMinute,
)
```

- [ ] **Step 4: Update GoalSlotEntity.toDomain()**

```kotlin
private fun GoalSlotEntity.toDomain() = GoalSlot(
    id = id,
    goalId = goalId,
    targetCount = targetCount,
    timingType = timingType,
    timingValue = timingValue,
    label = label,
    sortOrder = sortOrder,
)
```

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt
git commit -m "feat: update repository mappings for new goal config model"
```

---

### Task 8: Rewrite GoalProgressCalculator

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/util/GoalProgressCalculator.kt`

- [ ] **Step 1: Read the current file**

- [ ] **Step 2: Rewrite isDueToday()**

Replace the existing function. The new version checks `frequencyType` and `config` instead of `GoalType` and `scheduleDays`:

```kotlin
fun isDueToday(goal: Goal, date: LocalDate = LocalDate.now()): Boolean {
    if (!goal.isActive || goal.isCompleted) return false
    if (date.isBefore(goal.startDate)) return false
    goal.endDate?.let { if (date.isAfter(it)) return false }
    goal.durationDays?.let {
        val daysSinceStart = ChronoUnit.DAYS.between(goal.startDate, date)
        if (daysSinceStart >= it) return false
    }

    return when (goal.frequencyType) {
        FrequencyType.DAILY -> true
        FrequencyType.WEEKLY -> {
            val config = goal.config as? GoalConfig.Weekly ?: return true
            val dayName = date.dayOfWeek.name.take(3)
            dayName in config.days.map { it.uppercase() }
        }
        FrequencyType.MONTHLY -> {
            val config = goal.config as? GoalConfig.Monthly ?: return true
            if (config.calendar == "hijri") {
                val hijri = java.time.chrono.HijrahDate.from(date)
                hijri.get(java.time.temporal.ChronoField.DAY_OF_MONTH) in config.daysOfMonth
            } else {
                date.dayOfMonth in config.daysOfMonth
            }
        }
        FrequencyType.INTERVAL -> {
            val config = goal.config as? GoalConfig.Interval ?: return true
            val daysSinceStart = ChronoUnit.DAYS.between(goal.startDate, date)
            daysSinceStart % config.intervalDays == 0L
        }
        FrequencyType.YEARLY -> {
            val config = goal.config as? GoalConfig.Yearly ?: return true
            if (config.calendar == "hijri") {
                val hijri = java.time.chrono.HijrahDate.from(date)
                val hijriMonth = hijri.get(java.time.temporal.ChronoField.MONTH_OF_YEAR)
                val hijriDay = hijri.get(java.time.temporal.ChronoField.DAY_OF_MONTH)
                hijriMonth == config.month && hijriDay in config.days
            } else {
                date.monthValue == config.month && date.dayOfMonth in config.days
            }
        }
        FrequencyType.SPECIFIC_DATES -> {
            // Specific dates stored in Yearly config with calendar field
            val config = goal.config as? GoalConfig.Yearly ?: return false
            date.monthValue == config.month && date.dayOfMonth in config.days
        }
    }
}
```

- [ ] **Step 3: Rewrite getFormattedTarget()**

```kotlin
fun getFormattedTarget(goal: Goal): String {
    if (goal.targetType == TargetType.NONE) return "Tracker"

    val totalTarget = goal.slots.sumOf { it.targetCount }
    val suffix = when (goal.frequencyType) {
        FrequencyType.DAILY -> "/day"
        FrequencyType.WEEKLY -> "/week"
        FrequencyType.MONTHLY -> "/month"
        FrequencyType.INTERVAL -> {
            val interval = (goal.config as? GoalConfig.Interval)?.intervalDays ?: 1
            "/every ${interval}d"
        }
        FrequencyType.YEARLY -> "/year"
        FrequencyType.SPECIFIC_DATES -> " total"
    }

    return when (goal.timingType) {
        TimingType.PRAYER_BASED -> {
            val slotCount = goal.slots.size
            "$slotCount prayers · $totalTarget total"
        }
        TimingType.TIME_BASED -> {
            val slotCount = goal.slots.size
            "$slotCount slots · $totalTarget total"
        }
        TimingType.ANYTIME -> {
            if (goal.isOneTime) "$totalTarget total"
            else "$totalTarget$suffix"
        }
    }
}
```

- [ ] **Step 4: Update calculateStreakWithCounts() — replace scheduleDays with GoalConfig**

```kotlin
fun calculateStreakWithCounts(
    dailyCounts: Map<LocalDate, Long>,
    today: LocalDate = LocalDate.now(),
    dailyTarget: Int = 0,
    minimumStreakCount: Int? = null,
    goal: Goal? = null,
): StreakInfo {
    val dateSet = dailyCounts.keys.toHashSet()
    val threshold = minimumStreakCount ?: dailyTarget

    var streak = 0
    var checkDate = if (dateSet.contains(today)) today else today.minusDays(1)
    while (true) {
        // Skip non-scheduled days using goal config
        if (goal != null && !isDueOnDate(goal, checkDate)) {
            checkDate = checkDate.minusDays(1)
            // Safety: don't walk back more than 366 days
            if (ChronoUnit.DAYS.between(checkDate, today) > 366) break
            continue
        }
        val count = dailyCounts[checkDate] ?: 0L
        if (count < threshold) break
        streak++
        checkDate = checkDate.minusDays(1)
    }

    return StreakInfo(
        currentStreak = streak,
        activeDates = dateSet,
        dailyCounts = dailyCounts,
        minimumStreakCount = threshold,
    )
}

// Helper that skips active/completed checks — just checks schedule
private fun isDueOnDate(goal: Goal, date: LocalDate): Boolean {
    if (date.isBefore(goal.startDate)) return false
    return when (goal.frequencyType) {
        FrequencyType.DAILY -> true
        FrequencyType.WEEKLY -> {
            val config = goal.config as? GoalConfig.Weekly ?: return true
            date.dayOfWeek.name.take(3) in config.days.map { it.uppercase() }
        }
        FrequencyType.MONTHLY -> {
            val config = goal.config as? GoalConfig.Monthly ?: return true
            if (config.calendar == "hijri") {
                val hijri = java.time.chrono.HijrahDate.from(date)
                hijri.get(java.time.temporal.ChronoField.DAY_OF_MONTH) in config.daysOfMonth
            } else {
                date.dayOfMonth in config.daysOfMonth
            }
        }
        FrequencyType.INTERVAL -> {
            val config = goal.config as? GoalConfig.Interval ?: return true
            ChronoUnit.DAYS.between(goal.startDate, date) % config.intervalDays == 0L
        }
        FrequencyType.YEARLY -> {
            val config = goal.config as? GoalConfig.Yearly ?: return true
            if (config.calendar == "hijri") {
                val hijri = java.time.chrono.HijrahDate.from(date)
                hijri.get(java.time.temporal.ChronoField.MONTH_OF_YEAR) == config.month &&
                    hijri.get(java.time.temporal.ChronoField.DAY_OF_MONTH) in config.days
            } else {
                date.monthValue == config.month && date.dayOfMonth in config.days
            }
        }
        FrequencyType.SPECIFIC_DATES -> {
            val config = goal.config as? GoalConfig.Yearly ?: return false
            date.monthValue == config.month && date.dayOfMonth in config.days
        }
    }
}
```

- [ ] **Step 5: Update imports**

Add:
```kotlin
import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalConfig
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetType
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
```

Remove:
```kotlin
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalType
```

- [ ] **Step 6: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/util/GoalProgressCalculator.kt
git commit -m "feat: rewrite GoalProgressCalculator for configurable goal axes"
```

---

### Task 9: Fix all GoalType references across ViewModels and screens

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/GoalsViewModel.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeViewModel.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/dhikrdetail/DhikrDetailViewModel.kt`

- [ ] **Step 1: Fix GoalsViewModel**

Find and replace all `GoalType` references. The key change is the ONE_TIME progress check:

Replace:
```kotlin
val progress = if (goal.goalType == GoalType.ONE_TIME) {
```
With:
```kotlin
val progress = if (goal.isOneTime) {
```

Remove `GoalType` import, add necessary model imports.

- [ ] **Step 2: Fix CountingViewModel**

Replace:
```kotlin
val isOneTime = goal.goalType == GoalType.ONE_TIME
```
With:
```kotlin
val isOneTime = goal.isOneTime
```

Replace:
```kotlin
val isPrayerBased = goal.goalType == GoalType.PRAYER_BASED
```
With:
```kotlin
val isPrayerBased = goal.isPrayerBased
```

Remove `GoalType` import.

- [ ] **Step 3: Fix CountingScreen — slot display**

Find `slotKeyToDisplayName()` function or anywhere `slot.slotKey` is used. Replace with `slot.label ?: slot.timingValue ?: ""`.

Search for `SlotKeys` references and replace:
- `slot.slotKey` → `slot.timingValue` or `slot.label`
- Any `slotKeyToDisplayName(slot.slotKey)` → `slot.label ?: slot.timingValue ?: ""`

- [ ] **Step 4: Fix HomeViewModel**

Remove `GoalType` import. The `isDueToday()` call is already via `GoalProgressCalculator` which was updated in Task 8.

- [ ] **Step 5: Fix DhikrDetailViewModel**

Search for any `GoalType` references and replace. Likely used in suggested goals display.

- [ ] **Step 6: Search for any remaining GoalType references**

Run: `grep -r "GoalType\|goalType\|goal_type\|slotKey\|SlotKeys" --include="*.kt" app/src/main/java/`

Fix any remaining references found.

- [ ] **Step 7: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix: replace all GoalType and slotKey references with new config model"
```

---

### Task 10: Update CreateGoalViewModel for presets and templates

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt`

- [ ] **Step 1: Read the current CreateGoalViewModel**

- [ ] **Step 2: Replace CreateGoalUiState**

Replace the state with preset-based fields:

```kotlin
data class CreateGoalUiState(
    // Wizard navigation
    val currentStep: CreateGoalStep = CreateGoalStep.SELECT_DHIKR,
    // Dhikr selection
    val allDhikrs: List<Dhikr> = emptyList(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val searchQuery: String = "",
    val selectedDhikr: Dhikr? = null,
    // Preset / template
    val selectedPreset: GoalPreset = GoalPreset.DAILY,
    val showAdvanced: Boolean = false,
    // Frequency config
    val selectedDays: Set<DayOfWeek> = emptySet(),         // for WEEKLY
    val selectedDaysOfMonth: Set<Int> = emptySet(),         // for MONTHLY
    val selectedMonth: Int = 1,                              // for YEARLY
    val selectedYearDays: Set<Int> = emptySet(),            // for YEARLY
    val intervalDays: String = "3",                          // for INTERVAL
    val calendarType: String = "gregorian",                  // for MONTHLY/YEARLY hijri variants
    // Timing
    val timingType: TimingType = TimingType.ANYTIME,
    // Prayer-based config
    val prayerTiming: PrayerTiming = PrayerTiming.AFTER,
    val selectedPrayers: Set<Prayer> = emptySet(),
    val uniformPrayerCount: Boolean = true,
    val uniformTargetCount: String = "33",
    val prayerCounts: Map<Prayer, String> = emptyMap(),
    // Time-based config
    val timeSlots: List<TimeSlotInput> = emptyList(),
    // Target
    val targetCount: String = "33",
    // Min streak
    val hasMinStreak: Boolean = false,
    val minStreakCount: String = "",
    // Duration
    val hasDuration: Boolean = false,
    val durationDays: String = "",
    // Notifications
    val notificationEnabled: Boolean = false,
    val notificationHour: Int = 8,
    val notificationMinute: Int = 0,
    // Status
    val isCreating: Boolean = false,
    val isCreated: Boolean = false,
    val isFormValid: Boolean = false,
)

data class TimeSlotInput(
    val label: String = "",
    val startTime: String = "",
    val endTime: String = "",
    val targetCount: String = "33",
)
```

- [ ] **Step 3: Add preset selection methods**

```kotlin
fun selectPreset(preset: GoalPreset) {
    _state.value = _state.value.copy(
        selectedPreset = preset,
        timingType = preset.defaultTimingType,
        showAdvanced = !preset.isQuickPreset,
    )
    updateFormValidity()
}

fun toggleAdvanced() {
    _state.value = _state.value.copy(showAdvanced = !_state.value.showAdvanced)
}

fun setTimingType(timing: TimingType) {
    _state.value = _state.value.copy(timingType = timing)
    updateFormValidity()
}

// Weekly day toggles
fun toggleWeekDay(day: DayOfWeek) {
    val current = _state.value.selectedDays.toMutableSet()
    if (day in current) current.remove(day) else current.add(day)
    _state.value = _state.value.copy(selectedDays = current)
    updateFormValidity()
}

// Monthly day toggles
fun toggleMonthDay(day: Int) {
    val current = _state.value.selectedDaysOfMonth.toMutableSet()
    if (day in current) current.remove(day) else current.add(day)
    _state.value = _state.value.copy(selectedDaysOfMonth = current)
    updateFormValidity()
}

// Yearly
fun setSelectedMonth(month: Int) {
    _state.value = _state.value.copy(selectedMonth = month)
    updateFormValidity()
}

fun toggleYearDay(day: Int) {
    val current = _state.value.selectedYearDays.toMutableSet()
    if (day in current) current.remove(day) else current.add(day)
    _state.value = _state.value.copy(selectedYearDays = current)
    updateFormValidity()
}

fun setIntervalDays(days: String) {
    _state.value = _state.value.copy(intervalDays = days)
    updateFormValidity()
}
```

- [ ] **Step 4: Rewrite buildSlots()**

```kotlin
private fun buildSlots(state: CreateGoalUiState): List<GoalSlot> {
    if (state.selectedPreset.defaultTargetType == TargetType.NONE &&
        state.timingType == TimingType.ANYTIME) {
        return emptyList() // Tracker — no slots
    }

    return when (state.timingType) {
        TimingType.ANYTIME -> {
            val count = state.targetCount.toIntOrNull() ?: 33
            listOf(GoalSlot(goalId = 0, targetCount = count, timingType = SlotTimingTypes.ANYTIME))
        }
        TimingType.PRAYER_BASED -> buildPrayerSlots(state)
        TimingType.TIME_BASED -> buildTimeSlots(state)
    }
}

private fun buildPrayerSlots(state: CreateGoalUiState): List<GoalSlot> {
    val slots = mutableListOf<GoalSlot>()
    var sortOrder = 0
    val prayers = Prayer.entries.filter { it in state.selectedPrayers }
    for (prayer in prayers) {
        val timings = when (state.prayerTiming) {
            PrayerTiming.BEFORE -> listOf("before")
            PrayerTiming.AFTER -> listOf("after")
            PrayerTiming.BOTH -> listOf("before", "after")
        }
        for (timing in timings) {
            val timingValue = "${timing}_${prayer.name.lowercase()}"
            val label = "${timing.replaceFirstChar { it.uppercase() }} ${prayer.name.lowercase().replaceFirstChar { it.uppercase() }}"
            val count = if (state.uniformPrayerCount) {
                state.uniformTargetCount.toIntOrNull() ?: 33
            } else {
                state.prayerCounts[prayer]?.toIntOrNull() ?: 33
            }
            slots.add(GoalSlot(
                goalId = 0,
                targetCount = count,
                timingType = SlotTimingTypes.PRAYER,
                timingValue = timingValue,
                label = label,
                sortOrder = sortOrder++,
            ))
        }
    }
    return slots
}

private fun buildTimeSlots(state: CreateGoalUiState): List<GoalSlot> {
    return state.timeSlots.mapIndexed { index, input ->
        GoalSlot(
            goalId = 0,
            targetCount = input.targetCount.toIntOrNull() ?: 33,
            timingType = SlotTimingTypes.TIME_WINDOW,
            timingValue = "${input.startTime}-${input.endTime}",
            label = input.label.ifEmpty { "Slot ${index + 1}" },
            sortOrder = index,
        )
    }
}
```

- [ ] **Step 5: Rewrite buildConfig()**

```kotlin
private fun buildConfig(state: CreateGoalUiState): GoalConfig? {
    return when (state.selectedPreset.frequencyType) {
        FrequencyType.DAILY -> null
        FrequencyType.WEEKLY -> GoalConfig.Weekly(
            days = state.selectedDays.sortedBy { it.value }.map { it.name.take(3) },
        )
        FrequencyType.MONTHLY -> GoalConfig.Monthly(
            daysOfMonth = state.selectedDaysOfMonth.sorted(),
            calendar = state.calendarType,
        )
        FrequencyType.INTERVAL -> GoalConfig.Interval(
            intervalDays = state.intervalDays.toIntOrNull() ?: 3,
        )
        FrequencyType.YEARLY -> GoalConfig.Yearly(
            month = state.selectedMonth,
            days = state.selectedYearDays.sorted(),
            calendar = state.calendarType,
        )
        FrequencyType.SPECIFIC_DATES -> GoalConfig.Yearly(
            month = state.selectedMonth,
            days = state.selectedYearDays.sorted(),
            calendar = state.calendarType,
        )
    }
}
```

- [ ] **Step 6: Rewrite createGoal()**

```kotlin
fun createGoal() {
    val state = _state.value
    val dhikr = state.selectedDhikr ?: return
    _state.value = state.copy(isCreating = true)

    viewModelScope.launch {
        val preset = state.selectedPreset
        val durationDays = when {
            preset == GoalPreset.ONE_TIME -> 1
            state.hasDuration -> state.durationDays.toIntOrNull()
            else -> null
        }
        val slots = buildSlots(state)
        val config = buildConfig(state)
        val minimumCount = if (state.hasMinStreak) state.minStreakCount.toIntOrNull() else null

        val targetType = when (state.timingType) {
            TimingType.PRAYER_BASED -> TargetType.CUSTOM
            TimingType.TIME_BASED -> TargetType.CUSTOM
            TimingType.ANYTIME -> preset.defaultTargetType
        }

        val goal = Goal(
            dhikrId = dhikr.id,
            frequencyType = preset.frequencyType,
            timingType = state.timingType,
            targetType = targetType,
            durationType = if (durationDays != null) DurationType.FIXED else preset.defaultDurationType,
            minimumCount = minimumCount,
            config = config,
            slots = slots,
            startDate = LocalDate.parse(dateProvider.getEffectiveToday()),
            durationDays = durationDays,
            notificationEnabled = state.notificationEnabled,
            notificationHour = if (state.notificationEnabled) state.notificationHour else null,
            notificationMinute = if (state.notificationEnabled) state.notificationMinute else null,
        )
        val goalId = goalRepository.createGoal(goal)
        if (state.notificationEnabled) {
            scheduler.scheduleForGoal(goal.copy(id = goalId))
        }
        _state.value = _state.value.copy(isCreating = false, isCreated = true)
    }
}
```

- [ ] **Step 7: Rewrite updateFormValidity()**

```kotlin
private fun updateFormValidity() {
    val state = _state.value
    val valid = isFormValid(state)
    _state.value = state.copy(isFormValid = valid)
}

private fun isFormValid(state: CreateGoalUiState): Boolean {
    if (state.selectedDhikr == null) return false
    val preset = state.selectedPreset

    // Frequency-specific validation
    val freqValid = when (preset.frequencyType) {
        FrequencyType.DAILY -> true
        FrequencyType.WEEKLY -> state.selectedDays.isNotEmpty()
        FrequencyType.MONTHLY -> state.selectedDaysOfMonth.isNotEmpty()
        FrequencyType.INTERVAL -> state.intervalDays.toIntOrNull()?.let { it > 0 } ?: false
        FrequencyType.YEARLY -> state.selectedYearDays.isNotEmpty()
        FrequencyType.SPECIFIC_DATES -> state.selectedYearDays.isNotEmpty()
    }

    // Target validation
    val targetValid = when {
        preset.defaultTargetType == TargetType.NONE -> true
        state.timingType == TimingType.PRAYER_BASED ->
            state.selectedPrayers.isNotEmpty() &&
                if (state.uniformPrayerCount) {
                    state.uniformTargetCount.toIntOrNull()?.let { it > 0 } ?: false
                } else {
                    state.selectedPrayers.all { prayer ->
                        state.prayerCounts[prayer]?.toIntOrNull()?.let { it > 0 } ?: false
                    }
                }
        state.timingType == TimingType.TIME_BASED ->
            state.timeSlots.isNotEmpty() && state.timeSlots.all {
                it.startTime.isNotEmpty() && it.endTime.isNotEmpty() &&
                    it.targetCount.toIntOrNull()?.let { c -> c > 0 } ?: false
            }
        else -> state.targetCount.toIntOrNull()?.let { it > 0 } ?: false
    }

    // Min streak validation
    val minStreakValid = !state.hasMinStreak || state.minStreakCount.toIntOrNull()?.let { it > 0 } ?: false

    return freqValid && targetValid && minStreakValid
}
```

- [ ] **Step 8: Compile to verify**

Run: `./gradlew compileDebugKotlin`

- [ ] **Step 9: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt
git commit -m "feat: rewrite CreateGoalViewModel with preset/template system"
```

---

### Task 11: Rewrite CreateGoalScreen UI

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt`
- Modify: `app/src/main/res/values/strings.xml`
- Modify: `app/src/main/res/values-ar/strings.xml`
- Modify: `app/src/main/res/values-ml/strings.xml`

- [ ] **Step 1: Add string resources**

In `res/values/strings.xml`:
```xml
<string name="create_goal_quick_presets">Quick presets</string>
<string name="create_goal_advanced">Advanced</string>
<string name="preset_daily">Daily</string>
<string name="preset_prayer_based">Prayer-based</string>
<string name="preset_one_time">One-time</string>
<string name="preset_tracker">Tracker</string>
<string name="preset_weekly">Weekly</string>
<string name="preset_monthly_gregorian">Monthly</string>
<string name="preset_monthly_hijri">Monthly (Hijri)</string>
<string name="preset_interval">Every X days</string>
<string name="preset_yearly_gregorian">Yearly</string>
<string name="preset_yearly_hijri">Yearly (Hijri)</string>
<string name="preset_specific_dates">Specific dates</string>
<string name="create_goal_timing">Timing</string>
<string name="timing_anytime">Anytime</string>
<string name="timing_prayer_based">Prayer-based</string>
<string name="timing_time_based">Time-based</string>
<string name="create_goal_pick_days_week">Pick days of the week</string>
<string name="create_goal_pick_days_month">Pick days of the month</string>
<string name="create_goal_pick_month">Pick month</string>
<string name="create_goal_interval_label">Repeat every</string>
<string name="create_goal_interval_suffix">days</string>
<string name="create_goal_per_day">per day</string>
<string name="create_goal_total">total</string>
```

Add matching translations to `values-ar/strings.xml` and `values-ml/strings.xml`.

- [ ] **Step 2: Read the current CreateGoalScreen to understand structure**

- [ ] **Step 3: Rewrite ConfigureGoalStep — preset chips section**

Replace the GoalType chip section with:

```kotlin
// Quick Presets
Text(
    text = stringResource(R.string.create_goal_quick_presets),
    style = MaterialTheme.typography.titleSmall,
    fontWeight = FontWeight.SemiBold,
)
Spacer(modifier = Modifier.height(8.dp))
FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    val quickPresets = listOf(
        GoalPreset.DAILY to stringResource(R.string.preset_daily),
        GoalPreset.PRAYER_BASED to stringResource(R.string.preset_prayer_based),
        GoalPreset.ONE_TIME to stringResource(R.string.preset_one_time),
        GoalPreset.TRACKER to stringResource(R.string.preset_tracker),
    )
    quickPresets.forEach { (preset, label) ->
        FilterChip(
            selected = uiState.selectedPreset == preset,
            onClick = { viewModel.selectPreset(preset) },
            label = { Text(label) },
            colors = FilterChipDefaults.filterChipColors(
                selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
            ),
        )
    }
}

// Inline target for quick presets
if (uiState.selectedPreset.isQuickPreset && uiState.selectedPreset.showTargetField) {
    Spacer(modifier = Modifier.height(12.dp))
    if (uiState.selectedPreset == GoalPreset.PRAYER_BASED) {
        PrayerBasedForm(uiState = uiState, viewModel = viewModel)
    } else {
        OutlinedTextField(
            value = uiState.targetCount,
            onValueChange = { viewModel.setTargetCount(it) },
            label = { Text(stringResource(R.string.create_goal_target_count)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
```

- [ ] **Step 4: Add Advanced section**

```kotlin
// Advanced toggle
Spacer(modifier = Modifier.height(16.dp))
Row(
    modifier = Modifier
        .fillMaxWidth()
        .clickable { viewModel.toggleAdvanced() },
    horizontalArrangement = Arrangement.SpaceBetween,
    verticalAlignment = Alignment.CenterVertically,
) {
    Text(
        text = stringResource(R.string.create_goal_advanced),
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
    )
    Icon(
        imageVector = if (uiState.showAdvanced) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
        contentDescription = null,
    )
}

if (uiState.showAdvanced) {
    Spacer(modifier = Modifier.height(8.dp))
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val advancedPresets = listOf(
            GoalPreset.ADV_DAILY to stringResource(R.string.preset_daily),
            GoalPreset.ADV_PRAYER_BASED to stringResource(R.string.preset_prayer_based),
            GoalPreset.ADV_WEEKLY to stringResource(R.string.preset_weekly),
            GoalPreset.ADV_MONTHLY_GREGORIAN to stringResource(R.string.preset_monthly_gregorian),
            GoalPreset.ADV_MONTHLY_HIJRI to stringResource(R.string.preset_monthly_hijri),
            GoalPreset.ADV_INTERVAL to stringResource(R.string.preset_interval),
            GoalPreset.ADV_YEARLY_GREGORIAN to stringResource(R.string.preset_yearly_gregorian),
            GoalPreset.ADV_YEARLY_HIJRI to stringResource(R.string.preset_yearly_hijri),
            GoalPreset.ADV_SPECIFIC_DATES to stringResource(R.string.preset_specific_dates),
            GoalPreset.ADV_TRACKER to stringResource(R.string.preset_tracker),
        )
        advancedPresets.forEach { (preset, label) ->
            FilterChip(
                selected = uiState.selectedPreset == preset,
                onClick = { viewModel.selectPreset(preset) },
                label = { Text(label) },
            )
        }
    }

    // Frequency details form
    Spacer(modifier = Modifier.height(12.dp))
    FrequencyDetailsForm(uiState = uiState, viewModel = viewModel)

    // Timing picker (Anytime | Prayer-based | Time-based)
    if (uiState.selectedPreset.showTimingPicker) {
        Spacer(modifier = Modifier.height(12.dp))
        Text(stringResource(R.string.create_goal_timing), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Spacer(modifier = Modifier.height(8.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(
                TimingType.ANYTIME to stringResource(R.string.timing_anytime),
                TimingType.PRAYER_BASED to stringResource(R.string.timing_prayer_based),
                TimingType.TIME_BASED to stringResource(R.string.timing_time_based),
            ).forEach { (timing, label) ->
                FilterChip(
                    selected = uiState.timingType == timing,
                    onClick = { viewModel.setTimingType(timing) },
                    label = { Text(label) },
                )
            }
        }
    }

    // Target form based on timing
    if (uiState.selectedPreset.showTargetField) {
        Spacer(modifier = Modifier.height(12.dp))
        when (uiState.timingType) {
            TimingType.PRAYER_BASED -> PrayerBasedForm(uiState = uiState, viewModel = viewModel)
            TimingType.TIME_BASED -> TimeBasedForm(uiState = uiState, viewModel = viewModel)
            TimingType.ANYTIME -> {
                OutlinedTextField(
                    value = uiState.targetCount,
                    onValueChange = { viewModel.setTargetCount(it) },
                    label = { Text(stringResource(R.string.create_goal_target_count)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }

    // Min streak
    Spacer(modifier = Modifier.height(12.dp))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(stringResource(R.string.create_goal_min_streak), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Switch(checked = uiState.hasMinStreak, onCheckedChange = { viewModel.setHasMinStreak(it) })
    }
    if (uiState.hasMinStreak) {
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = uiState.minStreakCount,
            onValueChange = { viewModel.setMinStreakCount(it) },
            label = { Text(stringResource(R.string.create_goal_min_streak_hint)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
```

- [ ] **Step 5: Add FrequencyDetailsForm composable**

```kotlin
@Composable
private fun FrequencyDetailsForm(uiState: CreateGoalUiState, viewModel: CreateGoalViewModel) {
    when (uiState.selectedPreset.frequencyType) {
        FrequencyType.WEEKLY -> {
            Text(stringResource(R.string.create_goal_pick_days_week), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            val days = listOf(
                DayOfWeek.MONDAY to stringResource(R.string.home_day_mon),
                DayOfWeek.TUESDAY to stringResource(R.string.home_day_tue),
                DayOfWeek.WEDNESDAY to stringResource(R.string.home_day_wed),
                DayOfWeek.THURSDAY to stringResource(R.string.home_day_thu),
                DayOfWeek.FRIDAY to stringResource(R.string.home_day_fri),
                DayOfWeek.SATURDAY to stringResource(R.string.home_day_sat),
                DayOfWeek.SUNDAY to stringResource(R.string.home_day_sun),
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                days.forEach { (day, label) ->
                    FilterChip(
                        selected = day in uiState.selectedDays,
                        onClick = { viewModel.toggleWeekDay(day) },
                        label = { Text(label) },
                    )
                }
            }
        }
        FrequencyType.MONTHLY -> {
            Text(stringResource(R.string.create_goal_pick_days_month), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            val maxDay = if (uiState.calendarType == "hijri") 30 else 31
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                (1..maxDay).forEach { day ->
                    FilterChip(
                        selected = day in uiState.selectedDaysOfMonth,
                        onClick = { viewModel.toggleMonthDay(day) },
                        label = { Text("$day") },
                    )
                }
            }
        }
        FrequencyType.INTERVAL -> {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.create_goal_interval_label), style = MaterialTheme.typography.titleSmall)
                OutlinedTextField(
                    value = uiState.intervalDays,
                    onValueChange = { viewModel.setIntervalDays(it) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.width(80.dp),
                )
                Text(stringResource(R.string.create_goal_interval_suffix), style = MaterialTheme.typography.titleSmall)
            }
        }
        FrequencyType.YEARLY, FrequencyType.SPECIFIC_DATES -> {
            // Month picker
            Text(stringResource(R.string.create_goal_pick_month), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            val monthCount = if (uiState.calendarType == "hijri") 12 else 12
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                (1..monthCount).forEach { month ->
                    FilterChip(
                        selected = uiState.selectedMonth == month,
                        onClick = { viewModel.setSelectedMonth(month) },
                        label = { Text("$month") },
                    )
                }
            }
            // Day picker
            Spacer(modifier = Modifier.height(8.dp))
            Text(stringResource(R.string.create_goal_pick_days_month), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            val maxDay = if (uiState.calendarType == "hijri") 30 else 31
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                (1..maxDay).forEach { day ->
                    FilterChip(
                        selected = day in uiState.selectedYearDays,
                        onClick = { viewModel.toggleYearDay(day) },
                        label = { Text("$day") },
                    )
                }
            }
        }
        FrequencyType.DAILY -> { /* No extra config needed */ }
    }
}
```

- [ ] **Step 6: Add TimeBasedForm composable**

```kotlin
@Composable
private fun TimeBasedForm(uiState: CreateGoalUiState, viewModel: CreateGoalViewModel) {
    uiState.timeSlots.forEachIndexed { index, slot ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = slot.label,
                onValueChange = { viewModel.updateTimeSlotLabel(index, it) },
                label = { Text("Label") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = slot.targetCount,
                onValueChange = { viewModel.updateTimeSlotTarget(index, it) },
                label = { Text("Count") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.width(80.dp),
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
    }
    TextButton(onClick = { viewModel.addTimeSlot() }) {
        Text("+ Add time slot")
    }
}
```

- [ ] **Step 7: Remove old goalTypeLabel() and slotKeyToDisplayName() functions**

Delete the `goalTypeLabel()` function that mapped GoalType to strings. Delete `slotKeyToDisplayName()` if it exists.

- [ ] **Step 8: Add necessary imports**

Add: `DayOfWeek`, `GoalPreset`, `TimingType`, `FrequencyType`, `Icons.Default.ExpandLess`, `Icons.Default.ExpandMore`, `Switch`, `FlowRow`

Remove: `GoalType` import

- [ ] **Step 9: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt \
       app/src/main/res/values/strings.xml \
       app/src/main/res/values-ar/strings.xml \
       app/src/main/res/values-ml/strings.xml
git commit -m "feat: rewrite CreateGoalScreen with preset chips and advanced templates"
```

---

### Task 12: Update CountingScreen slot display

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt`

- [ ] **Step 1: Update CountingViewModel — pass Goal object for streak calc**

In `CountingViewModel`, update the `HistoryBottomSheet` to receive the full Goal for schedule-aware streaks. Add to `GoalInfoHolder` and `CountingUiState`:

```kotlin
// In GoalInfoHolder, add:
val goal: Goal? = null,

// Set in bindAndStart():
goal = goal,
```

Update the streak calculation call site to use `goal` parameter instead of `scheduleDays`.

- [ ] **Step 2: Update slot display in CountingScreen**

Find anywhere `slotKeyToDisplayName(slot.slotKey)` or `slot.slotKey` is used for display. Replace with:

```kotlin
slot.label ?: slot.timingValue ?: ""
```

- [ ] **Step 3: Update HistoryBottomSheet streak calculation**

Replace the `calculateStreakWithCounts` call to use the new `goal` parameter:

```kotlin
val streakInfo = remember(dailyCounts, effectiveToday, dailyTarget, minimumStreakCount) {
    GoalProgressCalculator.calculateStreakWithCounts(
        dailyCounts = dailyCounts,
        today = effectiveToday,
        dailyTarget = dailyTarget,
        minimumStreakCount = minimumStreakCount,
        goal = goal,
    )
}
```

- [ ] **Step 4: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt
git commit -m "feat: update CountingScreen for new slot model and goal-aware streaks"
```

---

### Task 13: Final compilation, cleanup, and install test

- [ ] **Step 1: Search for any remaining references to removed types**

Run: `grep -r "GoalType\|goalType\|slotKey\|SlotKeys\|scheduleDays\|minimumStreakCount" --include="*.kt" app/src/main/java/`

Fix any remaining references.

- [ ] **Step 2: Full build**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 3: Install and run**

Run: `./gradlew installDebug`

- [ ] **Step 4: Manual smoke test**

1. App launches without crash (migration runs)
2. Existing goals still display correctly
3. Create a new Daily goal → works
4. Create a new Prayer-based goal → works
5. Create an Advanced Weekly goal (pick Friday) → works
6. Open counting screen → history bottom sheet shows streak grid
7. Home screen streak card works

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: configurable goals system — complete implementation"
```
