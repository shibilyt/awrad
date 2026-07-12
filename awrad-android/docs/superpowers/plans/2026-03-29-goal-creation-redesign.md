# Goal Creation Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-form goal configuration screen with a Quick Create fast path + Adaptive Wizard, using typed sealed sub-states instead of flat nullable fields.

**Architecture:** Internal state machine within a single nav destination. `GoalCreationMode` sealed class drives which UI renders (SelectDhikr / QuickCreate / Wizard). Wizard steps are computed at runtime via `WizardStepComputer` based on the selected preset. Both paths share one ViewModel and call the same `createGoal()`.

**Tech Stack:** Jetpack Compose + Material3, Hilt, StateFlow, Room (no changes), AnimatedContent for transitions.

**Base package:** `app.awrad.awrad_dhikrgoalstracker`

---

## File Structure

### New Files (Create)

| File | Responsibility |
|------|---------------|
| `ui/screens/goals/model/GoalCreationMode.kt` | Sealed class: SelectDhikr, QuickCreate, Wizard(stepIndex) |
| `ui/screens/goals/model/WizardStep.kt` | Sealed class: Frequency, Timing, Target, WhichPrayers, Deadline, Extras |
| `ui/screens/goals/model/FrequencyDraft.kt` | Sealed class: Daily, Weekly, Monthly, Interval, Yearly |
| `ui/screens/goals/model/TargetDraft.kt` | Sealed class: None, Fixed, PrayerBased |
| `ui/screens/goals/model/ExtrasDraft.kt` | Data class for duration, min streak, notifications |
| `ui/screens/goals/WizardStepComputer.kt` | Pure object computing wizard steps from preset |
| `ui/screens/goals/components/DhikrHeaderCard.kt` | Reusable dhikr display with audio preview |
| `ui/screens/goals/components/PresetChipRow.kt` | 4 mutually exclusive preset chips |
| `ui/screens/goals/components/CountInputField.kt` | [−] [count] [+] stepper with quick-select pills |
| `ui/screens/goals/components/CreateGoalButton.kt` | Full-width CTA with loading state |
| `ui/screens/goals/components/WizardProgressBar.kt` | Dot-based step indicator |
| `ui/screens/goals/components/WizardNavRow.kt` | Back + Continue/Create bottom bar |
| `ui/screens/goals/QuickCreatePane.kt` | Quick Create screen content |
| `ui/screens/goals/GoalWizard.kt` | Wizard host with AnimatedContent step switching |
| `ui/screens/goals/steps/FrequencyStep.kt` | Frequency picker step |
| `ui/screens/goals/steps/TimingStep.kt` | Timing selection cards step |
| `ui/screens/goals/steps/TargetStep.kt` | Target count input step |
| `ui/screens/goals/steps/WhichPrayersStep.kt` | Prayer toggle chips step |
| `ui/screens/goals/steps/DeadlineStep.kt` | Optional end date step |
| `ui/screens/goals/steps/ExtrasStep.kt` | Duration, min streak, notifications step |
| `test/.../ui/screens/goals/WizardStepComputerTest.kt` | Unit tests for step computation |
| `test/.../ui/screens/goals/model/TargetDraftTest.kt` | Unit tests for draft defaults |

### Modified Files

| File | Changes |
|------|---------|
| `ui/screens/goals/CreateGoalViewModel.kt` | Replace flat state with typed drafts, add mode management, wizard navigation |
| `ui/screens/goals/CreateGoalScreen.kt` | Replace ConfigureGoalStep with AnimatedContent switching QuickCreatePane/GoalWizard |

### Unchanged Files

GoalPreset.kt, GoalConfig.kt, FrequencyType.kt, TimingType.kt, TargetType.kt, DurationType.kt, Goal.kt, GoalSlot.kt, Prayer.kt, all DAOs, repositories, AwradNavGraph.kt, AwradDestination.kt.

---

## Task 1: Create Typed Draft Models

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/GoalCreationMode.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/WizardStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/FrequencyDraft.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/TargetDraft.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/ExtrasDraft.kt`

- [ ] **Step 1: Create GoalCreationMode sealed class**

```kotlin
// GoalCreationMode.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

sealed class GoalCreationMode {
    data object SelectDhikr : GoalCreationMode()
    data object QuickCreate : GoalCreationMode()
    data class Wizard(val stepIndex: Int = 0) : GoalCreationMode()
}
```

- [ ] **Step 2: Create WizardStep sealed class**

```kotlin
// WizardStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

sealed class WizardStep {
    data object Frequency : WizardStep()
    data object Timing : WizardStep()
    data object Target : WizardStep()
    data object WhichPrayers : WizardStep()
    data object Deadline : WizardStep()
    data object Extras : WizardStep()
}
```

- [ ] **Step 3: Create FrequencyDraft sealed class**

```kotlin
// FrequencyDraft.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import java.time.DayOfWeek

sealed class FrequencyDraft {
    data object Daily : FrequencyDraft()
    data class Weekly(val days: Set<DayOfWeek> = emptySet()) : FrequencyDraft()
    data class Monthly(
        val daysOfMonth: Set<Int> = emptySet(),
        val calendar: String = "gregorian",
    ) : FrequencyDraft()
    data class Interval(val intervalDays: String = "3") : FrequencyDraft()
    data class Yearly(
        val month: Int = 1,
        val days: Set<Int> = emptySet(),
        val calendar: String = "gregorian",
    ) : FrequencyDraft()
}
```

- [ ] **Step 4: Create TargetDraft sealed class**

```kotlin
// TargetDraft.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.PrayerTiming

sealed class TargetDraft {
    data object None : TargetDraft()
    data class Fixed(val count: String = "33") : TargetDraft()
    data class PrayerBased(
        val timing: PrayerTiming = PrayerTiming.AFTER,
        val selectedPrayers: Set<Prayer> = Prayer.entries.toSet(),
        val uniform: Boolean = true,
        val uniformCount: String = "33",
        val perPrayerCounts: Map<Prayer, String> = emptyMap(),
    ) : TargetDraft()
}
```

- [ ] **Step 5: Create ExtrasDraft data class**

```kotlin
// ExtrasDraft.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

data class ExtrasDraft(
    val hasDuration: Boolean = false,
    val durationDays: String = "",
    val hasMinStreak: Boolean = false,
    val minStreakCount: String = "",
    val notificationEnabled: Boolean = false,
    val notificationHour: Int = 8,
    val notificationMinute: Int = 0,
)
```

- [ ] **Step 6: Verify models compile**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -5`

Expected: BUILD SUCCESSFUL

- [ ] **Step 7: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/model/
git commit -m "feat: add typed draft models for goal creation redesign"
```

---

## Task 2: Create WizardStepComputer with Tests

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/WizardStepComputer.kt`
- Create: `app/src/test/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/WizardStepComputerTest.kt`

- [ ] **Step 1: Write the failing tests**

