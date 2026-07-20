package app.awrad.awrad_dhikrgoalstracker.ui.sync

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncEngine
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

@HiltViewModel
class ProgressSyncRefreshViewModel @Inject constructor(
    private val engine: ProgressSyncEngine,
) : ViewModel() {
    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()

    fun refresh() {
        if (_isRefreshing.value) return
        _isRefreshing.value = true
        viewModelScope.launch {
            try {
                engine.synchronize()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                engine.recordFailure(error)
            } finally {
                _isRefreshing.value = false
            }
        }
    }
}
