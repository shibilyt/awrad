package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountPolicyUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountRuleMode
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountSetupUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalSlotCountPolicyUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateWarning
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupResult
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalCountSetupUseCase
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.LocalDate
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EditGoalUiState(
    val isLoading: Boolean = true,
    val goal: Goal? = null,
    val title: String = "",
    val progressCount: Long = 0L,
    val slotCounts: Map<Long, Long> = emptyMap(),
    val draft: EditGoalDraft = EditGoalDraft(),
    val originalDraft: EditGoalDraft = EditGoalDraft(),
    val validationErrors: List<GoalUpdateError> = emptyList(),
    val warnings: List<GoalUpdateWarning> = emptyList(),
    val isSaving: Boolean = false,
    val saveCompleted: Boolean = false,
    val saveFailed: Boolean = false,
) {
    val isDirty: Boolean get() = draft != originalDraft
    val canSave: Boolean get() = !isLoading && !isSaving && isDirty && validationErrors.isEmpty()
    val hasMultipleSessions: Boolean get() = draft.slots.size > 1
    val isLifetimeGoal: Boolean get() = goal?.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL
}

data class EditGoalDraft(
    val ruleMode: GoalCountRuleMode = GoalCountRuleMode.Target,
    val minimumCount: String = "",
    val targetCount: String = "100",
    val maximumCount: String = "",
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val autoCompleteOnTarget: Boolean = false,
    val slots: List<EditGoalSlotDraft> = emptyList(),
)

data class EditGoalSlotDraft(
    val slotId: Long,
    val title: String,
    val subtitle: String,
    val currentCount: Long,
    val minimumCount: String = "",
    val targetCount: String = "100",
    val maximumCount: String = "",
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
)