```kotlin
// WizardStepComputerTest.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.WizardStep
import org.junit.Assert.assertEquals
import org.junit.Test

class WizardStepComputerTest {

    @Test
    fun `DAILY preset produces Target and Extras steps`() {
        val steps = WizardStepComputer.compute(GoalPreset.DAILY, TimingType.ANYTIME)
        assertEquals(listOf(WizardStep.Target, WizardStep.Extras), steps)
    }

    @Test
    fun `PRAYER_BASED preset produces WhichPrayers, Target, and Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.PRAYER_BASED, TimingType.PRAYER_BASED)
        assertEquals(listOf(WizardStep.WhichPrayers, WizardStep.Target, WizardStep.Extras), steps)
    }

    @Test
    fun `ONE_TIME preset produces Target, Deadline, and Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.ONE_TIME, TimingType.ANYTIME)
        assertEquals(listOf(WizardStep.Target, WizardStep.Deadline, WizardStep.Extras), steps)
    }

    @Test
    fun `TRACKER preset produces only Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.TRACKER, TimingType.ANYTIME)
        assertEquals(listOf(WizardStep.Extras), steps)
    }

    @Test
    fun `ADV_WEEKLY preset produces Frequency, Timing, Target, Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.ADV_WEEKLY, TimingType.ANYTIME)
        assertEquals(
            listOf(WizardStep.Frequency, WizardStep.Timing, WizardStep.Target, WizardStep.Extras),
            steps,
        )
    }

    @Test
    fun `ADV_WEEKLY with PRAYER_BASED timing adds WhichPrayers step`() {
        val steps = WizardStepComputer.compute(GoalPreset.ADV_WEEKLY, TimingType.PRAYER_BASED)
        assertEquals(
            listOf(WizardStep.Frequency, WizardStep.Timing, WizardStep.WhichPrayers, WizardStep.Target, WizardStep.Extras),
            steps,
        )
    }

    @Test
    fun `ADV_TRACKER preset produces only Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.ADV_TRACKER, TimingType.ANYTIME)
        assertEquals(listOf(WizardStep.Extras), steps)
    }

    @Test
    fun `ADV_MONTHLY_HIJRI produces Frequency, Timing, Target, Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.ADV_MONTHLY_HIJRI, TimingType.ANYTIME)
        assertEquals(
            listOf(WizardStep.Frequency, WizardStep.Timing, WizardStep.Target, WizardStep.Extras),
            steps,
        )
    }

    @Test
    fun `ADV_INTERVAL produces Frequency, Timing, Target, Extras`() {
        val steps = WizardStepComputer.compute(GoalPreset.ADV_INTERVAL, TimingType.ANYTIME)
        assertEquals(
            listOf(WizardStep.Frequency, WizardStep.Timing, WizardStep.Target, WizardStep.Extras),
            steps,
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew testDebugUnitTest --tests "app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.WizardStepComputerTest" 2>&1 | tail -10`

Expected: FAIL — `WizardStepComputer` does not exist

- [ ] **Step 3: Implement WizardStepComputer**

```kotlin
// WizardStepComputer.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.WizardStep

object WizardStepComputer {

    fun compute(preset: GoalPreset, timingType: TimingType): List<WizardStep> = buildList {
        // Frequency: only when not DAILY
        if (preset.frequencyType != FrequencyType.DAILY) {
            add(WizardStep.Frequency)
        }
        // Timing: only for advanced presets that show the timing picker
        if (preset.showTimingPicker) {
            add(WizardStep.Timing)
        }
        // WhichPrayers: when timing is prayer-based (either from preset default or user choice)
        if (timingType == TimingType.PRAYER_BASED) {
            add(WizardStep.WhichPrayers)
        }
        // Target: absent for tracker presets
        if (preset.showTargetField) {
            add(WizardStep.Target)
        }
        // Deadline: only for one-time goals
        if (preset == GoalPreset.ONE_TIME) {
            add(WizardStep.Deadline)
        }
        // Extras: always present
        add(WizardStep.Extras)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew testDebugUnitTest --tests "app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.WizardStepComputerTest" 2>&1 | tail -10`

Expected: BUILD SUCCESSFUL, all 9 tests pass

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/WizardStepComputer.kt \
       app/src/test/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/WizardStepComputerTest.kt
git commit -m "feat: add WizardStepComputer with unit tests"
```

---

## Task 3: Rewrite CreateGoalViewModel with Typed State

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt`

This task replaces the flat `CreateGoalUiState` with typed sub-states and adds mode management. The `PrayerTiming` enum stays in this file. The `CreateGoalStep` enum is removed (replaced by `GoalCreationMode`).

- [ ] **Step 1: Replace CreateGoalUiState and CreateGoalStep**

Replace the entire `CreateGoalUiState` data class (lines 38-77) and `CreateGoalStep` enum (line 34) with:

```kotlin
data class CreateGoalUiState(
    // Search / dhikr selection
    val allDhikrs: List<Dhikr> = emptyList(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val searchQuery: String = "",
    val selectedDhikr: Dhikr? = null,
    // Navigation mode
    val mode: GoalCreationMode = GoalCreationMode.SelectDhikr,
    // Preset
    val selectedPreset: GoalPreset = GoalPreset.DAILY,
    // Typed sub-states
    val frequencyDraft: FrequencyDraft = FrequencyDraft.Daily,
    val timingType: TimingType = TimingType.ANYTIME,
    val targetDraft: TargetDraft = TargetDraft.Fixed(),
    val extras: ExtrasDraft = ExtrasDraft(),
    // Wizard steps (computed from preset + timingType)
    val wizardSteps: List<WizardStep> = emptyList(),
    // Status
    val isCreating: Boolean = false,
    val isCreated: Boolean = false,
    val validationError: String? = null,
)
```

Add imports at the top of the file:

```kotlin
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.WizardStep
```

- [ ] **Step 2: Replace ViewModel methods — navigation and preset**

Replace the `selectDhikr`, `selectPreset`, `toggleAdvanced`, `previousStep` methods, and the `init` block:

```kotlin
init {
    val dhikrId = savedStateHandle.get<Long>("dhikrId")?.takeIf { it != -1L }
    if (dhikrId != null) {
        viewModelScope.launch {
            val dhikr = dhikrRepository.getDhikrById(dhikrId)
            if (dhikr != null) {
                _state.value = _state.value.copy(
                    selectedDhikr = dhikr,
                    mode = GoalCreationMode.QuickCreate,
                )
            }
        }
    }
}

fun selectDhikr(dhikr: Dhikr) {
    _state.value = _state.value.copy(
        selectedDhikr = dhikr,
        mode = GoalCreationMode.QuickCreate,
    )
}

fun selectPreset(preset: GoalPreset) {
    val newTimingType = preset.defaultTimingType
    val newTargetDraft = when (preset.defaultTargetType) {
        TargetType.NONE -> TargetDraft.None
        TargetType.CUSTOM -> TargetDraft.PrayerBased()
        TargetType.FIXED -> TargetDraft.Fixed()
    }
    val newFrequencyDraft = when (preset.frequencyType) {
        FrequencyType.DAILY -> FrequencyDraft.Daily
        FrequencyType.WEEKLY -> FrequencyDraft.Weekly()
        FrequencyType.MONTHLY -> FrequencyDraft.Monthly(
            calendar = if (preset == GoalPreset.ADV_MONTHLY_HIJRI) "hijri" else "gregorian",
        )
        FrequencyType.INTERVAL -> FrequencyDraft.Interval()
        FrequencyType.YEARLY, FrequencyType.SPECIFIC_DATES -> FrequencyDraft.Yearly(
            calendar = if (preset == GoalPreset.ADV_YEARLY_HIJRI) "hijri" else "gregorian",
        )
    }
    _state.value = _state.value.copy(
        selectedPreset = preset,
        timingType = newTimingType,
        targetDraft = newTargetDraft,
        frequencyDraft = newFrequencyDraft,
    )
}

fun enterWizard() {
    val state = _state.value
    _state.value = state.copy(
        mode = GoalCreationMode.Wizard(stepIndex = 0),
        wizardSteps = WizardStepComputer.compute(state.selectedPreset, state.timingType),
    )
}

fun navigateBack(): Boolean {
    val state = _state.value
    return when (val mode = state.mode) {
        is GoalCreationMode.Wizard -> {
            if (mode.stepIndex > 0) {
                _state.value = state.copy(mode = mode.copy(stepIndex = mode.stepIndex - 1))
            } else {
                _state.value = state.copy(mode = GoalCreationMode.QuickCreate, wizardSteps = emptyList())
            }
            false // handled internally
        }
        is GoalCreationMode.QuickCreate -> {
            _state.value = state.copy(mode = GoalCreationMode.SelectDhikr)
            false
        }
        GoalCreationMode.SelectDhikr -> true // caller should popBackStack
    }
}

fun advanceWizard() {
    val state = _state.value
    val mode = state.mode as? GoalCreationMode.Wizard ?: return
    if (mode.stepIndex < state.wizardSteps.lastIndex) {
        _state.value = state.copy(mode = mode.copy(stepIndex = mode.stepIndex + 1))
    }
}
```

