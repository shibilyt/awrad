package app.awrad.feature.library

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.LocalizedText
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.asDhikr
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/** "Your dhikrs": the user's own dhikrs, newest first, as the library lists dhikrs. Null until loaded. */
@HiltViewModel
internal class YourDhikrsViewModel @Inject constructor(customDhikrs: CustomDhikrRepository) : ViewModel() {
    val state: StateFlow<List<Dhikr>?> = customDhikrs.dhikrs
        .map { list -> list.map { it.asDhikr() } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), null)

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

/** The "Your dhikrs" collection page: a top bar with Back and the title, then the dhikrs, like any collection. */
@Composable
internal fun YourDhikrsRoute(
    onNavigate: (LibraryDestination) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: YourDhikrsViewModel = hiltViewModel(),
) {
    val dhikrs by viewModel.state.collectAsStateWithLifecycle()
    val title = stringResource(R.string.library_your_dhikrs)
    CollectionScreen(
        state = dhikrs?.let { CollectionUiState.Ready(Collection(YOUR_DHIKRS_KEY, LocalizedText(en = title), it)) }
            ?: CollectionUiState.Loading,
        onOpenDhikr = { onNavigate(LibraryDestination.Dhikr(it)) },
        onBack = onBack,
        modifier = modifier,
    )
}

/** Not a catalog key: "Your dhikrs" is the user's own, shown like a collection. */
private const val YOUR_DHIKRS_KEY = "your-dhikrs"
