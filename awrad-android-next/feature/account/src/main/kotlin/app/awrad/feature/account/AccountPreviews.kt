package app.awrad.feature.account

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewParameter
import androidx.compose.ui.tooling.preview.PreviewParameterProvider
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.InputProblem

/** One state per step, with the hints, errors and notices each can show. */
private class AccountStatePreviews : PreviewParameterProvider<AccountUiState> {
    override val values: Sequence<AccountUiState> = sequenceOf(
        AccountUiState(step = AccountStep.SIGN_IN, error = AccountError.InvalidCredentials),
        AccountUiState(
            step = AccountStep.REGISTER,
            email = "amina@example.com",
            password = "short",
            fieldProblems = setOf(InputProblem.PASSWORD_TOO_SHORT),
        ),
        AccountUiState(
            step = AccountStep.VERIFY_EMAIL,
            email = "amina@example.com",
            notice = AccountNotice.CODE_SENT,
            resendCooldownSeconds = 42,
        ),
        AccountUiState(step = AccountStep.FORGOT_PASSWORD, email = "amina@example.com"),
        AccountUiState(step = AccountStep.RESET_PASSWORD, email = "amina@example.com", isBusy = true),
        AccountUiState(step = AccountStep.SIGN_IN, notice = AccountNotice.SESSION_ENDED),
        AccountUiState(step = AccountStep.SIGN_IN, notice = AccountNotice.ACCOUNT_DELETED),
    )
}

@Preview(showBackground = true)
@Composable
private fun AccountScreenPreview(@PreviewParameter(AccountStatePreviews::class) state: AccountUiState) {
    AwradTheme {
        AccountScreen(state = state, onAction = {}, onBack = {})
    }
}

@Preview(showBackground = true, locale = "ar")
@Composable
private fun AccountScreenArabicPreview(@PreviewParameter(AccountStatePreviews::class) state: AccountUiState) {
    AwradTheme {
        AccountScreen(state = state, onAction = {}, onBack = {})
    }
}

@Preview(showBackground = true, locale = "ml")
@Composable
private fun AccountScreenMalayalamPreview(@PreviewParameter(AccountStatePreviews::class) state: AccountUiState) {
    AwradTheme {
        AccountScreen(state = state, onAction = {}, onBack = {})
    }
}
