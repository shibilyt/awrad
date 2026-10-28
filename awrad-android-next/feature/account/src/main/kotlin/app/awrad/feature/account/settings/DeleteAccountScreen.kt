package app.awrad.feature.account.settings

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.BodyText
import app.awrad.feature.account.ConfirmDialog
import app.awrad.feature.account.DeviceNote
import app.awrad.feature.account.PasswordField
import app.awrad.feature.account.R
import app.awrad.feature.account.message
import app.awrad.feature.account.pageStatus

@Composable
internal fun DeleteAccountRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: DeleteAccountViewModel = hiltViewModel(),
) {
    val state by viewModel.state
    DeleteAccountScreen(state = state, onAction = viewModel::onAction, onBack = onBack, modifier = modifier)
}

/**
 * Says plainly what deleting does (the account and server data go now, data on this device stays), asks
 * for the password, then confirms once more.
 */
@Composable
internal fun DeleteAccountScreen(
    state: DeleteAccountUiState,
    onAction: (DeleteAccountAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AccountPage(
        title = stringResource(R.string.account_title_delete),
        onBack = onBack,
        modifier = modifier,
        isBusy = state.isBusy,
        status = pageStatus(error = state.error?.message(), notice = null),
    ) {
        BodyText(text = stringResource(R.string.account_delete_what_goes))
        DeviceNote(text = stringResource(R.string.account_delete_what_stays))
        BodyText(text = stringResource(R.string.account_delete_sessions))
        PasswordField(
            value = state.password,
            problem = state.passwordProblem,
            onValueChange = { onAction(DeleteAccountAction.PasswordChanged(it)) },
            label = R.string.account_field_current_password,
        )
        AwradButton(
            variant = AwradButtonVariant.Error,
            text = stringResource(R.string.account_action_delete),
            onClick = { onAction(DeleteAccountAction.Submit) },
            enabled = state.canSubmit,
        )
        if (state.isConfirming) {
            ConfirmDialog(
                title = stringResource(R.string.account_delete_confirm_title),
                text = stringResource(R.string.account_delete_confirm_body),
                confirmLabel = stringResource(R.string.account_action_delete_confirm),
                onConfirm = { onAction(DeleteAccountAction.Confirm) },
                onDismiss = { onAction(DeleteAccountAction.Dismiss) },
                isDestructive = true,
            )
        }
    }
}
