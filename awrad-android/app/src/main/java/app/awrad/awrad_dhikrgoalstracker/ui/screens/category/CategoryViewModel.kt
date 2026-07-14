package app.awrad.awrad_dhikrgoalstracker.ui.screens.category

import android.content.Context
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
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
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CategoryUiState(
    val categoryName: String = "",
    val categorySubtitle: String = "",
    val dhikrs: List<Dhikr> = emptyList(),
    val isLoading: Boolean = true,
)

@HiltViewModel
class CategoryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val dhikrRepository: DhikrRepository,
    val audioPlayer: AudioPreviewPlayer,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val categoryArg: String = checkNotNull(savedStateHandle["category"])
    private val category: DhikrCategory = DhikrCategory.valueOf(categoryArg)

    val playerState: StateFlow<PreviewPlaybackState> = audioPlayer.state

    private val _downloadingIds = MutableStateFlow<Set<AwradId>>(emptySet())
    val downloadingIds: StateFlow<Set<AwradId>> = _downloadingIds.asStateFlow()

    val uiState: StateFlow<CategoryUiState> =
        dhikrRepository.getDhikrsByCategory(category)
            .map { dhikrs ->
                CategoryUiState(
                    categoryName = getCategoryDisplayName(category),
                    categorySubtitle = getCategorySubtitle(category),
                    dhikrs = dhikrs,
                    isLoading = false,
                )
            }
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = CategoryUiState(
                    categoryName = getCategoryDisplayName(category),
                    categorySubtitle = getCategorySubtitle(category),
                ),
            )

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

    private fun getCategoryDisplayName(category: DhikrCategory): String =
        context.getString(category.toStringResId())

    private fun getCategorySubtitle(category: DhikrCategory): String = when (category) {
        DhikrCategory.MORNING -> "DAILY ESSENTIALS"
        DhikrCategory.EVENING -> "DAILY ESSENTIALS"
        DhikrCategory.AFTER_SALAH -> "POST-PRAYER"
        DhikrCategory.FORGIVENESS -> "REPENTANCE"
        DhikrCategory.PRAISE -> "GLORIFICATION"
        DhikrCategory.PROTECTION -> "REFUGE & SAFETY"
        DhikrCategory.GENERAL -> "EVERYDAY DHIKR"
        DhikrCategory.SWALATHS -> "BLESSINGS UPON THE PROPHET"
        DhikrCategory.ASMA_UL_HUSNA -> context.getString(R.string.category_asma_ul_husna_subtitle)
        DhikrCategory.RAMADAN -> "BLESSED MONTH"
        DhikrCategory.QURAN -> "QURANIC VERSES"
    }
}
