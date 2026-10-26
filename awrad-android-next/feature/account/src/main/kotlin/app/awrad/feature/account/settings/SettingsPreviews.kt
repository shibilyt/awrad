package app.awrad.feature.account.settings

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewParameter
import androidx.compose.ui.tooling.preview.PreviewParameterProvider
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.InputProblem
import java.time.Instant

/* Each signed-in page in English, Arabic (right to left) and Malayalam, and in English in the dark theme. */

private val Now = Instant.parse("2026-10-27T07:00:00Z")

private val Phone = AccountSession(
    id = AwradId("9a7d1c42-3e5b-4f60-8a19-0c2d4e6f8b13"),
    kind = AccountSession.Kind.DEVICE,
    name = "Google Pixel 9",
    platform = AccountSession.Platform.ANDROID,
    createdAt = Instant.parse("2026-10-26T08:05:00Z"),
    lastSeenAt = Now,
    isCurrent = true,
)

private val Sessions = listOf(
    Phone,
    Phone.copy(
        id = AwradId("4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"),
        kind = AccountSession.Kind.BROWSER,
        name = "Firefox on Windows",
        platform = AccountSession.Platform.WEB,
        lastSeenAt = Instant.parse("2026-10-27T06:12:00Z"),
        isCurrent = false,
    ),
    Phone.copy(
        id = AwradId("1f3b5d7e-9a2c-4e6f-8b1d-3c5e7a9b2d4f"),
        name = "iPhone 16 Pro",
        platform = AccountSession.Platform.IOS,
        lastSeenAt = Instant.parse("2026-10-20T18:00:00Z"),
        isCurrent = false,
    ),
    Phone.copy(
        id = AwradId("7e9a1c3b-5d2f-4a6e-8c1b-9d3f5a7c2e4b"),
        kind = AccountSession.Kind.BROWSER,
        name = null,
        platform = AccountSession.Platform.WEB,
        lastSeenAt = Instant.parse("2026-09-02T10:00:00Z"),
        isCurrent = false,
    ),
)

private class DevicesStates : PreviewParameterProvider<DevicesUiState> {
    override val values = sequenceOf(
        DevicesUiState(sessions = Sessions, loadedAt = Now, notice = DevicesNotice.REVOKED_ONE),
        DevicesUiState(sessions = Sessions, loadedAt = Now, confirming = DevicesConfirmation.RevokeOne(Sessions[1])),
        DevicesUiState(sessions = listOf(Phone), loadedAt = Now, error = AccountError.NotFound),
        DevicesUiState(error = AccountError.NoConnection),
    )
}

private class ChangePasswordStates : PreviewParameterProvider<ChangePasswordUiState> {
    override val values = sequenceOf(
        ChangePasswordUiState(
            currentPassword = "a wrong one",
            newPassword = "short",
            fieldProblems = setOf(InputProblem.CURRENT_PASSWORD_INCORRECT, InputProblem.PASSWORD_TOO_SHORT),
        ),
        ChangePasswordUiState(isDone = true),
    )
}

private class ChangeEmailStates : PreviewParameterProvider<ChangeEmailUiState> {
    override val values = sequenceOf(
        ChangeEmailUiState(newEmail = "amina@example.com", fieldProblems = setOf(InputProblem.EMAIL_UNCHANGED)),
        ChangeEmailUiState(
            step = ChangeEmailStep.CODE,
            newEmail = "amina.new@example.com",
            isCodeSent = true,
            resendCooldownSeconds = 42,
        ),
        ChangeEmailUiState(
            step = ChangeEmailStep.CODE,
            newEmail = "amina.new@example.com",
            error = AccountError.EmailTaken,
        ),
        ChangeEmailUiState(step = ChangeEmailStep.DONE, changedTo = "amina.new@example.com"),
    )
}

private class DeleteAccountStates : PreviewParameterProvider<DeleteAccountUiState> {
    override val values = sequenceOf(
        DeleteAccountUiState(password = "a wrong one", fieldProblems = setOf(InputProblem.CURRENT_PASSWORD_INCORRECT)),
        DeleteAccountUiState(password = "a long passphrase", isConfirming = true),
    )
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun AccountOverviewPreview() {
    AwradTheme {
        AccountOverviewScreen(
            account = Account(AwradId("0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"), "amina@example.com"),
            onAction = {},
            onBack = {},
        )
    }
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun DevicesPreview(@PreviewParameter(DevicesStates::class) state: DevicesUiState) {
    AwradTheme { DevicesScreen(state = state, onAction = {}, onBack = {}) }
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun ChangePasswordPreview(@PreviewParameter(ChangePasswordStates::class) state: ChangePasswordUiState) {
    AwradTheme { ChangePasswordScreen(state = state, onAction = {}, onBack = {}) }
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun ChangeEmailPreview(@PreviewParameter(ChangeEmailStates::class) state: ChangeEmailUiState) {
    AwradTheme { ChangeEmailScreen(state = state, onAction = {}, onBack = {}, onFinish = {}) }
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun DeleteAccountPreview(@PreviewParameter(DeleteAccountStates::class) state: DeleteAccountUiState) {
    AwradTheme { DeleteAccountScreen(state = state, onAction = {}, onBack = {}) }
}
