package app.awrad.feature.account.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradPrimaryButton
import app.awrad.core.designsystem.motion.AwradContentSwap
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.BodyText
import app.awrad.feature.account.PasswordField
import app.awrad.feature.account.R
import app.awrad.feature.account.message
import app.awrad.feature.account.pageStatus

@Composable
internal fun ChangePasswordRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ChangePasswordViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    ChangePasswordScreen(state = state, onAction = viewModel::onAction, onBack = onBack, modifier = modifier)
}

/** Current and new password; after the change, a confirmation and Done. */
@Composable
internal fun ChangePasswordScreen(
    state: ChangePasswordUiState,
    onAction: (ChangePasswordAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AccountPage(
        title = stringResource(R.string.account_title_change_password),
        onBack = onBack,
        modifier = modifier,
        isBusy = state.isBusy,
        status = pageStatus(
            error = state.error?.message(),
            notice = R.string.account_notice_password_updated.takeIf { state.isDone },
        ),
    ) {
        // The form gives way to Done in place (`contentSwap`).
        AwradContentSwap(targetState = state.isDone, label = "changePasswordDone") { isDone ->
            if (isDone) {
                AwradPrimaryButton(text = stringResource(R.string.account_action_done), onClick = onBack)
            } else {
                ChangePasswordForm(state = state, onAction = onAction)
            }
        }
    }
}

@Composable
private fun ChangePasswordForm(
    state: ChangePasswordUiState,
    onAction: (ChangePasswordAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.lg)) {
        BodyText(text = stringResource(R.string.account_change_password_body))
        PasswordField(
            value = state.currentPassword,
            problem = state.currentPasswordProblem,
            onValueChange = { onAction(ChangePasswordAction.CurrentPasswordChanged(it)) },
            label = R.string.account_field_current_password,
        )
        PasswordField(
            value = state.newPassword,
            problem = state.newPasswordProblem,
            onValueChange = { onAction(ChangePasswordAction.NewPasswordChanged(it)) },
            label = R.string.account_field_new_password,
            showRule = true,
        )
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_change_password),
            onClick = { onAction(ChangePasswordAction.Submit) },
            enabled = state.canSubmit,
        )
    }
}
