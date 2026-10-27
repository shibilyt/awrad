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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.theme.AwradTheme
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
    onOpenAccount: () -> Unit,
    onRestartOnboarding: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomePlaceholderViewModel = hiltViewModel(),
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .safeDrawingPadding()
                .padding(horizontal = AwradTheme.spacing.pageMargin, vertical = AwradTheme.spacing.xl4),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(R.string.home_placeholder_title),
                style = AwradTheme.type.title,
            )
            Spacer(modifier = Modifier.height(AwradTheme.spacing.rowGap))
            Text(
                text = stringResource(R.string.home_placeholder_body),
                style = AwradTheme.type.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(AwradTheme.spacing.xl2))
            AwradButton(text = stringResource(R.string.home_placeholder_account), onClick = onOpenAccount)
            Spacer(modifier = Modifier.height(AwradTheme.spacing.inlineGap))
            AwradTextButton(
                text = stringResource(R.string.home_placeholder_restart),
                onClick = { viewModel.restartOnboarding(onRestartOnboarding) },
            )
        }
    }
}
