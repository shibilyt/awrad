package app.awrad.feature.account

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.feature.account.settings.SignedInArea

/**
 * Stateful entry point: owns the ViewModel and Back. Back inside the flow goes to the previous step. A
 * signed-in device gets the account area, with its own pages.
 */
@Composable
internal fun AccountRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val account = state.account
    if (state.step == AccountStep.SIGNED_IN && account != null) {
        SignedInArea(
            account = account,
            onSignOut = { viewModel.onAction(AccountAction.SignOut) },
            onExit = onBack,
            modifier = modifier,
        )
        return
    }
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
    val step = state.step
    if (step == null) {
        Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Box(contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        }
        return
    }
    AccountPage(
        title = stringResource(step.title()),
        onBack = onBack,
        modifier = modifier,
        isBusy = state.isBusy,
        status = pageStatus(error = state.error?.message(), notice = state.notice?.message()),
    ) {
        StepContent(step = step, state = state, onAction = onAction)
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
        // Shown by SignedInArea; reached here only for a moment without an account.
        AccountStep.SIGNED_IN -> Unit
    }
}