- [ ] **Step 3: Replace typed update methods**

Remove all the old flat setters (lines 155-239: `setTimingType`, `toggleWeekDay`, `toggleMonthDay`, `setSelectedMonth`, `toggleYearDay`, `setIntervalDays`, `setCalendarType`, `setTargetCount`, `setPrayerTiming`, `togglePrayer`, `setUniformPrayerCount`, `setUniformTargetCount`, `setPrayerCount`, `setHasDuration`, `setDurationDays`, `setNotificationEnabled`, `setNotificationTime`, `setHasMinStreak`, `setMinStreakCount`) and add:

```kotlin
// -- Frequency draft updates --

fun updateFrequencyDraft(draft: FrequencyDraft) {
    _state.value = _state.value.copy(frequencyDraft = draft)
}

// -- Timing updates --

fun updateTimingType(timing: TimingType) {
    val state = _state.value
    val newTargetDraft = when (timing) {
        TimingType.PRAYER_BASED -> TargetDraft.PrayerBased()
        TimingType.ANYTIME, TimingType.TIME_BASED -> {
            val existingCount = when (val current = state.targetDraft) {
                is TargetDraft.Fixed -> current.count
                is TargetDraft.PrayerBased -> current.uniformCount
                TargetDraft.None -> "33"
            }
            TargetDraft.Fixed(existingCount)
        }
    }
    _state.value = state.copy(
        timingType = timing,
        targetDraft = newTargetDraft,
        wizardSteps = WizardStepComputer.compute(state.selectedPreset, timing),
    )
}

// -- Target draft updates --

fun updateTargetDraft(draft: TargetDraft) {
    _state.value = _state.value.copy(targetDraft = draft)
}

// -- Extras updates --

fun updateExtras(extras: ExtrasDraft) {
    _state.value = _state.value.copy(extras = extras)
}
```

- [ ] **Step 4: Update createGoal(), buildSlots(), buildConfig(), buildPrayerSlots()**

Replace the existing `createGoal()` (lines 248-290), `buildSlots()` (lines 297-309), `buildConfig()` (lines 311-330), and `buildPrayerSlots()` (lines 332-355) with:

```kotlin
fun createGoal() {
    val state = _state.value
    val dhikr = state.selectedDhikr ?: return
    _state.value = state.copy(isCreating = true)

    viewModelScope.launch {
        val preset = state.selectedPreset
        val extras = state.extras
        val durationDays = when {
            preset == GoalPreset.ONE_TIME -> 1
            extras.hasDuration -> extras.durationDays.toIntOrNull()
            else -> null
        }
        val slots = buildSlots(state)
        val config = buildConfig(state.frequencyDraft)
        val minimumCount = if (extras.hasMinStreak) extras.minStreakCount.toIntOrNull() else null

        val targetType = when (state.timingType) {
            TimingType.PRAYER_BASED, TimingType.TIME_BASED -> TargetType.CUSTOM
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
            notificationEnabled = extras.notificationEnabled,
            notificationHour = if (extras.notificationEnabled) extras.notificationHour else null,
            notificationMinute = if (extras.notificationEnabled) extras.notificationMinute else null,
        )
        val goalId = goalRepository.createGoal(goal)
        if (extras.notificationEnabled) {
            scheduler.scheduleForGoal(goal.copy(id = goalId))
        }
        _state.value = _state.value.copy(isCreating = false, isCreated = true)
    }
}

private fun buildSlots(state: CreateGoalUiState): List<GoalSlot> {
    return when (val target = state.targetDraft) {
        is TargetDraft.None -> emptyList()
        is TargetDraft.Fixed -> {
            val count = target.count.toIntOrNull() ?: 33
            listOf(GoalSlot(goalId = 0, targetCount = count, timingType = SlotTimingTypes.ANYTIME))
        }
        is TargetDraft.PrayerBased -> buildPrayerSlots(target)
    }
}

private fun buildConfig(draft: FrequencyDraft): GoalConfig? {
    return when (draft) {
        is FrequencyDraft.Daily -> null
        is FrequencyDraft.Weekly -> GoalConfig.Weekly(
            days = draft.days.sortedBy { it.value }.map { it.name.take(3) },
        )
        is FrequencyDraft.Monthly -> GoalConfig.Monthly(
            daysOfMonth = draft.daysOfMonth.sorted(),
            calendar = draft.calendar,
        )
        is FrequencyDraft.Interval -> GoalConfig.Interval(
            intervalDays = draft.intervalDays.toIntOrNull() ?: 3,
        )
        is FrequencyDraft.Yearly -> GoalConfig.Yearly(
            month = draft.month,
            days = draft.days.sorted(),
            calendar = draft.calendar,
        )
    }
}

private fun buildPrayerSlots(target: TargetDraft.PrayerBased): List<GoalSlot> {
    val slots = mutableListOf<GoalSlot>()
    var sortOrder = 0
    val prayers = Prayer.entries.filter { it in target.selectedPrayers }

    for (prayer in prayers) {
        val timings = when (target.timing) {
            PrayerTiming.BEFORE -> listOf("before")
            PrayerTiming.AFTER -> listOf("after")
            PrayerTiming.BOTH -> listOf("before", "after")
        }
        for (timing in timings) {
            val timingValue = "${timing}_${prayer.name.lowercase()}"
            val label = "${timing.replaceFirstChar { it.uppercase() }} ${prayer.name.lowercase().replaceFirstChar { it.uppercase() }}"
            val count = if (target.uniform) {
                target.uniformCount.toIntOrNull() ?: 33
            } else {
                target.perPrayerCounts[prayer]?.toIntOrNull() ?: 33
            }
            slots.add(
                GoalSlot(
                    goalId = 0,
                    timingType = SlotTimingTypes.PRAYER,
                    timingValue = timingValue,
                    label = label,
                    targetCount = count,
                    sortOrder = sortOrder++,
                )
            )
        }
    }
    return slots
}
```

