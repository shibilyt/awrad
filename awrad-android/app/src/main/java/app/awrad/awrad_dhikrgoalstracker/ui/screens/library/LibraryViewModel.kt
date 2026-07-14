package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.service.AudioPreviewPlayer
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
    val availableCategories: List<DhikrCategory> = emptyList(),
    val categoryCounts: Map<DhikrCategory, Int> = emptyMap(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val groupedDhikrs: Map<DhikrCategory, List<Dhikr>> = emptyMap(),
    val isShowingAll: Boolean = true,
)

@HiltViewModel
class LibraryViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    val audioPlayer: AudioPreviewPlayer,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _searchQuery = MutableStateFlow("")
    private val _selectedCategory = MutableStateFlow<DhikrCategory?>(null)

    val playerState: StateFlow<PreviewPlaybackState> = audioPlayer.state

    private val _downloadingIds = MutableStateFlow<Set<AwradId>>(emptySet())
    val downloadingIds: StateFlow<Set<AwradId>> = _downloadingIds.asStateFlow()

    val uiState: StateFlow<LibraryUiState> = combine(
        _searchQuery,
        _selectedCategory,
        dhikrRepository.getAllDhikrs(),
    ) { query, category, allDhikrs ->
        val filtered = allDhikrs.filter { dhikr ->
            val matchesQuery = query.isBlank() ||
                dhikr.title.contains(query, ignoreCase = true) ||
                dhikr.transliteration.contains(query, ignoreCase = true) ||
                dhikr.translation.contains(query, ignoreCase = true) ||
                dhikr.arabic.contains(query)
            val matchesCategory = category == null || dhikr.category == category
            matchesQuery && matchesCategory
        }

        val isShowingAll = query.isBlank() && category == null
        val grouped = if (isShowingAll) {
            filtered.groupBy { it.category }
                .toSortedMap(compareBy { DhikrCategory.entries.indexOf(it) })
        } else {
            emptyMap()
        }
        val availableCategories = allDhikrs
            .map { it.category }
            .distinct()
            .sortedBy { DhikrCategory.entries.indexOf(it) }
        val categoryCounts = allDhikrs.groupBy { it.category }
            .mapValues { it.value.size }

        LibraryUiState(
            searchQuery = query,
            selectedCategory = category,
            availableCategories = availableCategories,
            categoryCounts = categoryCounts,
            filteredDhikrs = filtered,
            groupedDhikrs = grouped,
            isShowingAll = isShowingAll,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = LibraryUiState(),
    )

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
    }

    fun onCategorySelected(category: DhikrCategory?) {
        _selectedCategory.value = category
    }

    fun clearFilters() {
        _searchQuery.value = ""
        _selectedCategory.value = null
    }

    fun togglePlayback(dhikr: Dhikr) {
        audioPlayer.toggle(dhikr.id, dhikr.audioUrl, dhikr.audioFileName)
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
