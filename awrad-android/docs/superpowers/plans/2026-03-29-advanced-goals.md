# Advanced Goals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add weekly schedule support (e.g., "every Friday") and minimum streak threshold to the goal system, with a three-state streak grid (complete / partial / empty).

**Architecture:** Two new nullable columns on `goals` table (`scheduleDays TEXT`, `minimumStreakCount INTEGER`) with Room migration 8→9. `GoalProgressCalculator` updated to respect schedule days in `isDueToday()` and threshold in `calculateStreak()`. `StreakSection` composable updated for three-state coloring. `CreateGoalScreen` gets day-of-week picker and minimum threshold field for ADVANCED goals.

**Tech Stack:** Room 2.6.1, Kotlin, Jetpack Compose, Hilt, Material3

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `data/database/entity/GoalEntity.kt` | Add `scheduleDays` and `minimumStreakCount` columns |
| Modify | `data/model/Goal.kt` | Add matching domain fields |
| Modify | `di/DatabaseModule.kt` | Migration 8→9, bump version |
| Modify | `data/database/AwradDatabase.kt` | Bump version to 9 |
| Modify | `data/repository/GoalRepositoryImpl.kt` | Map new fields in `toDomain()`/`toEntity()` |
| Modify | `util/GoalProgressCalculator.kt` | Update `isDueToday()`, `calculateStreak()`, add `StreakDayStatus` |
| Modify | `ui/components/StreakSection.kt` | Three-state cell coloring (full/partial/empty) |
| Modify | `ui/screens/goals/CreateGoalViewModel.kt` | Add schedule days and min threshold to state + form logic |
| Modify | `ui/screens/goals/CreateGoalScreen.kt` | Day picker + min threshold UI for ADVANCED type |
| Modify | `ui/screens/counting/CountingScreen.kt` | Pass daily target to streak for threshold coloring |
| Modify | `ui/screens/counting/CountingViewModel.kt` | Expose `minimumStreakCount` and `scheduleDays` |
| Modify | `ui/screens/home/HomeViewModel.kt` | Filter goals by schedule day in `isDueToday()` |
| Modify | `res/values/strings.xml` | New string resources |
| Modify | `res/values-ar/strings.xml` | Arabic translations |
| Modify | `res/values-ml/strings.xml` | Malayalam translations |

---

### Task 1: Schema — Add columns to GoalEntity and Goal model

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalEntity.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/Goal.kt`

- [ ] **Step 1: Add fields to GoalEntity**

```kotlin
// In GoalEntity, add after notificationMinute:
    val scheduleDays: String? = null,       // e.g. "FRI" or "MON,WED,FRI" — null means every day
    val minimumStreakCount: Int? = null,     // null means full daily target required for streak
```

The full data class becomes:
```kotlin
data class GoalEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val dhikrId: Long,
    val goalType: GoalType,
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
    val scheduleDays: String? = null,
    val minimumStreakCount: Int? = null,
)
```

- [ ] **Step 2: Add matching fields to Goal domain model**

```kotlin
// In Goal, add after notificationMinute:
    val scheduleDays: String? = null,
    val minimumStreakCount: Int? = null,
```

- [ ] **Step 3: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: Build failure (migration needed — will fix in Task 2)

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/entity/GoalEntity.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/model/Goal.kt
git commit -m "feat: add scheduleDays and minimumStreakCount fields to Goal"
```

---

### Task 2: Room migration 8→9

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/di/DatabaseModule.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AwradDatabase.kt`

- [ ] **Step 1: Add migration8To9 in DatabaseModule.kt**

Add after the `migration7To8` block (before the `return Room.databaseBuilder(...)` line):

```kotlin
val migration8To9 = object : Migration(8, 9) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE goals ADD COLUMN scheduleDays TEXT DEFAULT NULL")
        db.execSQL("ALTER TABLE goals ADD COLUMN minimumStreakCount INTEGER DEFAULT NULL")
    }
}
```

- [ ] **Step 2: Register migration**

Update the `addMigrations` call:
```kotlin
.addMigrations(migration1To2, migration2To3, migration3To4, migration4To5, migration5To6, migration6To7, migration7To8, migration8To9)
```

- [ ] **Step 3: Bump database version**

In `AwradDatabase.kt`, change:
```kotlin
version = 9,
```

- [ ] **Step 4: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS (may still fail if mapping not updated — that's Task 3)

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/di/DatabaseModule.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AwradDatabase.kt
git commit -m "feat: add Room migration 8→9 for scheduleDays and minimumStreakCount"
```

