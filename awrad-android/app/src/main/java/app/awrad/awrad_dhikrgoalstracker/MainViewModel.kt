package app.awrad.awrad_dhikrgoalstracker

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

sealed interface MainUiState {
    data object Loading : MainUiState
    data class Ready(val isOnboarded: Boolean, val darkMode: Boolean? = null) : MainUiState
}

data class NotificationGoalEvent(
    val goalId: AwradId,
    val slotId: AwradId? = null,
)

@HiltViewModel
class MainViewModel @Inject constructor(
    userPreferences: UserPreferences,
) : ViewModel() {

    val uiState: StateFlow<MainUiState> = combine(
        userPreferences.isOnboarded,
        userPreferences.darkMode,
    ) { onboarded, darkMode ->
        MainUiState.Ready(isOnboarded = onboarded, darkMode = darkMode)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = MainUiState.Loading,
    )

    private val _notificationGoalEvents = Channel<NotificationGoalEvent>(capacity = Channel.BUFFERED)
    val notificationGoalEvents: Flow<NotificationGoalEvent> = _notificationGoalEvents.receiveAsFlow()

    fun onNotificationGoalId(goalId: AwradId, slotId: AwradId? = null) {
        _notificationGoalEvents.trySend(NotificationGoalEvent(goalId, slotId))
    }

    /** Wird navigation events from reminder taps + `awrad://` deep links. A null wirdId = the list. */
    private val _wirdNavEvents = Channel<String?>(capacity = Channel.BUFFERED)
    val wirdNavEvents: Flow<String?> = _wirdNavEvents.receiveAsFlow()

    fun onWirdDeepLink(wirdId: String?) {
        _wirdNavEvents.trySend(wirdId)
    }

    override fun onCleared() {
        super.onCleared()
        _notificationGoalEvents.close()
        _wirdNavEvents.close()
    }
}
