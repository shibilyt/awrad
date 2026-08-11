package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.service.AudioPreviewPlayer
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LibraryUiState(
    val searchQuery: String = "",
    val selectedCategory: DhikrCategory? = null,
    val customOnly: Boolean = false,
    val categoryCounts: Map<DhikrCategory, Int> = emptyMap(),
    val customCount: Int = 0,
    val allDhikrs: List<Dhikr> = emptyList(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val groupedDhikrs: Map<DhikrCategory, List<Dhikr>> = emptyMap(),
    val ownedAudioByDhikrId: Map<AwradId, String> = emptyMap(),
    val missingOwnedAudioIds: Set<AwradId> = emptySet(),
    val isShowingAll: Boolean = true,
    val hasActiveFilters: Boolean = false,
)

@HiltViewModel
class LibraryViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    val audioPlayer: AudioPreviewPlayer,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _searchQuery = MutableStateFlow("")
    private val _selectedCategory = MutableStateFlow<DhikrCategory?>(null)
    private val _customOnly = MutableStateFlow(false)
    private val _missingOwnedAudioIds = MutableStateFlow<Set<AwradId>>(emptySet())

    val playerState: StateFlow<PreviewPlaybackState> = audioPlayer.state

    private val _downloadingIds = MutableStateFlow<Set<AwradId>>(emptySet())
    val downloadingIds: StateFlow<Set<AwradId>> = _downloadingIds.asStateFlow()

    val uiState: StateFlow<LibraryUiState> = combine(
        combine(_searchQuery, _selectedCategory, _customOnly) { q, c, custom ->
            LibraryFilterCriteria(query = q, category = c, customOnly = custom)
        },
        dhikrRepository.getAllDhikrs(),
        combine(
            dhikrRepository.observeOwnedAudioByDhikrId(),
            _missingOwnedAudioIds,
        ) { owned, missing -> owned to missing },
    ) { criteria, allDhikrs, ownedAndMissing ->
        val (ownedById, missingOwned) = ownedAndMissing
        val items = allDhikrs.map { LibraryFilterItem(dhikr = it) }
        val filteredItems = LibraryFilterPolicy.filter(
            items = items,
            query = criteria.query,
            category = criteria.category,
            customOnly = criteria.customOnly,
        )
        val filtered = filteredItems.map { it.dhikr }
        val isShowingAll = !criteria.hasActiveFilters
        val grouped = if (isShowingAll) {
            filtered.groupBy { it.category }
                .toSortedMap(compareBy { DhikrCategory.entries.indexOf(it) })
        } else {
            emptyMap()
        }
        LibraryUiState(
            searchQuery = criteria.query,
            selectedCategory = criteria.category,
            customOnly = criteria.customOnly,
            categoryCounts = allDhikrs.groupBy { it.category }.mapValues { it.value.size },
            customCount = allDhikrs.count { it.isCustom },
            allDhikrs = allDhikrs,
            filteredDhikrs = filtered,
            groupedDhikrs = grouped,
            ownedAudioByDhikrId = ownedById.mapValues { it.value.relativeFileName },
            missingOwnedAudioIds = missingOwned,
            isShowingAll = isShowingAll,
            hasActiveFilters = criteria.hasActiveFilters,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = LibraryUiState(),
    )

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
    }

    fun onFeaturedCollectionSelected(category: DhikrCategory) {
        _customOnly.value = false
        _selectedCategory.value = category
    }

    fun onYourDhikrsSelected() {
        _customOnly.value = true
        _selectedCategory.value = null
    }

    fun clearFilters() {
        _searchQuery.value = ""
        _selectedCategory.value = null
        _customOnly.value = false
    }

    fun togglePlayback(dhikr: Dhikr) {
        viewModelScope.launch {
            val owned = dhikrRepository.getOwnedAudio(dhikr.id)
            if (owned != null) {
                if (dhikrRepository.ownedAudioAvailability(dhikr.id) == OwnedAudioAvailability.MISSING) {
                    _missingOwnedAudioIds.update { it + dhikr.id }
                    return@launch
                }
                _missingOwnedAudioIds.update { it - dhikr.id }
                audioPlayer.toggle(dhikr.id, dhikr.audioUrl, owned.relativeFileName)
                return@launch
            }
            audioPlayer.toggle(dhikr.id, dhikr.audioUrl, dhikr.audioFileName)
        }
    }

    fun downloadDhikrAudio(dhikr: Dhikr) {
        if (dhikr.isDownloaded || dhikr.audioUrl == null) return
        _downloadingIds.update { it + dhikr.id }
        viewModelScope.launch {
            dhikrRepository.downloadDhikrAudio(dhikr)
            _downloadingIds.update { it - dhikr.id }
        }
    }

    fun getCategoryDisplayName(category: DhikrCategory): String =
        context.getString(category.toStringResId())
}