---

### Task 3: Update repository mapping

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt`

- [ ] **Step 1: Update toDomain() mapping**

Find `private fun GoalEntity.toDomain(...)` and add the two new fields:

```kotlin
private fun GoalEntity.toDomain(dhikr: Dhikr? = null, slots: List<GoalSlot> = emptyList()) = Goal(
    id = id,
    dhikrId = dhikrId,
    dhikr = dhikr,
    goalType = goalType,
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
    scheduleDays = scheduleDays,
    minimumStreakCount = minimumStreakCount,
)
```

- [ ] **Step 2: Update toEntity() mapping**

Find `private fun Goal.toEntity()` and add the two new fields:

```kotlin
private fun Goal.toEntity() = GoalEntity(
    id = id,
    dhikrId = dhikrId,
    goalType = goalType,
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
    scheduleDays = scheduleDays,
    minimumStreakCount = minimumStreakCount,
)
```

- [ ] **Step 3: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt
git commit -m "feat: map scheduleDays and minimumStreakCount in repository"
```

---

### Task 4: Update GoalProgressCalculator — isDueToday() and streak logic

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/util/GoalProgressCalculator.kt`

- [ ] **Step 1: Update isDueToday() to check scheduleDays**

Replace the existing `isDueToday()` function:

```kotlin
fun isDueToday(goal: Goal, date: LocalDate = LocalDate.now()): Boolean {
    if (!goal.isActive || goal.isCompleted) return false
    if (date.isBefore(goal.startDate)) return false
    goal.endDate?.let { if (date.isAfter(it)) return false }
    goal.durationDays?.let {
        val daysSinceStart = ChronoUnit.DAYS.between(goal.startDate, date)
        if (daysSinceStart >= it) return false
    }

    // Check schedule days (e.g., "FRI" or "MON,WED,FRI")
    goal.scheduleDays?.let { days ->
        val todayName = date.dayOfWeek.name.take(3) // "MON", "TUE", etc.
        val scheduledDays = days.split(",").map { it.trim().uppercase() }
        if (todayName !in scheduledDays) return false
    }

    return when (goal.goalType) {
        GoalType.DAILY -> true
        GoalType.PRAYER_BASED -> true
        GoalType.ONE_TIME -> date == goal.startDate
        GoalType.ADVANCED -> true
    }
}
```

- [ ] **Step 2: Add StreakDayStatus enum and update calculateStreak()**

Add a new enum and update the streak function to support three states and schedule-aware streaks:

```kotlin
enum class StreakDayStatus { COMPLETE, PARTIAL, INACTIVE }

