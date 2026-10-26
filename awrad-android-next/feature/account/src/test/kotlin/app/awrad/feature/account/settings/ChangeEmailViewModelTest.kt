package app.awrad.feature.account.settings

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.SignInState
import app.awrad.core.testing.FakeAccountRepository
import app.awrad.core.testing.FakeAccountSettingsRepository
import app.awrad.core.testing.MainDispatcherRule
import kotlinx.coroutines.ExperimentalCoroutinesApi
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ChangeEmailViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val accounts = FakeAccountRepository(SignInState.SignedIn(FakeAccountRepository.ACCOUNT))
    private val settings = FakeAccountSettingsRepository(accounts)
    private val viewModel by lazy { ChangeEmailViewModel(settings) }
    private val state get() = viewModel.state.value

    private fun requestCode(email: String = " amina.new@example.com ") {
        viewModel.onAction(ChangeEmailAction.NewEmailChanged(email))
        viewModel.onAction(ChangeEmailAction.CurrentPasswordChanged("a long passphrase"))
        viewModel.onAction(ChangeEmailAction.Submit)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private fun advanceSeconds(seconds: Long) {
        mainDispatcher.dispatcher.scheduler.advanceTimeBy(seconds * 1_000)
        mainDispatcher.dispatcher.scheduler.runCurrent()
    }

    @Test
    fun `an invalid address is caught before sending`() {
        requestCode(email = "amina@localhost")

        assertEquals(InputProblem.EMAIL_INVALID, state.newEmailProblem)
        assertTrue(settings.calls.isEmpty())
    }

    @Test
    fun `the code goes to the trimmed new address, then confirming changes the email`() {
        requestCode()

        assertEquals(listOf("request_email_change amina.new@example.com"), settings.calls)
        assertEquals(ChangeEmailStep.CODE, state.step)
        assertTrue(state.isCodeSent)
        assertEquals(60, state.resendCooldownSeconds)

        viewModel.onAction(ChangeEmailAction.CodeChanged("٥١٩ ٢٧٤"))
        viewModel.onAction(ChangeEmailAction.Submit)

        assertEquals("confirm_email_change 519274", settings.calls.last())
        assertEquals(ChangeEmailStep.DONE, state.step)
        assertEquals(FakeAccountSettingsRepository.NEW_EMAIL, state.changedTo)
        assertEquals("", state.currentPassword)
        val session = accounts.currentSession as SignInState.SignedIn
        assertEquals(FakeAccountSettingsRepository.NEW_EMAIL, session.account.email)
    }

    @Test
    fun `the server's field codes go under their fields`() {
        settings.requestEmailChangeResult = AccountResult.Failure(
            AccountError.InvalidInput(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT, InputProblem.EMAIL_UNCHANGED)),
        )
        requestCode(email = "amina@example.com")

        assertEquals(ChangeEmailStep.FORM, state.step)
        assertEquals(InputProblem.CURRENT_PASSWORD_INCORRECT, state.currentPasswordProblem)
        assertEquals(InputProblem.EMAIL_UNCHANGED, state.newEmailProblem)
        assertNull(state.error)
    }

    @Test
    fun `a malformed code is caught before sending, and a wrong one keeps the code step`() {
        requestCode()
        viewModel.onAction(ChangeEmailAction.CodeChanged("51927"))
        viewModel.onAction(ChangeEmailAction.Submit)

        assertEquals(InputProblem.CODE_INVALID, state.codeProblem)
        assertEquals(1, settings.calls.size)

        settings.confirmEmailChangeResult = AccountResult.Failure(AccountError.EmailChangeCodeInvalid)
        viewModel.onAction(ChangeEmailAction.CodeChanged("000000"))
        viewModel.onAction(ChangeEmailAction.Submit)

        assertEquals(ChangeEmailStep.CODE, state.step)
        assertEquals(AccountError.EmailChangeCodeInvalid, state.error)
    }

    @Test
    fun `an address taken meanwhile can be swapped for another`() {
        settings.confirmEmailChangeResult = AccountResult.Failure(AccountError.EmailTaken)
        requestCode()
        viewModel.onAction(ChangeEmailAction.CodeChanged("519274"))
        viewModel.onAction(ChangeEmailAction.Submit)

        assertEquals(AccountError.EmailTaken, state.error)

        viewModel.onAction(ChangeEmailAction.EditEmail)

        assertEquals(ChangeEmailStep.FORM, state.step)
        assertEquals("amina.new@example.com", state.newEmail)
        assertEquals("a long passphrase", state.currentPassword)
        assertNull(state.error)
    }

    @Test
    fun `resend repeats the request after the cooldown, and a rate limit extends it`() {
        requestCode()
        viewModel.onAction(ChangeEmailAction.ResendCode)
        assertEquals(1, settings.calls.size)

        advanceSeconds(60)
        settings.requestEmailChangeResult = AccountResult.Failure(AccountError.RateLimited(retryAfterSeconds = 90))
        viewModel.onAction(ChangeEmailAction.ResendCode)

        assertEquals(2, settings.calls.size)
        assertEquals(ChangeEmailStep.CODE, state.step)
        assertEquals(90, state.resendCooldownSeconds)
        assertTrue(state.error is AccountError.RateLimited)
    }
}
