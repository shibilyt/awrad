package app.awrad.feature.account

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.testing.FakeAccountRepository
import app.awrad.core.testing.MainDispatcherRule
import kotlinx.coroutines.ExperimentalCoroutinesApi
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AccountViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val accounts = FakeAccountRepository()
    private val viewModel by lazy { AccountViewModel(accounts) }
    private val state get() = viewModel.state.value

    private fun AccountViewModel.type(email: String = "", password: String = "", code: String = "") {
        if (email.isNotEmpty()) onAction(AccountAction.EmailChanged(email))
        if (password.isNotEmpty()) onAction(AccountAction.PasswordChanged(password))
        if (code.isNotEmpty()) onAction(AccountAction.CodeChanged(code))
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private fun advanceSeconds(seconds: Long) {
        mainDispatcher.dispatcher.scheduler.advanceTimeBy(seconds * 1_000)
        mainDispatcher.dispatcher.scheduler.runCurrent()
    }

    @Test
    fun `a signed-out device starts on sign in`() {
        assertEquals(AccountStep.SIGN_IN, state.step)
    }

    @Test
    fun `a signed-in device shows the account and reloads it from the server`() {
        val accounts = FakeAccountRepository(AccountSession.SignedIn(FakeAccountRepository.ACCOUNT))
        val viewModel = AccountViewModel(accounts)

        assertEquals(AccountStep.SIGNED_IN, viewModel.state.value.step)
        assertEquals("amina@example.com", viewModel.state.value.account?.email)
        assertEquals(listOf("refresh"), accounts.calls)
    }

    @Test
    fun `register checks the shared input rules before sending anything`() {
        viewModel.onAction(AccountAction.GoToRegister)
        viewModel.type(email = "amina@localhost", password = "a long passphrase")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(setOf(InputProblem.EMAIL_INVALID), state.fieldProblems)

        viewModel.type(email = " amina@example.com ", password = "short")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(setOf(InputProblem.PASSWORD_TOO_SHORT), state.fieldProblems)
        assertTrue(accounts.calls.isEmpty())
    }

    @Test
    fun `register then verify signs in with the typed password`() {
        viewModel.onAction(AccountAction.GoToRegister)
        viewModel.type(email = " amina@example.com ", password = "a long passphrase")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(AccountStep.VERIFY_EMAIL, state.step)
        assertEquals(AccountNotice.CODE_SENT, state.notice)
        assertEquals(60, state.resendCooldownSeconds)

        viewModel.type(code = "٤٨٢ ٩١٣")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(
            listOf("register amina@example.com", "verify amina@example.com 482913", "sign_in amina@example.com"),
            accounts.calls.take(3),
        )
        assertEquals(AccountStep.SIGNED_IN, state.step)
        assertEquals("", state.password)
    }

    @Test
    fun `a malformed code is caught before sending`() {
        accounts.signInResult = AccountResult.Failure(AccountError.EmailVerificationRequired)
        viewModel.type(email = "amina@example.com", password = "a long passphrase")
        viewModel.onAction(AccountAction.Submit)
        viewModel.type(code = "48291")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(setOf(InputProblem.CODE_INVALID), state.fieldProblems)
        assertEquals(listOf("sign_in amina@example.com"), accounts.calls)
    }

    @Test
    fun `an unverified sign-in goes to the code screen`() {
        accounts.signInResult = AccountResult.Failure(AccountError.EmailVerificationRequired)
        viewModel.type(email = "amina@example.com", password = "a long passphrase")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(AccountStep.VERIFY_EMAIL, state.step)
        assertEquals(AccountNotice.VERIFICATION_REQUIRED, state.notice)
        assertNull(state.error)
    }

    @Test
    fun `server errors are shown by code, field codes on their fields`() {
        accounts.signInResult = AccountResult.Failure(AccountError.InvalidCredentials)
        viewModel.type(email = "amina@example.com", password = "wrong")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(AccountError.InvalidCredentials, state.error)
        assertEquals(AccountStep.SIGN_IN, state.step)

        val tooCommon = AccountError.InvalidInput(setOf(InputProblem.PASSWORD_TOO_COMMON))
        accounts.registerResult = AccountResult.Failure(tooCommon)
        viewModel.onAction(AccountAction.GoToRegister)
        viewModel.type(password = "password1234")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(setOf(InputProblem.PASSWORD_TOO_COMMON), state.fieldProblems)
        assertNull(state.error)
    }

    @Test
    fun `resend waits out the cooldown, and a rate limit extends it`() {
        viewModel.onAction(AccountAction.GoToRegister)
        viewModel.type(email = "amina@example.com", password = "a long passphrase")
        viewModel.onAction(AccountAction.Submit)

        viewModel.onAction(AccountAction.ResendCode)
        assertEquals(listOf("register amina@example.com"), accounts.calls)

        advanceSeconds(60)
        assertEquals(0, state.resendCooldownSeconds)
        accounts.resendResult = AccountResult.Failure(AccountError.RateLimited(retryAfterSeconds = 120))
        viewModel.onAction(AccountAction.ResendCode)

        assertEquals("resend amina@example.com", accounts.calls.last())
        assertEquals(120, state.resendCooldownSeconds)
        assertTrue(state.error is AccountError.RateLimited)
    }

    @Test
    fun `forgot password then reset signs in with the new password`() {
        viewModel.type(email = "amina@example.com")
        viewModel.onAction(AccountAction.GoToForgotPassword)
        viewModel.onAction(AccountAction.Submit)

        assertEquals(AccountStep.RESET_PASSWORD, state.step)

        viewModel.type(code = "730-158", password = "another long passphrase")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(
            listOf("request_reset amina@example.com", "reset amina@example.com 730158", "sign_in amina@example.com"),
            accounts.calls.take(3),
        )
        assertEquals(AccountStep.SIGNED_IN, state.step)
    }

    @Test
    fun `a wrong reset code keeps the form`() {
        accounts.resetResult = AccountResult.Failure(AccountError.ResetCodeInvalid)
        viewModel.type(email = "amina@example.com")
        viewModel.onAction(AccountAction.GoToForgotPassword)
        viewModel.onAction(AccountAction.Submit)
        viewModel.type(code = "000000", password = "another long passphrase")
        viewModel.onAction(AccountAction.Submit)

        assertEquals(AccountStep.RESET_PASSWORD, state.step)
        assertEquals(AccountError.ResetCodeInvalid, state.error)
    }

    @Test
    fun `signing out returns to sign in and says practice stays`() {
        val accounts = FakeAccountRepository(AccountSession.SignedIn(FakeAccountRepository.ACCOUNT))
        val viewModel = AccountViewModel(accounts)

        viewModel.onAction(AccountAction.SignOut)

        assertEquals(AccountSession.SignedOut, accounts.currentSession)
        assertEquals(AccountStep.SIGN_IN, viewModel.state.value.step)
        assertEquals(AccountNotice.SIGNED_OUT, viewModel.state.value.notice)
    }

    @Test
    fun `back steps through the flow`() {
        viewModel.onAction(AccountAction.GoToForgotPassword)
        viewModel.type(email = "amina@example.com")
        viewModel.onAction(AccountAction.Submit)
        assertTrue(state.canGoBack)

        viewModel.onAction(AccountAction.Back)
        assertEquals(AccountStep.FORGOT_PASSWORD, state.step)
        viewModel.onAction(AccountAction.Back)
        assertEquals(AccountStep.SIGN_IN, state.step)
        assertEquals(false, state.canGoBack)
    }
}