fun calculateStreak(
    dates: List<String>,
    today: LocalDate = LocalDate.now(),
    dailyTarget: Int = 0,
    minimumStreakCount: Int? = null,
    scheduleDays: String? = null,
): StreakInfo {
    val dateSet = dates.mapTo(HashSet()) { LocalDate.parse(it) }

    // Build schedule set for quick lookup
    val scheduledDaySet = scheduleDays?.split(",")
        ?.map { it.trim().uppercase() }
        ?.toSet()

    var streak = 0
    var checkDate = if (dateSet.contains(today)) today else today.minusDays(1)
    while (true) {
        // Skip non-scheduled days (they don't break the streak)
        if (scheduledDaySet != null) {
            val dayName = checkDate.dayOfWeek.name.take(3)
            if (dayName !in scheduledDaySet) {
                checkDate = checkDate.minusDays(1)
                continue
            }
        }
        if (!dateSet.contains(checkDate)) break
        streak++
        checkDate = checkDate.minusDays(1)
    }

    return StreakInfo(currentStreak = streak, activeDates = dateSet)
}
```

- [ ] **Step 3: Add per-day count version for three-state grid**

Add a new function that returns daily counts for the streak grid to distinguish complete vs partial:

```kotlin
fun calculateStreakWithCounts(
    dailyCounts: Map<LocalDate, Long>,
    today: LocalDate = LocalDate.now(),
    dailyTarget: Int = 0,
    minimumStreakCount: Int? = null,
    scheduleDays: String? = null,
): StreakInfo {
    val dateSet = dailyCounts.keys.toHashSet()

    val scheduledDaySet = scheduleDays?.split(",")
        ?.map { it.trim().uppercase() }
        ?.toSet()

    val threshold = minimumStreakCount ?: dailyTarget

    var streak = 0
    var checkDate = if (dateSet.contains(today)) today else today.minusDays(1)
    while (true) {
        if (scheduledDaySet != null) {
            val dayName = checkDate.dayOfWeek.name.take(3)
            if (dayName !in scheduledDaySet) {
                checkDate = checkDate.minusDays(1)
                continue
            }
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
        minimumStreakCount = if (minimumStreakCount != null) minimumStreakCount else dailyTarget,
    )
}
```

- [ ] **Step 4: Update StreakInfo to carry daily counts**

```kotlin
data class StreakInfo(
    val currentStreak: Int = 0,
    val activeDates: Set<LocalDate> = emptySet(),
    val dailyCounts: Map<LocalDate, Long> = emptyMap(),
    val minimumStreakCount: Int = 0,
) {
    fun statusForDate(date: LocalDate): StreakDayStatus {
        val count = dailyCounts[date] ?: 0L
        return when {
            count <= 0L -> StreakDayStatus.INACTIVE
            minimumStreakCount > 0 && count >= minimumStreakCount -> StreakDayStatus.COMPLETE
            count > 0L -> StreakDayStatus.PARTIAL
            else -> StreakDayStatus.INACTIVE
        }
    }
}
```

- [ ] **Step 5: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/util/GoalProgressCalculator.kt
git commit -m "feat: schedule-aware isDueToday and three-state streak calculation"
```

---

### Task 5: Add per-goal daily counts DAO query and repository method

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/dao/CountEntryDao.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepository.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt`

- [ ] **Step 1: Add DAO query for per-goal daily counts**

In `CountEntryDao.kt`, add:

```kotlin
@Query("SELECT date, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 GROUP BY date ORDER BY date DESC")
abstract fun getDailyCountsForGoal(goalId: Long): Flow<List<GoalDateCount>>
```

Note: `GoalDateCount` already exists in this file with fields `goalId` and `total`. We need a different data class for date+total. Add to `CountEntryDao.kt`:

```kotlin
data class DateCount(val date: String, val total: Long)
```

And update the query to use it:

```kotlin
@Query("SELECT date, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 GROUP BY date ORDER BY date DESC")
abstract fun getDailyCountsForGoal(goalId: Long): Flow<List<DateCount>>
```

- [ ] **Step 2: Add repository interface method**

In `GoalRepository.kt`, add:

```kotlin
fun getDailyCountsForGoal(goalId: Long): Flow<Map<LocalDate, Long>>
```

- [ ] **Step 3: Implement in GoalRepositoryImpl**

In `GoalRepositoryImpl.kt`, add:

```kotlin
override fun getDailyCountsForGoal(goalId: Long): Flow<Map<LocalDate, Long>> =
    countEntryDao.getDailyCountsForGoal(goalId).map { list ->
        list.associate { LocalDate.parse(it.date) to it.total }
    }
```

Add import: `import java.time.LocalDate` (check if already imported).

- [ ] **Step 4: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/dao/CountEntryDao.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepository.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/GoalRepositoryImpl.kt
git commit -m "feat: add getDailyCountsForGoal query for three-state streak grid"
```

---

### Task 6: Update StreakSection for three-state coloring

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/StreakSection.kt`

- [ ] **Step 1: Add streakInfo parameter and update coloring logic**

Update the `StreakSection` composable signature to accept an optional `StreakInfo` for three-state rendering. The key change is in the cell color logic:

Replace the current signature:
```kotlin
fun StreakSection(
    currentStreak: Int,
    activeDates: Set<LocalDate>,
    today: LocalDate,
    earliestDate: LocalDate? = null,
    modifier: Modifier = Modifier,
)
```

With:
```kotlin
fun StreakSection(
    currentStreak: Int,
    activeDates: Set<LocalDate>,
    today: LocalDate,
    earliestDate: LocalDate? = null,
    streakInfo: StreakInfo? = null,
    modifier: Modifier = Modifier,
)
```

Add import: `import app.awrad.awrad_dhikrgoalstracker.util.StreakDayStatus`
Add import: `import app.awrad.awrad_dhikrgoalstracker.util.StreakInfo`

- [ ] **Step 2: Update cell color logic in the grid**

Find the block that computes `color` for each calendar day cell and replace it:

```kotlin
val color = when {
    isFuture -> emptyColor.copy(alpha = 0.3f)
    else -> {
        val status = streakInfo?.statusForDate(date)
        when {
            isToday && status == StreakDayStatus.COMPLETE -> goldColor
            isToday && status == StreakDayStatus.PARTIAL -> goldColor.copy(alpha = 0.45f)
            isToday && isActive -> goldColor
            isToday -> goldColor.copy(alpha = 0.35f)
            status == StreakDayStatus.COMPLETE -> goldColor
            status == StreakDayStatus.PARTIAL -> goldColor.copy(alpha = 0.45f)
            isActive && streakInfo == null -> goldColor
            else -> emptyColor
        }
    }
}
```

Also update `textColor` to handle PARTIAL:

```kotlin
val textColor = when {
    isFuture -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
    else -> {
        val status = streakInfo?.statusForDate(date)
        when {
            status == StreakDayStatus.COMPLETE -> MaterialTheme.colorScheme.onSecondary
            status == StreakDayStatus.PARTIAL -> MaterialTheme.colorScheme.onSecondary
            isActive && streakInfo == null -> MaterialTheme.colorScheme.onSecondary
            else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
        }
    }
}
```

- [ ] **Step 3: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/StreakSection.kt
git commit -m "feat: three-state streak grid (complete/partial/empty)"
```

---

### Task 7: Wire three-state streak into CountingScreen's HistoryBottomSheet

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt`

- [ ] **Step 1: Add fields to CountingUiState**

In `CountingUiState`, add after `effectiveToday`:
```kotlin
    val minimumStreakCount: Int? = null,
    val scheduleDays: String? = null,
    val dailyTarget: Int = 0,
```

- [ ] **Step 2: Add dailyCounts flow to CountingViewModel**

In `CountingViewModel`, add alongside `_historyItems`:
```kotlin
private val _dailyCounts = MutableStateFlow<Map<LocalDate, Long>>(emptyMap())
val dailyCounts: StateFlow<Map<LocalDate, Long>> = _dailyCounts.asStateFlow()
```

- [ ] **Step 3: Collect daily counts in bindAndStart()**

In `bindAndStart()`, add after the `getHistoryForGoal` collection:
```kotlin
launch {
    goalRepository.getDailyCountsForGoal(goalId).collect { _dailyCounts.value = it }
}
```

- [ ] **Step 4: Add goal fields to GoalInfoHolder**

In `GoalInfoHolder`, add:
```kotlin
    val minimumStreakCount: Int? = null,
    val scheduleDays: String? = null,
    val dailyTarget: Int = 0,
```

- [ ] **Step 5: Wire in bindAndStart() goal info**

In the `_goalInfo.value = GoalInfoHolder(...)` block, add:
```kotlin
    minimumStreakCount = goal.minimumStreakCount,
    scheduleDays = goal.scheduleDays,
    dailyTarget = dailyTarget,
```

- [ ] **Step 6: Wire in CountingUiState construction**

In the `combine` block that builds `CountingUiState`, add:
```kotlin
    minimumStreakCount = goalInfo.minimumStreakCount,
    scheduleDays = goalInfo.scheduleDays,
    dailyTarget = goalInfo.dailyTarget,
```

- [ ] **Step 7: Update HistoryBottomSheet call site**

In CountingScreen, update the `HistoryBottomSheet` call:
```kotlin
if (showHistory) {
    val dailyCounts by viewModel.dailyCounts.collectAsStateWithLifecycle()
    HistoryBottomSheet(
        historyItems = historyItems,
        isPrayerBased = uiState.isPrayerBased,
        slots = uiState.slots,
        goalStartDate = uiState.goalStartDate,
        effectiveToday = uiState.effectiveToday,
        dailyCounts = dailyCounts,
        dailyTarget = uiState.dailyTarget,
        minimumStreakCount = uiState.minimumStreakCount,
        scheduleDays = uiState.scheduleDays,
        onDismiss = { showHistory = false },
    )
}
```

- [ ] **Step 8: Update HistoryBottomSheet function signature and streak calculation**

```kotlin
private fun HistoryBottomSheet(
    historyItems: List<CountEntry>,
    isPrayerBased: Boolean,
    slots: List<GoalSlot>,
    goalStartDate: LocalDate,
    effectiveToday: LocalDate,
    dailyCounts: Map<LocalDate, Long>,
    dailyTarget: Int,
    minimumStreakCount: Int?,
    scheduleDays: String?,
    onDismiss: () -> Unit,
) {
```

Replace the streak calculation block:
```kotlin
val streakInfo = remember(dailyCounts, effectiveToday, dailyTarget, minimumStreakCount, scheduleDays) {
    GoalProgressCalculator.calculateStreakWithCounts(
        dailyCounts = dailyCounts,
        today = effectiveToday,
        dailyTarget = dailyTarget,
        minimumStreakCount = minimumStreakCount,
        scheduleDays = scheduleDays,
    )
}
```

Update the `StreakSection` call:
```kotlin
StreakSection(
    currentStreak = streakInfo.currentStreak,
    activeDates = streakInfo.activeDates,
    today = effectiveToday,
    earliestDate = goalStartDate,
    streakInfo = streakInfo,
)
```

- [ ] **Step 9: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingViewModel.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt
git commit -m "feat: wire three-state streak into HistoryBottomSheet"
```

---

### Task 8: Update CreateGoalScreen — day picker and minimum threshold

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt`
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt`
- Modify: `app/src/main/res/values/strings.xml`
- Modify: `app/src/main/res/values-ar/strings.xml`
- Modify: `app/src/main/res/values-ml/strings.xml`

- [ ] **Step 1: Add string resources**

In `res/values/strings.xml`, add after the existing create_goal strings:
```xml
<string name="create_goal_schedule_days">Schedule days</string>
<string name="create_goal_every_day">Every day</string>
<string name="create_goal_specific_days">Specific days</string>
<string name="create_goal_min_streak">Minimum for streak</string>
<string name="create_goal_min_streak_hint">Minimum count to maintain streak</string>
```

In `res/values-ar/strings.xml`:
```xml
<string name="create_goal_schedule_days">أيام الجدول</string>
<string name="create_goal_every_day">كل يوم</string>
<string name="create_goal_specific_days">أيام محددة</string>
<string name="create_goal_min_streak">الحد الأدنى للسلسلة</string>
<string name="create_goal_min_streak_hint">الحد الأدنى للعدد للحفاظ على السلسلة</string>
```

In `res/values-ml/strings.xml`:
```xml
<string name="create_goal_schedule_days">ഷെഡ്യൂൾ ദിവസങ്ങൾ</string>
<string name="create_goal_every_day">എല്ലാ ദിവസവും</string>
<string name="create_goal_specific_days">നിർദ്ദിഷ്ട ദിവസങ്ങൾ</string>
<string name="create_goal_min_streak">സ്ട്രീക്കിനുള്ള മിനിമം</string>
<string name="create_goal_min_streak_hint">സ്ട്രീക്ക് നിലനിർത്താനുള്ള കുറഞ്ഞ എണ്ണം</string>
```

- [ ] **Step 2: Add state fields to CreateGoalUiState**

In `CreateGoalViewModel.kt`, add to `CreateGoalUiState`:
```kotlin
    val useSpecificDays: Boolean = false,
    val selectedDays: Set<DayOfWeek> = emptySet(),
    val hasMinStreak: Boolean = false,
    val minStreakCount: String = "",
```

Add import at top of file: `import java.time.DayOfWeek`

- [ ] **Step 3: Add ViewModel methods**

Add these methods to `CreateGoalViewModel`:

```kotlin
fun setUseSpecificDays(use: Boolean) {
    _state.value = _state.value.copy(useSpecificDays = use)
}

fun toggleDay(day: DayOfWeek) {
    val current = _state.value.selectedDays.toMutableSet()
    if (day in current) current.remove(day) else current.add(day)
    _state.value = _state.value.copy(selectedDays = current)
}

fun setHasMinStreak(has: Boolean) {
    _state.value = _state.value.copy(hasMinStreak = has)
}

fun setMinStreakCount(count: String) {
    _state.value = _state.value.copy(minStreakCount = count)
}
```

- [ ] **Step 4: Update createGoal() to pass new fields**

In `createGoal()`, update the `Goal(...)` construction:

```kotlin
val scheduleDays = if (state.useSpecificDays && state.selectedDays.isNotEmpty()) {
    state.selectedDays.sortedBy { it.value }
        .joinToString(",") { it.name.take(3) }
} else null

val minimumStreakCount = if (state.hasMinStreak) {
    state.minStreakCount.toIntOrNull()
} else null

val goal = Goal(
    dhikrId = dhikr.id,
    goalType = state.goalType,
    slots = slots,
    startDate = LocalDate.parse(dateProvider.getEffectiveToday()),
    durationDays = durationDays,
    notificationEnabled = state.notificationEnabled,
    notificationHour = if (state.notificationEnabled) state.notificationHour else null,
    notificationMinute = if (state.notificationEnabled) state.notificationMinute else null,
    scheduleDays = scheduleDays,
    minimumStreakCount = minimumStreakCount,
)
```

- [ ] **Step 5: Update isFormValid() for schedule days**

Update the ADVANCED case in `isFormValid()`:

```kotlin
GoalType.ADVANCED -> {
    val targetValid = state.targetCount.toIntOrNull()?.let { it > 0 } ?: false
    val scheduleValid = !state.useSpecificDays || state.selectedDays.isNotEmpty()
    val minStreakValid = !state.hasMinStreak || state.minStreakCount.toIntOrNull()?.let { it > 0 } ?: false
    targetValid && scheduleValid && minStreakValid
}
```

Also add schedule and min streak validation for DAILY:
```kotlin
GoalType.DAILY -> {
    val targetValid = state.targetCount.toIntOrNull()?.let { it > 0 } ?: false
    val minStreakValid = !state.hasMinStreak || state.minStreakCount.toIntOrNull()?.let { it > 0 } ?: false
    targetValid && minStreakValid
}
```

- [ ] **Step 6: Add UI for day picker and min streak in CreateGoalScreen**

In `CreateGoalScreen.kt`, inside the `ConfigureGoalStep` composable, add after the target count field (for DAILY and ADVANCED types):

```kotlin
// Schedule Days Section (for DAILY and ADVANCED)
if (state.goalType == GoalType.DAILY || state.goalType == GoalType.ADVANCED) {
    Spacer(modifier = Modifier.height(16.dp))
    Text(
        text = stringResource(R.string.create_goal_schedule_days),
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(
            selected = !state.useSpecificDays,
            onClick = { viewModel.setUseSpecificDays(false) },
            label = { Text(stringResource(R.string.create_goal_every_day)) },
        )
        FilterChip(
            selected = state.useSpecificDays,
            onClick = { viewModel.setUseSpecificDays(true) },
            label = { Text(stringResource(R.string.create_goal_specific_days)) },
        )
    }
    if (state.useSpecificDays) {
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            days.forEach { (day, label) ->
                FilterChip(
                    selected = day in state.selectedDays,
                    onClick = { viewModel.toggleDay(day) },
                    label = { Text(label) },
                )
            }
        }
    }

    // Minimum Streak Section
    Spacer(modifier = Modifier.height(16.dp))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.create_goal_min_streak),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
        )
        Switch(
            checked = state.hasMinStreak,
            onCheckedChange = { viewModel.setHasMinStreak(it) },
        )
    }
    if (state.hasMinStreak) {
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = state.minStreakCount,
            onValueChange = { viewModel.setMinStreakCount(it) },
            label = { Text(stringResource(R.string.create_goal_min_streak_hint)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
```

Add import for `DayOfWeek`: `import java.time.DayOfWeek`
Add import for `Switch`: `import androidx.compose.material3.Switch`

- [ ] **Step 7: Compile to verify**

Run: `./gradlew compileDebugKotlin`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt \
       app/src/main/res/values/strings.xml \
       app/src/main/res/values-ar/strings.xml \
       app/src/main/res/values-ml/strings.xml
git commit -m "feat: add day picker and minimum streak threshold to goal creation"
```

---

### Task 9: Update HomeScreen streak to use schedule-aware calculation

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeViewModel.kt`

The HomeScreen shows a global streak (across all goals). The streak calculation should skip non-scheduled days when all active goals have schedule restrictions. However, since the home streak is global (not per-goal), we keep the existing behavior: a day counts if *any* goal had progress. The `isDueToday()` already handles schedule filtering for showing which goals are "due today."

- [ ] **Step 1: Verify isDueToday filtering already works**

In `HomeViewModel.kt`, the active goals are already filtered:
```kotlin
val goalsWithProgress = activeGoals
    .filter { GoalProgressCalculator.isDueToday(it, effectiveDate) }
```

This already uses the updated `isDueToday()` from Task 4, which checks `scheduleDays`. Goals not scheduled for today won't appear in "Resume Counting."

No code changes needed — just verify the flow works with the updated `isDueToday()`.

- [ ] **Step 2: Compile and run to verify**

Run: `./gradlew installDebug`
Expected: PASS, app installs and runs

- [ ] **Step 3: Commit (only if changes were needed)**

No commit needed if no changes made.

---

### Task 10: Final integration test

- [ ] **Step 1: Build and install**

Run: `./gradlew installDebug`
Expected: PASS

- [ ] **Step 2: Test weekly goal creation**

1. Open app → Goals tab → Create Goal
2. Select any dhikr
3. Select "Advanced" goal type
4. Set target count to 70
5. Select "Specific days" → tap "F" (Friday)
6. Tap Create
7. Verify goal appears in list
8. Open counting screen → verify it works

- [ ] **Step 3: Test minimum streak threshold**

1. Create a new goal with target 300
2. Enable "Minimum for streak" → set to 33
3. Create the goal
4. Count some dhikr (e.g., 50)
5. Open history bottom sheet
6. Verify the streak grid shows gold for today (above minimum)
7. Check that a day with only 10 counts shows lighter gold (partial)

- [ ] **Step 4: Test schedule-aware streaks**

1. With a Friday-only goal, verify:
   - Non-Friday days don't break the streak
   - Only Fridays with counts contribute to streak count
   - Grid shows empty for non-Friday dates

- [ ] **Step 5: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: advanced goals with weekly schedule and minimum streak threshold"
```
