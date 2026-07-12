package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ProgressSummary
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.notification.WirdReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

data class WirdPartRow(
    val part: WirdPart,
    val occasion: WirdOccasion,
    val progress: ProgressSummary,
    val isActiveToday: Boolean,
)

data class WirdDetailUiState(
    val wird: Wird? = null,
    val parts: List<WirdPartRow> = emptyList(),
    val aggregate: ProgressSummary = ProgressSummary(0, 0),
    val streak: Int = 0,
    val week: List<WirdEngine.DayActivity> = emptyList(),
    val todayPartId: String? = null,
    val isLoading: Boolean = true,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class WirdDetailViewModel @Inject constructor(
    private val repository: WirdLibraryRepository,
    private val engine: WirdEngine,
    private val reminderScheduler: WirdReminderScheduler,
    dateProvider: DateProvider,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val wirdId: String = checkNotNull(savedStateHandle["wirdId"])

    /** Turn the quick daily reminder on/off, keeping its existing time (or the default). */
    fun setReminderEnabled(enabled: Boolean) {
        val current = uiState.value.wird?.reminders?.firstOrNull { it.id == QUICK_REMINDER_ID }
        saveReminder(enabled, current?.hour ?: DEFAULT_HOUR, current?.minute ?: DEFAULT_MINUTE)
    }

    /** Set (and enable) the quick daily reminder time. */
    fun setReminderTime(hour: Int, minute: Int) = saveReminder(true, hour, minute)

    private fun saveReminder(enabled: Boolean, hour: Int, minute: Int) {
        val wird = uiState.value.wird ?: return
        viewModelScope.launch {
            val reminders = if (enabled) {
                listOf(
                    WirdReminder(
                        id = QUICK_REMINDER_ID,
                        reminderType = ReminderType.FIXED_TIME,
                        hour = hour,
                        minute = minute,
                        enabled = true,
                    ),
                )
            } else {
                emptyList()
            }
            val saved = repository.setReminders(wird, reminders)
            // Cancel the prior alarm explicitly (schedule() only cancels reminders still present).
            reminderScheduler.cancel(wird.id, listOf(QUICK_REMINDER_ID))
            reminderScheduler.schedule(saved)
        }
    }

    val uiState: StateFlow<WirdDetailUiState> = dateProvider.effectiveToday.flatMapLatest { today ->
        val date = WirdEngine.parseDateKeyOrNull(today) ?: LocalDate.now()
        combine(
            repository.observeWird(wirdId),
            repository.observeAllSessions(wirdId),
        ) { wird, allSessions ->
            if (wird == null) return@combine WirdDetailUiState(isLoading = false)
            val todaySessions = allSessions.filter { it.dateKey == today }
            fun sessionFor(part: WirdPart) =
                todaySessions.firstOrNull {
                    it.partID == part.id && it.occasionKey == wird.occasionFor(part).key
                }

            val activeParts = engine.activeParts(wird, date)
            val activeIds = activeParts.map { it.id }.toSet()
            val todayPart = activeParts
                .firstOrNull { sessionFor(it)?.isComplete != true }
                ?: activeParts.firstOrNull()
            val rows = wird.parts.map { part ->
                WirdPartRow(
                    part = part,
                    occasion = wird.occasionFor(part),
                    progress = engine.progressSummary(part, sessionFor(part)),
                    isActiveToday = part.id in activeIds,
                )
            }
            WirdDetailUiState(
                wird = wird,
                parts = rows,
                aggregate = engine.aggregateProgress(wird, date) { sessionFor(it) },
                streak = engine.streak(wird, allSessions, date),
                week = engine.recentWeek(wird, allSessions, date),
                todayPartId = todayPart?.id,
                isLoading = false,
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), WirdDetailUiState())

    companion object {
        /** Stable id for the single user-set reminder managed from the detail screen. */
        const val QUICK_REMINDER_ID = "quick"
        private const val DEFAULT_HOUR = 7
        private const val DEFAULT_MINUTE = 0
    }
}