- [ ] **Step 5: Verify ViewModel compiles**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -10`

Expected: Compile errors in CreateGoalScreen.kt (expected — it still references old state fields). The ViewModel itself should have no errors.

- [ ] **Step 6: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt
git commit -m "feat: rewrite CreateGoalViewModel with typed draft state and wizard navigation"
```

---

## Task 4: Create Reusable UI Components

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/DhikrHeaderCard.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/PresetChipRow.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/CountInputField.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/CreateGoalButton.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/WizardProgressBar.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/WizardNavRow.kt`

- [ ] **Step 1: Create DhikrHeaderCard**

```kotlin
// DhikrHeaderCard.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

@Composable
fun DhikrHeaderCard(
    dhikr: Dhikr,
    audioState: PreviewPlaybackState,
    onTogglePlayback: () -> Unit,
    collapsed: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val goldColor = MaterialTheme.colorScheme.tertiary

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            // Gold left border stripe
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(if (collapsed) 80.dp else 160.dp)
                    .background(goldColor),
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = if (collapsed) 12.dp else 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Arabic text
                Text(
                    text = dhikr.arabic,
                    fontFamily = NotoNaskhArabicFontFamily,
                    fontSize = if (collapsed) 22.sp else 28.sp,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.fillMaxWidth(),
                )

                if (!collapsed) {
                    Spacer(modifier = Modifier.height(8.dp))

                    // Transliteration
                    Text(
                        text = dhikr.transliteration,
                        style = MaterialTheme.typography.bodyMedium.copy(fontStyle = FontStyle.Italic),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        textAlign = TextAlign.Center,
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    // Translation/meaning
                    Text(
                        text = dhikr.translation,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        textAlign = TextAlign.Center,
                    )
                }

                Spacer(modifier = Modifier.height(if (collapsed) 8.dp else 12.dp))

                // Audio strip
                if (dhikr.audioUrl != null || dhikr.audioFileName != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                    ) {
                        FilledIconButton(
                            onClick = onTogglePlayback,
                            modifier = Modifier.size(36.dp),
                            colors = IconButtonDefaults.filledIconButtonColors(
                                containerColor = goldColor,
                            ),
                        ) {
                            Icon(
                                imageVector = if (audioState.isPlaying && audioState.dhikrId == dhikr.id) {
                                    Icons.Default.Pause
                                } else {
                                    Icons.Default.PlayArrow
                                },
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        LinearProgressIndicator(
                            progress = {
                                if (audioState.dhikrId == dhikr.id) audioState.progress else 0f
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(4.dp)
                                .clip(RoundedCornerShape(2.dp)),
                            color = goldColor,
                        )
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create PresetChipRow**

```kotlin
// PresetChipRow.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset

@Composable
fun PresetChipRow(
    selectedPreset: GoalPreset,
    onSelect: (GoalPreset) -> Unit,
    modifier: Modifier = Modifier,
) {
    val quickPresets = listOf(
        GoalPreset.DAILY to R.string.preset_daily,
        GoalPreset.PRAYER_BASED to R.string.preset_prayer_based,
        GoalPreset.ONE_TIME to R.string.preset_one_time,
        GoalPreset.TRACKER to R.string.preset_tracker,
    )

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        quickPresets.forEach { (preset, labelRes) ->
            val selected = selectedPreset == preset
            val scale by animateFloatAsState(
                targetValue = if (selected) 1.04f else 1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessHigh,
                ),
                label = "PresetChipScale",
            )
            FilterChip(
                selected = selected,
                onClick = { onSelect(preset) },
                label = { Text(stringResource(labelRes)) },
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        }
    }
}
```

- [ ] **Step 3: Create CountInputField**

```kotlin
// CountInputField.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AssistChip
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CountInputField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    quickValues: List<Int> = listOf(33, 100, 1000),
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            FilledIconButton(
                onClick = {
                    val current = value.toIntOrNull() ?: 0
                    if (current > 1) onValueChange((current - 1).toString())
                },
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Decrease")
            }
            Spacer(modifier = Modifier.width(12.dp))
            OutlinedTextField(
                value = value,
                onValueChange = { newValue ->
                    if (newValue.isEmpty() || newValue.all { it.isDigit() }) {
                        onValueChange(newValue)
                    }
                },
                modifier = Modifier.width(120.dp),
                textStyle = MaterialTheme.typography.headlineSmall.copy(textAlign = TextAlign.Center),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
            )
            Spacer(modifier = Modifier.width(12.dp))
            FilledIconButton(
                onClick = {
                    val current = value.toIntOrNull() ?: 0
                    onValueChange((current + 1).toString())
                },
            ) {
                Icon(Icons.Default.Add, contentDescription = "Increase")
            }
        }
        if (quickValues.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                modifier = Modifier.fillMaxWidth(),
            ) {
                quickValues.forEach { qv ->
                    AssistChip(
                        onClick = { onValueChange(qv.toString()) },
                        label = { Text(qv.toString()) },
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create CreateGoalButton**

```kotlin
// CreateGoalButton.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R

@Composable
fun CreateGoalButton(
    onClick: () -> Unit,
    isLoading: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    labelRes: Int = R.string.create_goal,
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(16.dp),
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = MaterialTheme.colorScheme.onPrimary,
                strokeWidth = 2.dp,
            )
        } else {
            Text(
                text = stringResource(labelRes),
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
```

- [ ] **Step 5: Create WizardProgressBar**

```kotlin
// WizardProgressBar.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

@Composable
fun WizardProgressBar(
    currentStep: Int,
    totalSteps: Int,
    modifier: Modifier = Modifier,
) {
    val progress by animateFloatAsState(
        targetValue = (currentStep + 1).toFloat() / totalSteps.toFloat(),
        animationSpec = tween(durationMillis = 250, easing = FastOutSlowInEasing),
        label = "WizardProgress",
    )
    LinearProgressIndicator(
        progress = { progress },
        modifier = modifier
            .fillMaxWidth()
            .height(3.dp)
            .clip(RoundedCornerShape(2.dp)),
        color = MaterialTheme.colorScheme.tertiary,
        trackColor = MaterialTheme.colorScheme.surfaceVariant,
    )
}
```

- [ ] **Step 6: Create WizardNavRow**

```kotlin
// WizardNavRow.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R

@Composable
fun WizardNavRow(
    isFirstStep: Boolean,
    isFinalStep: Boolean,
    canAdvance: Boolean,
    isCreating: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (!isFirstStep) {
            TextButton(onClick = onBack) {
                Text(stringResource(R.string.wizard_back))
            }
        } else {
            // Spacer to keep Continue right-aligned
            TextButton(onClick = {}, enabled = false) { Text("") }
        }
        if (isFinalStep) {
            CreateGoalButton(
                onClick = onCreate,
                isLoading = isCreating,
                enabled = canAdvance,
                modifier = Modifier.weight(1f, fill = false),
            )
        } else {
            Button(
                onClick = onNext,
                enabled = canAdvance,
            ) {
                Text(stringResource(R.string.wizard_continue))
            }
        }
    }
}
```

- [ ] **Step 7: Add string resources**

Add these entries to `app/src/main/res/values/strings.xml`:

```xml
<!-- Goal creation redesign -->
<string name="preset_daily">Daily</string>
<string name="preset_prayer_based">Prayers</string>
<string name="preset_one_time">Once</string>
<string name="preset_tracker">Tracker</string>
<string name="create_goal">Create Goal</string>
<string name="how_would_you_practice">How would you like to practice this?</string>
<string name="how_many_each_day">How many times each day?</string>
<string name="times_per_prayer">Times per prayer</string>
<string name="total_count">Total count to complete</string>
<string name="no_target_message">Just counting — no target set.\nYour count will be recorded each session.</string>
<string name="customize_goal">Customize this goal</string>
<string name="wizard_back">Back</string>
<string name="wizard_continue">Continue</string>
<string name="customize_title">Customize Goal</string>
<string name="step_n_of_m">Step %1$d of %2$d</string>
```

Add corresponding entries to `values-ar/strings.xml`:

```xml
<string name="preset_daily">يومي</string>
<string name="preset_prayer_based">الصلوات</string>
<string name="preset_one_time">مرة واحدة</string>
<string name="preset_tracker">عداد</string>
<string name="create_goal">إنشاء هدف</string>
<string name="how_would_you_practice">كيف تريد ممارسة هذا؟</string>
<string name="how_many_each_day">كم مرة كل يوم؟</string>
<string name="times_per_prayer">مرة لكل صلاة</string>
<string name="total_count">العدد الكلي للإكمال</string>
<string name="no_target_message">عد فقط — بدون هدف محدد.\nسيتم تسجيل عددك في كل جلسة.</string>
<string name="customize_goal">تخصيص هذا الهدف</string>
<string name="wizard_back">رجوع</string>
<string name="wizard_continue">متابعة</string>
<string name="customize_title">تخصيص الهدف</string>
<string name="step_n_of_m">الخطوة %1$d من %2$d</string>
```

Add corresponding entries to `values-ml/strings.xml`:

```xml
<string name="preset_daily">ദൈനംദിനം</string>
<string name="preset_prayer_based">നമസ്കാരം</string>
<string name="preset_one_time">ഒരിക്കൽ</string>
<string name="preset_tracker">ട്രാക്കർ</string>
<string name="create_goal">ലക്ഷ്യം സൃഷ്ടിക്കുക</string>
<string name="how_would_you_practice">ഇത് എങ്ങനെ അഭ്യസിക്കണം?</string>
<string name="how_many_each_day">ഓരോ ദിവസവും എത്ര തവണ?</string>
<string name="times_per_prayer">ഓരോ നമസ്കാരത്തിനും</string>
<string name="total_count">മൊത്തം എണ്ണം</string>
<string name="no_target_message">എണ്ണൽ മാത്രം — ലക്ഷ്യമില്ല.\nഓരോ സെഷനിലും നിങ്ങളുടെ എണ്ണം രേഖപ്പെടുത്തും.</string>
<string name="customize_goal">ഈ ലക്ഷ്യം ഇഷ്ടാനുസൃതമാക്കുക</string>
<string name="wizard_back">പിന്നോട്ട്</string>
<string name="wizard_continue">തുടരുക</string>
<string name="customize_title">ലക്ഷ്യം ഇഷ്ടാനുസൃതമാക്കുക</string>
<string name="step_n_of_m">ഘട്ടം %1$d / %2$d</string>
```

- [ ] **Step 8: Verify components compile**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -10`

Expected: Compile errors only in CreateGoalScreen.kt (not yet updated). Component files should compile.

- [ ] **Step 9: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/components/ \
       app/src/main/res/values/strings.xml \
       app/src/main/res/values-ar/strings.xml \
       app/src/main/res/values-ml/strings.xml
git commit -m "feat: add reusable UI components for goal creation redesign"
```

---

## Task 5: Create Wizard Step Composables

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/FrequencyStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/TimingStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/TargetStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/WhichPrayersStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/DeadlineStep.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/ExtrasStep.kt`

- [ ] **Step 1: Create FrequencyStep**

Extract and adapt from current `FrequencyDetailsForm()` (CreateGoalScreen.kt lines 559-699). This composable reads a `FrequencyDraft` and emits updates:

```kotlin
// FrequencyStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import java.time.DayOfWeek

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FrequencyStep(
    draft: FrequencyDraft,
    onUpdate: (FrequencyDraft) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.frequency_step_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.frequency_step_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Spacer(modifier = Modifier.height(16.dp))

        when (draft) {
            is FrequencyDraft.Weekly -> {
                Text(
                    text = stringResource(R.string.select_days),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    DayOfWeek.entries.forEach { day ->
                        FilterChip(
                            selected = day in draft.days,
                            onClick = {
                                val updated = draft.days.toMutableSet()
                                if (day in updated) updated.remove(day) else updated.add(day)
                                onUpdate(draft.copy(days = updated))
                            },
                            label = { Text(day.name.take(3)) },
                        )
                    }
                }
            }
            is FrequencyDraft.Monthly -> {
                Text(
                    text = stringResource(R.string.select_days_of_month),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(modifier = Modifier.height(8.dp))
                val maxDay = if (draft.calendar == "hijri") 30 else 31
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    (1..maxDay).forEach { day ->
                        FilterChip(
                            selected = day in draft.daysOfMonth,
                            onClick = {
                                val updated = draft.daysOfMonth.toMutableSet()
                                if (day in updated) updated.remove(day) else updated.add(day)
                                onUpdate(draft.copy(daysOfMonth = updated))
                            },
                            label = { Text("$day") },
                        )
                    }
                }
            }
            is FrequencyDraft.Interval -> {
                Text(
                    text = stringResource(R.string.every_n_days),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = draft.intervalDays,
                    onValueChange = { if (it.all { c -> c.isDigit() }) onUpdate(draft.copy(intervalDays = it)) },
                    label = { Text(stringResource(R.string.interval_days_label)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            is FrequencyDraft.Yearly -> {
                Text(
                    text = stringResource(R.string.select_month_and_days),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    (1..12).forEach { month ->
                        FilterChip(
                            selected = month == draft.month,
                            onClick = { onUpdate(draft.copy(month = month)) },
                            label = { Text("$month") },
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
                val maxDay = if (draft.calendar == "hijri") 30 else 31
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    (1..maxDay).forEach { day ->
                        FilterChip(
                            selected = day in draft.days,
                            onClick = {
                                val updated = draft.days.toMutableSet()
                                if (day in updated) updated.remove(day) else updated.add(day)
                                onUpdate(draft.copy(days = updated))
                            },
                            label = { Text("$day") },
                        )
                    }
                }
            }
            is FrequencyDraft.Daily -> {
                // No configuration needed for daily
                Text(
                    text = stringResource(R.string.daily_no_config),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}
```

- [ ] **Step 2: Create TimingStep**

```kotlin
// TimingStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType

@Composable
fun TimingStep(
    selectedTiming: TimingType,
    onSelect: (TimingType) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.timing_step_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.timing_step_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Spacer(modifier = Modifier.height(16.dp))

        val options = listOf(
            Triple(TimingType.ANYTIME, R.string.timing_anytime, R.string.timing_anytime_desc),
            Triple(TimingType.PRAYER_BASED, R.string.timing_prayer_based, R.string.timing_prayer_desc),
            Triple(TimingType.TIME_BASED, R.string.timing_time_based, R.string.timing_time_desc),
        )

        options.forEach { (timing, titleRes, descRes) ->
            val selected = selectedTiming == timing
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .clickable { onSelect(timing) },
                colors = CardDefaults.cardColors(
                    containerColor = if (selected) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                ),
                border = if (selected) {
                    BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
                } else {
                    BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                },
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = stringResource(titleRes),
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = stringResource(descRes),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create TargetStep**

```kotlin
// TargetStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CountInputField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft

@Composable
fun TargetStep(
    draft: TargetDraft,
    onUpdate: (TargetDraft) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.target_step_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(16.dp))

        when (draft) {
            is TargetDraft.Fixed -> {
                CountInputField(
                    value = draft.count,
                    onValueChange = { onUpdate(draft.copy(count = it)) },
                    label = stringResource(R.string.how_many_each_day),
                    quickValues = listOf(33, 100, 1000),
                )
            }
            is TargetDraft.PrayerBased -> {
                CountInputField(
                    value = draft.uniformCount,
                    onValueChange = { onUpdate(draft.copy(uniformCount = it)) },
                    label = stringResource(R.string.times_per_prayer),
                    quickValues = listOf(33, 100),
                )
            }
            is TargetDraft.None -> {
                Text(
                    text = stringResource(R.string.no_target_message),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}
```

- [ ] **Step 4: Create WhichPrayersStep**

```kotlin
// WhichPrayersStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WhichPrayersStep(
    draft: TargetDraft.PrayerBased,
    onUpdate: (TargetDraft.PrayerBased) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.which_prayers_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.which_prayers_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Spacer(modifier = Modifier.height(16.dp))

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Prayer.entries.forEach { prayer ->
                val selected = prayer in draft.selectedPrayers
                FilterChip(
                    selected = selected,
                    onClick = {
                        val updated = draft.selectedPrayers.toMutableSet()
                        if (selected) updated.remove(prayer) else updated.add(prayer)
                        onUpdate(draft.copy(selectedPrayers = updated))
                    },
                    label = {
                        Text(prayer.name.lowercase().replaceFirstChar { it.uppercase() })
                    },
                )
            }
        }
    }
}
```

- [ ] **Step 5: Create DeadlineStep**

```kotlin
// DeadlineStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft

@Composable
fun DeadlineStep(
    extras: ExtrasDraft,
    onUpdate: (ExtrasDraft) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.deadline_step_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.deadline_step_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.set_deadline),
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = extras.hasDuration,
                onCheckedChange = { onUpdate(extras.copy(hasDuration = it)) },
            )
        }

        if (extras.hasDuration) {
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = extras.durationDays,
                onValueChange = {
                    if (it.all { c -> c.isDigit() }) onUpdate(extras.copy(durationDays = it))
                },
                label = { Text(stringResource(R.string.duration_days_label)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
```

- [ ] **Step 6: Create ExtrasStep**

```kotlin
// ExtrasStep.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft

@Composable
fun ExtrasStep(
    extras: ExtrasDraft,
    showDuration: Boolean,
    onUpdate: (ExtrasDraft) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            text = stringResource(R.string.extras_step_title),
            style = MaterialTheme.typography.headlineSmall,
        )
        Spacer(modifier = Modifier.height(16.dp))

        // Duration section
        if (showDuration) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.set_duration),
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = extras.hasDuration,
                    onCheckedChange = { onUpdate(extras.copy(hasDuration = it)) },
                )
            }
            AnimatedVisibility(visible = extras.hasDuration) {
                OutlinedTextField(
                    value = extras.durationDays,
                    onValueChange = {
                        if (it.all { c -> c.isDigit() }) onUpdate(extras.copy(durationDays = it))
                    },
                    label = { Text(stringResource(R.string.duration_days_label)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(8.dp))
        }

        // Min streak section
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.min_streak),
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = extras.hasMinStreak,
                onCheckedChange = { onUpdate(extras.copy(hasMinStreak = it)) },
            )
        }
        AnimatedVisibility(visible = extras.hasMinStreak) {
            OutlinedTextField(
                value = extras.minStreakCount,
                onValueChange = {
                    if (it.all { c -> c.isDigit() }) onUpdate(extras.copy(minStreakCount = it))
                },
                label = { Text(stringResource(R.string.min_streak_count_label)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
        }

        Spacer(modifier = Modifier.height(8.dp))
        HorizontalDivider()
        Spacer(modifier = Modifier.height(8.dp))

        // Notifications section
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.notifications),
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = extras.notificationEnabled,
                onCheckedChange = { onUpdate(extras.copy(notificationEnabled = it)) },
            )
        }
        AnimatedVisibility(visible = extras.notificationEnabled) {
            Text(
                text = stringResource(
                    R.string.notification_time_display,
                    String.format("%02d:%02d", extras.notificationHour, extras.notificationMinute),
                ),
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
```

- [ ] **Step 7: Add remaining string resources**

Append to `app/src/main/res/values/strings.xml`:

```xml
<!-- Wizard step titles -->
<string name="frequency_step_title">How often?</string>
<string name="frequency_step_subtitle">Choose the rhythm for this dhikr</string>
<string name="timing_step_title">When during the day?</string>
<string name="timing_step_subtitle">Set a time anchor, or practice whenever feels right</string>
<string name="target_step_title">Your daily target</string>
<string name="which_prayers_title">Which prayers?</string>
<string name="which_prayers_subtitle">Select when you\'d like to do this dhikr</string>
<string name="deadline_step_title">Set an end date?</string>
<string name="deadline_step_subtitle">Give yourself a gentle deadline, or leave it open-ended</string>
<string name="extras_step_title">Additional settings</string>
<string name="set_deadline">Set a deadline</string>
<string name="set_duration">Set duration</string>
<string name="min_streak">Minimum streak count</string>
<string name="notifications">Notifications</string>
<string name="notification_time_display">Reminder at %1$s</string>
<string name="select_days">Select days</string>
<string name="select_days_of_month">Select days of the month</string>
<string name="every_n_days">Repeat every N days</string>
<string name="interval_days_label">Days</string>
<string name="select_month_and_days">Select month and days</string>
<string name="daily_no_config">Every day — no additional configuration needed</string>
<string name="duration_days_label">Number of days</string>
<string name="min_streak_count_label">Minimum count for streak</string>
<string name="timing_anytime">Anytime</string>
<string name="timing_anytime_desc">No specific time — practice whenever feels right</string>
<string name="timing_prayer_based">After a prayer</string>
<string name="timing_prayer_desc">Tie this dhikr to your daily prayers</string>
<string name="timing_time_based">At a specific time</string>
<string name="timing_time_desc">Set a specific time of day</string>
```

Append corresponding entries to `values-ar/strings.xml` and `values-ml/strings.xml` (same keys, translated values).

- [ ] **Step 8: Verify step composables compile**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -10`

Expected: Only CreateGoalScreen.kt errors remain.

- [ ] **Step 9: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/steps/ \
       app/src/main/res/values/strings.xml \
       app/src/main/res/values-ar/strings.xml \
       app/src/main/res/values-ml/strings.xml
git commit -m "feat: add wizard step composables for goal creation flow"
```

---

## Task 6: Create QuickCreatePane and GoalWizard

**Files:**
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/QuickCreatePane.kt`
- Create: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/GoalWizard.kt`

- [ ] **Step 1: Create QuickCreatePane**

```kotlin
// QuickCreatePane.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CountInputField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CreateGoalButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.DhikrHeaderCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.PresetChipRow
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft

@Composable
fun QuickCreatePane(
    dhikr: Dhikr,
    audioState: PreviewPlaybackState,
    selectedPreset: GoalPreset,
    targetDraft: TargetDraft,
    isCreating: Boolean,
    onTogglePlayback: () -> Unit,
    onPresetSelect: (GoalPreset) -> Unit,
    onTargetChange: (TargetDraft) -> Unit,
    onCreateClick: () -> Unit,
    onCustomizeClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        DhikrHeaderCard(
            dhikr = dhikr,
            audioState = audioState,
            onTogglePlayback = onTogglePlayback,
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = stringResource(R.string.how_would_you_practice),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )

        Spacer(modifier = Modifier.height(12.dp))

        PresetChipRow(
            selectedPreset = selectedPreset,
            onSelect = onPresetSelect,
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Context-aware target field with cross-fade
        AnimatedContent(
            targetState = targetDraft,
            transitionSpec = {
                (fadeIn(tween(200)) + slideInVertically { it / 8 }) togetherWith
                    (fadeOut(tween(150)) + slideOutVertically { -it / 8 })
            },
            label = "TargetFieldCrossfade",
        ) { draft ->
            when (draft) {
                is TargetDraft.Fixed -> {
                    val label = when (selectedPreset) {
                        GoalPreset.ONE_TIME -> stringResource(R.string.total_count)
                        else -> stringResource(R.string.how_many_each_day)
                    }
                    val quickValues = when (selectedPreset) {
                        GoalPreset.ONE_TIME -> listOf(100, 1000, 10000)
                        else -> listOf(33, 100, 1000)
                    }
                    CountInputField(
                        value = draft.count,
                        onValueChange = { onTargetChange(draft.copy(count = it)) },
                        label = label,
                        quickValues = quickValues,
                    )
                }
                is TargetDraft.PrayerBased -> {
                    CountInputField(
                        value = draft.uniformCount,
                        onValueChange = { onTargetChange(draft.copy(uniformCount = it)) },
                        label = stringResource(R.string.times_per_prayer),
                        quickValues = listOf(33, 100),
                    )
                }
                is TargetDraft.None -> {
                    Text(
                        text = stringResource(R.string.no_target_message),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(vertical = 16.dp),
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Customize link
        TextButton(
            onClick = onCustomizeClick,
            modifier = Modifier.align(Alignment.CenterHorizontally),
        ) {
            Text(
                text = stringResource(R.string.customize_goal) + " →",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f),
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Create button
        val canCreate = when (targetDraft) {
            is TargetDraft.None -> true
            is TargetDraft.Fixed -> (targetDraft.count.toIntOrNull() ?: 0) > 0
            is TargetDraft.PrayerBased -> (targetDraft.uniformCount.toIntOrNull() ?: 0) > 0
        }
        CreateGoalButton(
            onClick = onCreateClick,
            isLoading = isCreating,
            enabled = canCreate,
        )
    }
}
```

- [ ] **Step 2: Create GoalWizard**

```kotlin
// GoalWizard.kt
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.DhikrHeaderCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.WizardNavRow
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.WizardProgressBar
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.WizardStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.DeadlineStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.ExtrasStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.FrequencyStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.TargetStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.TimingStep
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.steps.WhichPrayersStep

@Composable
fun GoalWizard(
    dhikr: Dhikr,
    audioState: PreviewPlaybackState,
    wizardMode: GoalCreationMode.Wizard,
    steps: List<WizardStep>,
    selectedPreset: GoalPreset,
    frequencyDraft: FrequencyDraft,
    timingType: TimingType,
    targetDraft: TargetDraft,
    extras: ExtrasDraft,
    isCreating: Boolean,
    onTogglePlayback: () -> Unit,
    onFrequencyUpdate: (FrequencyDraft) -> Unit,
    onTimingUpdate: (TimingType) -> Unit,
    onTargetUpdate: (TargetDraft) -> Unit,
    onExtrasUpdate: (ExtrasDraft) -> Unit,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val currentStepIndex = wizardMode.stepIndex
    val currentStep = steps.getOrNull(currentStepIndex) ?: return
    val isFirstStep = currentStepIndex == 0
    val isFinalStep = currentStepIndex == steps.lastIndex

    // Track previous step index for animation direction
    var previousStepIndex by remember { mutableIntStateOf(currentStepIndex) }
    val isForward = currentStepIndex >= previousStepIndex
    previousStepIndex = currentStepIndex

    Column(modifier = modifier.fillMaxSize()) {
        // Header
        DhikrHeaderCard(
            dhikr = dhikr,
            audioState = audioState,
            onTogglePlayback = onTogglePlayback,
            collapsed = true,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        )

        // Progress
        WizardProgressBar(
            currentStep = currentStepIndex,
            totalSteps = steps.size,
            modifier = Modifier.padding(horizontal = 16.dp),
        )
        Text(
            text = stringResource(R.string.step_n_of_m, currentStepIndex + 1, steps.size),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.align(Alignment.End).padding(end = 16.dp, top = 4.dp),
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Step content with directional animation
        AnimatedContent(
            targetState = currentStepIndex,
            transitionSpec = {
                if (isForward) {
                    (slideInHorizontally { it } + fadeIn(tween(200))) togetherWith
                        (slideOutHorizontally { -it / 3 } + fadeOut(tween(150)))
                } else {
                    (slideInHorizontally { -it / 3 } + fadeIn(tween(200))) togetherWith
                        (slideOutHorizontally { it } + fadeOut(tween(150)))
                }
            },
            modifier = Modifier.weight(1f),
            label = "WizardStepContent",
        ) { stepIndex ->
            val step = steps.getOrNull(stepIndex) ?: return@AnimatedContent
            Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                when (step) {
                    WizardStep.Frequency -> FrequencyStep(
                        draft = frequencyDraft,
                        onUpdate = onFrequencyUpdate,
                    )
                    WizardStep.Timing -> TimingStep(
                        selectedTiming = timingType,
                        onSelect = onTimingUpdate,
                    )
                    WizardStep.Target -> TargetStep(
                        draft = targetDraft,
                        onUpdate = onTargetUpdate,
                    )
                    WizardStep.WhichPrayers -> {
                        val prayerDraft = targetDraft as? TargetDraft.PrayerBased ?: TargetDraft.PrayerBased()
                        WhichPrayersStep(
                            draft = prayerDraft,
                            onUpdate = { onTargetUpdate(it) },
                        )
                    }
                    WizardStep.Deadline -> DeadlineStep(
                        extras = extras,
                        onUpdate = onExtrasUpdate,
                    )
                    WizardStep.Extras -> ExtrasStep(
                        extras = extras,
                        showDuration = selectedPreset != GoalPreset.ONE_TIME,
                        onUpdate = onExtrasUpdate,
                    )
                }
            }
        }

        // Navigation row
        WizardNavRow(
            isFirstStep = isFirstStep,
            isFinalStep = isFinalStep,
            canAdvance = true, // validation can be added per-step
            isCreating = isCreating,
            onBack = onBack,
            onNext = onNext,
            onCreate = onCreate,
        )
    }
}
```

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -10`

Expected: Only CreateGoalScreen.kt errors remain.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/QuickCreatePane.kt \
       app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/GoalWizard.kt
git commit -m "feat: add QuickCreatePane and GoalWizard composables"
```

---

## Task 7: Rewrite CreateGoalScreen to Wire Everything Together

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt`

This is the final integration task. Replace the existing `ConfigureGoalStep`, `FrequencyDetailsForm`, `PrayerBasedForm`, and `isFormValid` with the new `AnimatedContent`-based mode switching.

- [ ] **Step 1: Rewrite CreateGoalScreen**

Replace the entire file content. Keep `SelectDhikrStep` mostly as-is (it's the dhikr selection list). Replace everything else:

```kotlin
package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.EaseInOutCubic
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateGoalScreen(
    onGoalCreated: () -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: CreateGoalViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val audioState by viewModel.audioState.collectAsStateWithLifecycle()

    LaunchedEffect(uiState.isCreated) {
        if (uiState.isCreated) onGoalCreated()
    }

    BackHandler(enabled = uiState.mode != GoalCreationMode.SelectDhikr) {
        val shouldExit = viewModel.navigateBack()
        if (shouldExit) onNavigateBack()
    }

    val title = when (uiState.mode) {
        GoalCreationMode.SelectDhikr -> stringResource(R.string.select_dhikr_title)
        GoalCreationMode.QuickCreate -> ""
        is GoalCreationMode.Wizard -> stringResource(R.string.customize_title)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = {
                        val shouldExit = viewModel.navigateBack()
                        if (shouldExit) onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        AnimatedContent(
            targetState = uiState.mode,
            transitionSpec = {
                val forward = when {
                    targetState is GoalCreationMode.Wizard && initialState is GoalCreationMode.QuickCreate -> true
                    targetState is GoalCreationMode.QuickCreate && initialState is GoalCreationMode.SelectDhikr -> true
                    else -> false
                }
                if (forward) {
                    (slideInHorizontally(tween(300, easing = EaseInOutCubic)) { it } +
                        fadeIn(tween(300))) togetherWith
                        (slideOutHorizontally(tween(300, easing = EaseInOutCubic)) { -it / 3 } +
                            fadeOut(tween(300)))
                } else {
                    (slideInHorizontally(tween(300, easing = EaseInOutCubic)) { -it / 3 } +
                        fadeIn(tween(300))) togetherWith
                        (slideOutHorizontally(tween(300, easing = EaseInOutCubic)) { it } +
                            fadeOut(tween(300)))
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            label = "GoalCreationMode",
        ) { mode ->
            when (mode) {
                GoalCreationMode.SelectDhikr -> {
                    SelectDhikrStep(
                        dhikrs = uiState.filteredDhikrs,
                        searchQuery = uiState.searchQuery,
                        onSearchChange = viewModel::onSearchQueryChange,
                        onSelect = viewModel::selectDhikr,
                    )
                }
                GoalCreationMode.QuickCreate -> {
                    val dhikr = uiState.selectedDhikr ?: return@AnimatedContent
                    QuickCreatePane(
                        dhikr = dhikr,
                        audioState = audioState,
                        selectedPreset = uiState.selectedPreset,
                        targetDraft = uiState.targetDraft,
                        isCreating = uiState.isCreating,
                        onTogglePlayback = viewModel::togglePlayback,
                        onPresetSelect = viewModel::selectPreset,
                        onTargetChange = viewModel::updateTargetDraft,
                        onCreateClick = viewModel::createGoal,
                        onCustomizeClick = viewModel::enterWizard,
                    )
                }
                is GoalCreationMode.Wizard -> {
                    val dhikr = uiState.selectedDhikr ?: return@AnimatedContent
                    GoalWizard(
                        dhikr = dhikr,
                        audioState = audioState,
                        wizardMode = mode,
                        steps = uiState.wizardSteps,
                        selectedPreset = uiState.selectedPreset,
                        frequencyDraft = uiState.frequencyDraft,
                        timingType = uiState.timingType,
                        targetDraft = uiState.targetDraft,
                        extras = uiState.extras,
                        isCreating = uiState.isCreating,
                        onTogglePlayback = viewModel::togglePlayback,
                        onFrequencyUpdate = viewModel::updateFrequencyDraft,
                        onTimingUpdate = viewModel::updateTimingType,
                        onTargetUpdate = viewModel::updateTargetDraft,
                        onExtrasUpdate = viewModel::updateExtras,
                        onBack = { viewModel.navigateBack() },
                        onNext = viewModel::advanceWizard,
                        onCreate = viewModel::createGoal,
                    )
                }
            }
        }
    }
}

@Composable
private fun SelectDhikrStep(
    dhikrs: List<Dhikr>,
    searchQuery: String,
    onSearchChange: (String) -> Unit,
    onSelect: (Dhikr) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize()) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchChange,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            placeholder = { Text(stringResource(R.string.search_dhikr)) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
        )

        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        ) {
            items(dhikrs, key = { it.id }) { dhikr ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clickable { onSelect(dhikr) },
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = dhikr.arabic,
                                fontFamily = NotoNaskhArabicFontFamily,
                                style = MaterialTheme.typography.titleMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = dhikr.transliteration,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                text = dhikr.title,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add missing string resource if needed**

Check if `R.string.select_dhikr_title` and `R.string.search_dhikr` already exist. If not, add to `values/strings.xml`:

```xml
<string name="select_dhikr_title">Select Dhikr</string>
<string name="search_dhikr">Search dhikr…</string>
```

- [ ] **Step 3: Verify full project compiles**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -20`

Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Run all existing tests**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew testDebugUnitTest 2>&1 | tail -10`

Expected: All tests pass (including new WizardStepComputerTest)

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt \
       app/src/main/res/values/strings.xml \
       app/src/main/res/values-ar/strings.xml \
       app/src/main/res/values-ml/strings.xml
git commit -m "feat: rewrite CreateGoalScreen with Quick Create + Adaptive Wizard flow"
```

---

## Task 8: Clean Up Old Code

**Files:**
- Modify: `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt`

- [ ] **Step 1: Remove dead code from ViewModel**

Verify these are no longer referenced anywhere in the project:
- `CreateGoalStep` enum (replaced by `GoalCreationMode`)
- `showAdvanced` field (no longer in state)
- `toggleAdvanced()` method

Search for any remaining references:

Run: `grep -rn "CreateGoalStep\|showAdvanced\|toggleAdvanced\|ConfigureGoalStep\|FrequencyDetailsForm\|PrayerBasedForm\|isFormValid" app/src/main/java/ 2>/dev/null`

Expected: No results (all references replaced).

If `CreateGoalStep` is still defined in the ViewModel file, remove it. The `PrayerTiming` enum should remain as it's used by `TargetDraft.PrayerBased`.

- [ ] **Step 2: Verify clean compile**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew compileDebugKotlin 2>&1 | tail -5`

Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Run all tests**

Run: `cd /Users/apple/AndroidStudioProjects/AwradDhikrGoalsTracker && ./gradlew testDebugUnitTest 2>&1 | tail -10`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "chore: remove dead code from old goal creation flow"
```