@HiltViewModel
class EditGoalViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val dateProvider: DateProvider,
    private val goalProgressUseCase: GoalProgressUseCase,
    private val updateGoalCountSetupUseCase: UpdateGoalCountSetupUseCase,
) : ViewModel() {

    private val goalId: Long = savedStateHandle["goalId"] ?: -1L

    private val _uiState = MutableStateFlow(EditGoalUiState())
    val uiState: StateFlow<EditGoalUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun onRuleModeChange(ruleMode: GoalCountRuleMode) {
        updateDraft { it.withRuleModeDefaults(ruleMode) }
    }

    fun onMinimumChange(value: String) {
        updateDraft { it.copy(minimumCount = value.onlyDigits()) }
    }

    fun onTargetChange(value: String) {
        updateDraft { it.copy(targetCount = value.onlyDigits()) }
    }

    fun onMaximumChange(value: String) {
        updateDraft { it.copy(maximumCount = value.onlyDigits()) }
    }

    fun onCapBehaviorChange(behavior: CountCapBehavior) {
        updateDraft { it.copy(capBehavior = behavior) }
    }

    fun onAutoCompleteChange(enabled: Boolean) {
        updateDraft { it.copy(autoCompleteOnTarget = enabled) }
    }

    fun onSlotMinimumChange(slotId: Long, value: String) {
        updateSlot(slotId) { it.copy(minimumCount = value.onlyDigits()) }
    }

    fun onSlotTargetChange(slotId: Long, value: String) {
        updateSlot(slotId) { it.copy(targetCount = value.onlyDigits()) }
    }

    fun onSlotMaximumChange(slotId: Long, value: String) {
        updateSlot(slotId) { it.copy(maximumCount = value.onlyDigits()) }
    }

    fun onSlotCapBehaviorChange(slotId: Long, behavior: CountCapBehavior) {
        updateSlot(slotId) { it.copy(capBehavior = behavior) }
    }

    fun onSaveResultConsumed() {
        _uiState.update { it.copy(saveCompleted = false, saveFailed = false) }
    }

    fun save() {
        val command = _uiState.value.toCommand() ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, saveFailed = false) }
            when (val result = updateGoalCountSetupUseCase(command)) {
                is UpdateGoalCountSetupResult.Updated -> {
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            saveCompleted = true,
                            originalDraft = it.draft,
                            warnings = result.updatedGoal.warnings,
                        )
                    }
                }
                is UpdateGoalCountSetupResult.Invalid -> {
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            saveFailed = true,
                            validationErrors = result.errors,
                        )
                    }
                }
            }
        }
    }

    private fun load() {
        viewModelScope.launch {
            val goal = goalRepository.getGoalById(goalId)
            if (goal == null) {
                _uiState.value = EditGoalUiState(isLoading = false)
                return@launch
            }
            val todayString = dateProvider.getEffectiveToday()
            val today = todayString.toLocalDateOr(LocalDate.now())
            val dhikr = goal.dhikr ?: dhikrRepository.getAllDhikrs().first().firstOrNull { it.id == goal.dhikrId }
            val dailyCounts = goalRepository.getDailyCountsByGoal().first()[goal.id].orEmpty()
            val progressCount = goalProgressUseCase.progressCountFor(goal, dailyCounts, today)
            val slotCounts = goalRepository.getSlotCountsForGoalAndDate(goal.id, todayString)
            val draft = goal.toEditDraft(slotCounts)
            _uiState.value = EditGoalUiState(
                isLoading = false,
                goal = goal,
                title = dhikr?.transliteration?.ifBlank { dhikr.title }.orEmpty().ifBlank { dhikr?.title.orEmpty() },
                progressCount = progressCount,
                slotCounts = slotCounts,
                draft = draft,
                originalDraft = draft,
            ).validated()
        }
    }

    private fun updateDraft(transform: (EditGoalDraft) -> EditGoalDraft) {
        _uiState.update { state ->
            state.copy(draft = transform(state.draft)).validated()
        }
    }

    private fun updateSlot(slotId: Long, transform: (EditGoalSlotDraft) -> EditGoalSlotDraft) {
        updateDraft { draft ->
            draft.copy(
                slots = draft.slots.map { slot ->
                    if (slot.slotId == slotId) transform(slot) else slot
                },
            )
        }
    }

    private fun EditGoalUiState.validated(): EditGoalUiState {
        val goal = goal ?: return this
        val command = toCommand() ?: return copy(validationErrors = listOf(GoalUpdateError.InvalidCountPolicy))
        return when (val result = GoalCountSetupUpdateFactory.update(goal, command)) {
            is GoalUpdateResult.Valid -> copy(
                validationErrors = emptyList(),
                warnings = result.validatedGoalUpdate.warnings,
            )
            is GoalUpdateResult.Invalid -> copy(
                validationErrors = result.errors,
                warnings = emptyList(),
            )
        }
    }

    private fun EditGoalUiState.toCommand(): UpdateGoalCountSetupCommand? {
        val goal = goal ?: return null
        return UpdateGoalCountSetupCommand(
            goalId = goal.id,
            ruleMode = draft.ruleMode,
            countPolicy = draft.toPolicy(),
            slotPolicies = if (draft.slots.size > 1) {
                draft.slots.map { slot ->
                    GoalSlotCountPolicyUpdate(
                        slotId = slot.slotId,
                        countPolicy = slot.toPolicy(draft.ruleMode),
                    )
                }
            } else {
                emptyList()
            },
            autoCompleteOnTarget = draft.autoCompleteOnTarget,
            currentProgressCount = progressCount,
            currentSlotCounts = slotCounts,
        )
    }

    private fun EditGoalDraft.toPolicy(): GoalCountPolicyUpdate =
        GoalCountPolicyUpdate(
            minimumCount = minimumCount.toPositiveIntOrNull(),
            targetCount = targetCount.toPositiveIntOrNull(),
            maximumCount = maximumCount.toPositiveIntOrNull(),
            capBehavior = capBehavior,
        )

    private fun EditGoalSlotDraft.toPolicy(ruleMode: GoalCountRuleMode): GoalCountPolicyUpdate =
        GoalCountPolicyUpdate(
            minimumCount = minimumCount.toPositiveIntOrNull(),
            targetCount = targetCount.toPositiveIntOrNull(),
            maximumCount = maximumCount.toPositiveIntOrNull(),
            capBehavior = if (ruleMode == GoalCountRuleMode.Exact) CountCapBehavior.BlockAtMaximum else capBehavior,
        )

    private fun Goal.toEditDraft(slotCounts: Map<Long, Long>): EditGoalDraft {
        val singleSlot = slots.singleOrNull()
        val minimum = singleSlot?.minimumCount ?: minimumStreakCount
        val target = singleSlot?.targetCount ?: slots.sumOf { it.targetCount ?: 0 }.takeIf { it > 0 }
        val maximum = singleSlot?.maximumCount ?: maximumCount
        val cap = singleSlot?.capBehavior ?: capBehavior
        val mode = inferRuleMode(targetPolicy, minimum, target, maximum, cap)
        return EditGoalDraft(
            ruleMode = mode,
            minimumCount = minimum.asText(),
            targetCount = target.asText(default = "100"),
            maximumCount = maximum.asText(),
            capBehavior = cap,
            autoCompleteOnTarget = targetPolicy == TargetPolicy.CUMULATIVE_TOTAL && autoCompleteOnTarget,
            slots = slots.sortedBy { it.sortOrder }.map { slot ->
                slot.toEditSlotDraft(mode, slotCounts[slot.id] ?: 0L)
            },
        ).withRuleModeDefaults(mode)
    }

    private fun GoalSlot.toEditSlotDraft(ruleMode: GoalCountRuleMode, currentCount: Long): EditGoalSlotDraft {
        val mode = inferRuleMode(
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            minimum = minimumCount,
            target = targetCount,
            maximum = maximumCount,
            cap = capBehavior,
        )
        val effectiveMode = if (ruleMode == GoalCountRuleMode.Tracker) GoalCountRuleMode.Tracker else mode
        return EditGoalSlotDraft(
            slotId = id,
            title = label?.takeIf { it.isNotBlank() } ?: defaultSlotTitle(),
            subtitle = timingSubtitle(),
            currentCount = currentCount,
            minimumCount = minimumCount.asText(),
            targetCount = targetCount.asText(default = "100"),
            maximumCount = maximumCount.asText(),
            capBehavior = capBehavior,
        ).withRuleModeDefaults(effectiveMode)
    }

}

