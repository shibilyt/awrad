package app.awrad.feature.account.settings

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.motion.AwradContentSwap
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.BodyText
import app.awrad.feature.account.CodeField
import app.awrad.feature.account.CodeSentTo
import app.awrad.feature.account.EmailField
import app.awrad.feature.account.PasswordField
import app.awrad.feature.account.R
import app.awrad.feature.account.ResendButton
import app.awrad.feature.account.isolated
import app.awrad.feature.account.message
import app.awrad.feature.account.pageStatus

/** Back from the code step returns to the form; otherwise it leaves the page. */
@Composable
internal fun ChangeEmailRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ChangeEmailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val isOnCode = state.step == ChangeEmailStep.CODE
    BackHandler(enabled = isOnCode) { viewModel.onAction(ChangeEmailAction.EditEmail) }
    ChangeEmailScreen(
        state = state,
        onAction = viewModel::onAction,
        onBack = { if (isOnCode) viewModel.onAction(ChangeEmailAction.EditEmail) else onBack() },
        onFinish = onBack,
        modifier = modifier,
    )
}

@Composable
internal fun ChangeEmailScreen(
    state: ChangeEmailUiState,
    onAction: (ChangeEmailAction) -> Unit,
    onBack: () -> Unit,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val title = when (state.step) {
        ChangeEmailStep.CODE -> R.string.account_title_confirm_email
        ChangeEmailStep.FORM, ChangeEmailStep.DONE -> R.string.account_title_change_email
    }
    AccountPage(
        title = stringResource(title),
        onBack = onBack,
        modifier = modifier,
        isBusy = state.isBusy,
        status = pageStatus(
            error = state.error?.message(),
            notice = R.string.account_notice_code_sent.takeIf { state.isCodeSent },
        ),
    ) {
        // Each step replaces the last in place (`contentSwap`).
        AwradContentSwap(targetState = state.step, label = "changeEmailStep") { step ->
            when (step) {
                ChangeEmailStep.FORM -> EmailChangeForm(state = state, onAction = onAction)
                ChangeEmailStep.CODE -> EmailChangeCode(state = state, onAction = onAction)
                ChangeEmailStep.DONE -> Column(verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.lg)) {
                    val email = isolated(state.changedTo.orEmpty())
                    BodyText(text = stringResource(R.string.account_notice_email_changed, email))
                    AwradButton(text = stringResource(R.string.account_action_done), onClick = onFinish)
                }
            }
        }
    }
}

@Composable
private fun EmailChangeForm(
    state: ChangeEmailUiState,
    onAction: (ChangeEmailAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        BodyText(text = stringResource(R.string.account_change_email_body))
        EmailField(
            value = state.newEmail,
            problem = state.newEmailProblem,
            onValueChange = { onAction(ChangeEmailAction.NewEmailChanged(it)) },
            label = R.string.account_field_new_email,
        )
        PasswordField(
            value = state.currentPassword,
            problem = state.currentPasswordProblem,
            onValueChange = { onAction(ChangeEmailAction.CurrentPasswordChanged(it)) },
            label = R.string.account_field_current_password,
        )
        AwradButton(
            text = stringResource(R.string.account_action_send_code),
            onClick = { onAction(ChangeEmailAction.Submit) },
            enabled = state.canSubmit,
        )
    }
}

@Composable
private fun EmailChangeCode(
    state: ChangeEmailUiState,
    onAction: (ChangeEmailAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        CodeSentTo(email = state.newEmail)
        CodeField(state.code, state.codeProblem, { onAction(ChangeEmailAction.CodeChanged(it)) })
        AwradButton(
            text = stringResource(R.string.account_action_confirm_email),
            onClick = { onAction(ChangeEmailAction.Submit) },
            enabled = state.canSubmit,
        )
        ResendButton(
            secondsLeft = state.resendCooldownSeconds,
            enabled = state.canResend,
            onClick = { onAction(ChangeEmailAction.ResendCode) },
        )
        AwradTextButton(
            text = stringResource(R.string.account_action_use_other_email),
            onClick = { onAction(ChangeEmailAction.EditEmail) },
        )
    }
}
