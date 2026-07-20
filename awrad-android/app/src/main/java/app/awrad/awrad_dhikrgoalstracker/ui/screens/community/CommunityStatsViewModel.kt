package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStats
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStatsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CommunityStatsUiState(
    val isLoading: Boolean = true,
    val stats: CommunityStats? = null,
    val hasError: Boolean = false,
)

@HiltViewModel
class CommunityStatsViewModel @Inject constructor(
    private val repository: CommunityStatsRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(CommunityStatsUiState())
    val uiState: StateFlow<CommunityStatsUiState> = _uiState.asStateFlow()
    private var loadJob: Job? = null

    init {
        load(forceRefresh = false)
    }

    fun retry() = load(forceRefresh = true)

    fun refresh() = load(forceRefresh = true)

    private fun load(forceRefresh: Boolean) {
        if (loadJob?.isActive == true) return
        loadJob = viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, hasError = false) }
            runCatching { repository.getStats(forceRefresh) }
                .onSuccess { stats -> _uiState.value = CommunityStatsUiState(isLoading = false, stats = stats) }
                .onFailure { _uiState.update { it.copy(isLoading = false, hasError = true) } }
        }
    }
}
