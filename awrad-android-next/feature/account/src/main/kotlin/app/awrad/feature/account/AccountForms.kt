package app.awrad.feature.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.component.AwradPrimaryButton
import java.util.Locale

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
            isNewPassword = true,
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
        ResendButton(state = state, onAction = onAction)
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
            isNewPassword = true,
            showRule = true,
        )
        AwradPrimaryButton(
            text = stringResource(R.string.account_action_reset_password),
            onClick = { onAction(AccountAction.Submit) },
            enabled = state.canSubmit,
        )
        ResendButton(state = state, onAction = onAction)
    }
}

@Composable
internal fun SignedInContent(state: AccountUiState, onAction: (AccountAction) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(FormSpacing)) {
        Text(
            text = stringResource(R.string.account_signed_in_as),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = state.account?.email.orEmpty(),
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.account_signed_in_body),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedButton(
            onClick = { onAction(AccountAction.SignOut) },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text(text = stringResource(R.string.account_action_sign_out), style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
private fun CodeSentTo(email: String, modifier: Modifier = Modifier) {
    Text(
        text = stringResource(R.string.account_code_sent_to, email.trim()),
        modifier = modifier,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

/** Sends a new code; waits out the cooldown after each code the server sent. */
@Composable
private fun ResendButton(state: AccountUiState, onAction: (AccountAction) -> Unit, modifier: Modifier = Modifier) {
    val seconds = state.resendCooldownSeconds
    TextButton(
        onClick = { onAction(AccountAction.ResendCode) },
        enabled = state.canResend,
        modifier = modifier.fillMaxWidth(),
    ) {
        Text(
            text = if (seconds > 0) {
                val clock = String.format(Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60)
                stringResource(R.string.account_action_resend_wait, clock)
            } else {
                stringResource(R.string.account_action_resend)
            },
        )
    }
}
