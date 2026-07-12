package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ProgressSummary
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import java.time.LocalDate
import javax.inject.Inject

data class WirdListItem(
    val wird: Wird,
    val todayPart: WirdPart?,
    val occasion: WirdOccasion?,
    val progress: ProgressSummary,
    val isActiveToday: Boolean,
    val streak: Int = 0,
)

data class WirdListUiState(
    val custom: List<WirdListItem> = emptyList(),
    val library: List<WirdListItem> = emptyList(),
    val isLoading: Boolean = true,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class WirdListViewModel @Inject constructor(
    private val repository: WirdLibraryRepository,
    private val engine: WirdEngine,
    dateProvider: DateProvider,
) : ViewModel() {

    // Slug-based identity for bundled wirds — same approach as HomeViewModel so a reminder-flipped
    // isCustom on a built-in wird doesn't hide it from the Library section.
    private val bundledSlugs: StateFlow<Set<String>> = flow {
        emit(repository.bundledLibrarySlugs())
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    val uiState: StateFlow<WirdListUiState> = dateProvider.effectiveToday.flatMapLatest { today ->
        val date = WirdEngine.parseDateKeyOrNull(today) ?: LocalDate.now()
        combine(
            repository.observeWirds(),
            repository.observeSessionsOnDate(today),
            bundledSlugs,
        ) { wirds, sessions, catalogSlugs ->
            val streaks = HashMap<String, Int>(wirds.size)
            for (wird in wirds) {
                streaks[wird.id] = repository.streak(wird, today)
            }
            val items = wirds.map { wird ->
                val active = engine.activeParts(wird, date)
                fun sessionFor(part: WirdPart) = sessions.firstOrNull {
                    it.wirdID == wird.id &&
                        it.partID == part.id &&
                        it.occasionKey == wird.occasionFor(part).key
                }
                val todayPart = active.firstOrNull { sessionFor(it)?.isComplete != true }
                    ?: active.firstOrNull()
                val progress = engine.aggregateProgress(wird, date) { part ->
                    sessionFor(part)
                }
                WirdListItem(
                    wird = wird,
                    todayPart = todayPart,
                    occasion = todayPart?.let { wird.occasionFor(it) },
                    progress = progress,
                    isActiveToday = active.isNotEmpty(),
                    streak = streaks[wird.id] ?: 0,
                )
            }
            val isBundled: (WirdListItem) -> Boolean = { item ->
                if (catalogSlugs.isEmpty()) !item.wird.isCustom else item.wird.slug in catalogSlugs
            }
            WirdListUiState(
                custom = items.filterNot(isBundled).sortedBy { it.wird.sortOrder },
                library = items.filter(isBundled).sortedBy { it.wird.sortOrder },
                isLoading = false,
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), WirdListUiState())
}
