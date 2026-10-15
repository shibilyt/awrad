package app.awrad.next.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import app.awrad.next.R
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import javax.inject.Inject

/** Stand-in until the first real home feature module exists. */
@Serializable
data object HomeDestination

@HiltViewModel
class HomePlaceholderViewModel @Inject constructor(
    private val status: OnboardingStatusStore,
) : ViewModel() {
    fun restartOnboarding(then: () -> Unit) {
        viewModelScope.launch {
            status.reset()
            then()
        }
    }
}

@Composable
fun HomePlaceholderRoute(
    onRestartOnboarding: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomePlaceholderViewModel = hiltViewModel(),
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .safeDrawingPadding()
                .padding(horizontal = 28.dp, vertical = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(R.string.home_placeholder_title),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.home_placeholder_body),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(24.dp))
            TextButton(onClick = { viewModel.restartOnboarding(onRestartOnboarding) }) {
                Text(text = stringResource(R.string.home_placeholder_restart))
            }
        }
    }
}
