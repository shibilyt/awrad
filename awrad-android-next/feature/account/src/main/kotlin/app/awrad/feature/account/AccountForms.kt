package app.awrad.feature.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.component.AwradPrimaryButton

/*
 * The form of each step. Stateless: every one renders AccountUiState and reports AccountActions.
 */

private val FormSpacing = 12.dp

@Composable
internal fun SignInForm(state: AccountUiState, onAction: (AccountAction) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        Text(
            text = stringResource(R.string.account_intro),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        EmailField(state.email, state.emailProblem, { onAction(AccountAction.EmailChanged(it)) })
        PasswordField(state.password, state.passwordProblem, { onAction(AccountAction.PasswordChanged(it)) })
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_sign_in),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
        TextButton(onClick = { onAction(AccountAction.GoToForgotPassword) }) {
            Text(text = stringResource(R.string.account_action_forgot_password))
        }
        TextButton(onClick = { onAction(AccountAction.GoToRegister) }) {
            Text(text = stringResource(R.string.account_action_go_register))
        }
    }
}

@Composable
internal fun RegisterForm(state: AccountUiState, onAction: (AccountAction) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        EmailField(state.email, state.emailProblem, { onAction(AccountAction.EmailChanged(it)) })
        PasswordField(
            value = state.password,
            problem = state.passwordProblem,
            onValueChange = { onAction(AccountAction.PasswordChanged(it)) },
            label = R.string.account_field_new_password,
            showRule = true,
        )
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_register),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
        TextButton(onClick = { onAction(AccountAction.GoToSignIn) }) {
            Text(text = stringResource(R.string.account_action_go_sign_in))
        }
    }
}

@Composable
internal fun VerifyEmailForm(state: AccountUiState, onAction: (AccountAction) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        CodeSentTo(email = state.email)
        CodeField(state.code, state.codeProblem, { onAction(AccountAction.CodeChanged(it)) })
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_verify),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
        ResendButton(
            secondsLeft = state.resendCooldownSeconds,
            enabled = state.canResend,
            onClick = { onAction(AccountAction.ResendCode) },
        )
    }
}

@Composable
internal fun ForgotPasswordForm(
    state: AccountUiState,
    onAction: (AccountAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        Text(
            text = stringResource(R.string.account_forgot_body),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        EmailField(state.email, state.emailProblem, { onAction(AccountAction.EmailChanged(it)) })
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_send_code),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
    }
}

@Composable
internal fun ResetPasswordForm(
    state: AccountUiState,
    onAction: (AccountAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        CodeSentTo(email = state.email)
        CodeField(state.code, state.codeProblem, { onAction(AccountAction.CodeChanged(it)) })
        PasswordField(
            value = state.password,
            problem = state.passwordProblem,
            onValueChange = { onAction(AccountAction.PasswordChanged(it)) },
            label = R.string.account_field_new_password,
            showRule = true,
        )
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_reset_password),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
        ResendButton(
            secondsLeft = state.resendCooldownSeconds,
            enabled = state.canResend,
            onClick = { onAction(AccountAction.ResendCode) },
        )
    }
}
