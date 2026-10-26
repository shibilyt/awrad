package app.awrad.feature.account

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/** Stateful entry point: owns the ViewModel and Back. Back inside the flow goes to the previous step. */
@Composable
internal fun AccountRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    BackHandler(enabled = state.canGoBack) { viewModel.onAction(AccountAction.Back) }
    AccountScreen(
        state = state,
        onAction = viewModel::onAction,
        onBack = { if (state.canGoBack) viewModel.onAction(AccountAction.Back) else onBack() },
        modifier = modifier,
    )
}

/** Stateless: renders [state] and reports every user intent through [onAction]. */
@Composable
internal fun AccountScreen(
    state: AccountUiState,
    onAction: (AccountAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        val step = state.step
        if (step == null) {
            Box(contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            return@Surface
        }
        Column(
            modifier = Modifier
                .safeDrawingPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.account_action_back),
                )
            }
            Text(
                text = stringResource(step.title()),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            BusyIndicator(isBusy = state.isBusy)
            StatusMessage(state = state)
            StepContent(step = step, state = state, onAction = onAction)
        }
    }
}

@Composable
private fun StepContent(
    step: AccountStep,
    state: AccountUiState,
    onAction: (AccountAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    when (step) {
        AccountStep.SIGN_IN -> SignInForm(state, onAction, modifier)
        AccountStep.REGISTER -> RegisterForm(state, onAction, modifier)
        AccountStep.VERIFY_EMAIL -> VerifyEmailForm(state, onAction, modifier)
        AccountStep.FORGOT_PASSWORD -> ForgotPasswordForm(state, onAction, modifier)
        AccountStep.RESET_PASSWORD -> ResetPasswordForm(state, onAction, modifier)
        AccountStep.SIGNED_IN -> SignedInContent(state, onAction, modifier)
    }
}

/** Keeps its height while idle, so the form doesn't jump when a request starts. */
@Composable
private fun BusyIndicator(isBusy: Boolean, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth().height(4.dp)) {
        if (isBusy) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    }
}

/** The error of the last request, or else the latest notice. Announced by screen readers. */
@Composable
private fun StatusMessage(state: AccountUiState, modifier: Modifier = Modifier) {
    val error = state.error
    val notice = state.notice
    val (text, color) = when {
        error != null -> stringResource(error.message()) to MaterialTheme.colorScheme.error
        notice != null -> stringResource(notice.message()) to MaterialTheme.colorScheme.secondary
        else -> return
    }
    Text(
        text = text,
        modifier = modifier.semantics { liveRegion = LiveRegionMode.Polite },
        style = MaterialTheme.typography.bodyMedium,
        color = color,
    )
}