private fun inferRuleMode(
    targetPolicy: TargetPolicy,
    minimum: Int?,
    target: Int?,
    maximum: Int?,
    cap: CountCapBehavior,
): GoalCountRuleMode =
    when {
        targetPolicy == TargetPolicy.NONE -> GoalCountRuleMode.Tracker
        target != null && maximum != null && target == maximum && cap == CountCapBehavior.BlockAtMaximum ->
            GoalCountRuleMode.Exact
        minimum != null && target != null && maximum != null -> GoalCountRuleMode.Bounded
        minimum != null && target != null && minimum < target -> GoalCountRuleMode.Stretch
        minimum != null && (target == null || target == minimum) -> GoalCountRuleMode.Minimum
        target != null -> GoalCountRuleMode.Target
        else -> GoalCountRuleMode.Target
    }

private fun EditGoalDraft.withRuleModeDefaults(mode: GoalCountRuleMode): EditGoalDraft {
    val normalized = copy(
        ruleMode = mode,
        minimumCount = when (mode) {
            GoalCountRuleMode.Minimum,
            GoalCountRuleMode.Stretch,
            GoalCountRuleMode.Bounded -> minimumCount.ifBlank { defaultMinimum(targetCount) }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Exact -> minimumCount
        },
        targetCount = when (mode) {
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch,
            GoalCountRuleMode.Bounded -> targetCount.ifBlank { "100" }
            GoalCountRuleMode.Exact -> maximumCount.ifBlank { targetCount.ifBlank { "100" } }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum -> targetCount
        },
        maximumCount = when (mode) {
            GoalCountRuleMode.Exact -> maximumCount.ifBlank { targetCount.ifBlank { "100" } }
            GoalCountRuleMode.Bounded -> maximumCount.ifBlank { defaultMaximum(targetCount) }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum,
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch -> maximumCount
        },
        capBehavior = when (mode) {
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum -> CountCapBehavior.AllowOverTarget
            GoalCountRuleMode.Exact -> CountCapBehavior.BlockAtMaximum
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch -> capBehavior.takeIf { it != CountCapBehavior.BlockAtMaximum }
                ?: CountCapBehavior.AllowOverTarget
            GoalCountRuleMode.Bounded -> capBehavior
        },
    )
    return normalized.copy(
        slots = normalized.slots.map { it.withRuleModeDefaults(mode) },
    )
}

