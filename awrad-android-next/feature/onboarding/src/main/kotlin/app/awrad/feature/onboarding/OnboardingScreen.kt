package app.awrad.feature.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradLogoMark
import app.awrad.core.designsystem.component.AwradPrimaryButton
import app.awrad.core.designsystem.theme.AwradTheme

/** Stateful entry point: owns the ViewModel and the exit side effect, nothing else. */
@Composable
internal fun OnboardingRoute(
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val currentOnFinish by rememberUpdatedState(onFinish)
    LaunchedEffect(state.isFinished) {
        if (state.isFinished) currentOnFinish()
    }
    OnboardingScreen(state = state, onAction = viewModel::onAction, modifier = modifier)
}

/** Stateless: renders [state] and reports every user intent through [onAction]. */
@Composable
internal fun OnboardingScreen(
    state: OnboardingUiState,
    onAction: (OnboardingAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .safeDrawingPadding()
                .padding(horizontal = 28.dp, vertical = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            AwradLogoMark(modifier = Modifier.size(148.dp))
            Spacer(modifier = Modifier.height(28.dp))
            Text(
                text = stringResource(R.string.onboarding_placeholder_title),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(40.dp))
            AwradPrimaryButton(
                text = stringResource(R.string.onboarding_placeholder_action),
                onClick = { onAction(OnboardingAction.GetStarted) },
                enabled = !state.isFinishing,
            )
        }
    }
}

@Preview
@Composable
private fun OnboardingScreenPreview() {
    AwradTheme {
        OnboardingScreen(state = OnboardingUiState(), onAction = {})
    }
}