private fun EditGoalSlotDraft.withRuleModeDefaults(mode: GoalCountRuleMode): EditGoalSlotDraft =
    copy(
        minimumCount = when (mode) {
            GoalCountRuleMode.Minimum,
            GoalCountRuleMode.Stretch,
            GoalCountRuleMode.Bounded -> minimumCount.ifBlank { defaultMinimum(targetCount) }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Exact -> minimumCount
        },
        targetCount = when (mode) {
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch,
            GoalCountRuleMode.Bounded -> targetCount.ifBlank { "100" }
            GoalCountRuleMode.Exact -> maximumCount.ifBlank { targetCount.ifBlank { "100" } }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum -> targetCount
        },
        maximumCount = when (mode) {
            GoalCountRuleMode.Exact -> maximumCount.ifBlank { targetCount.ifBlank { "100" } }
            GoalCountRuleMode.Bounded -> maximumCount.ifBlank { defaultMaximum(targetCount) }
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum,
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch -> maximumCount
        },
        capBehavior = when (mode) {
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum -> CountCapBehavior.AllowOverTarget
            GoalCountRuleMode.Exact -> CountCapBehavior.BlockAtMaximum
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch -> capBehavior.takeIf { it != CountCapBehavior.BlockAtMaximum }
                ?: CountCapBehavior.AllowOverTarget
            GoalCountRuleMode.Bounded -> capBehavior
        },
    )

private fun String.onlyDigits(): String = filter(Char::isDigit)

private fun String.toPositiveIntOrNull(): Int? =
    toIntOrNull()?.takeIf { it > 0 }

private fun Int?.asText(default: String = ""): String =
    this?.takeIf { it > 0 }?.toString() ?: default

private fun defaultMinimum(target: String): String =
    target.toIntOrNull()?.let { (it / 2).coerceAtLeast(1).toString() } ?: "1"

private fun defaultMaximum(target: String): String =
    target.toIntOrNull()?.let { (it * 2).coerceAtLeast(it).toString() } ?: "100"

private fun GoalSlot.defaultSlotTitle(): String =
    when (slotType) {
        GoalSlotType.ANYTIME -> "Anytime"
        GoalSlotType.PRAYER -> listOfNotNull(prayerRelation?.name?.lowercase(), prayerName?.name?.lowercase())
            .joinToString(" ")
            .replaceFirstChar { it.uppercase() }
            .ifBlank { "Prayer session" }
        GoalSlotType.TIME_WINDOW -> "Session ${sortOrder + 1}"
    }

private fun GoalSlot.timingSubtitle(): String =
    when (slotType) {
        GoalSlotType.ANYTIME -> ""
        GoalSlotType.PRAYER -> timingValue.orEmpty().replace('_', ' ')
        GoalSlotType.TIME_WINDOW -> {
            val start = startMinute ?: return ""
            val end = endMinute ?: return ""
            "${start.toClockText()}-${end.toClockText()}"
        }
    }

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    val suffix = if (hour24 < 12) "AM" else "PM"
    val hour12 = when (val normalized = hour24 % 12) {
        0 -> 12
        else -> normalized
    }
    return "%d:%02d %s".format(hour12, minute, suffix)
}
