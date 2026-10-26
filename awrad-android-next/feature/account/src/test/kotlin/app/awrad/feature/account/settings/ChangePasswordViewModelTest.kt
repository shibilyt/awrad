package app.awrad.feature.account.settings

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.SignInState
import app.awrad.core.testing.FakeAccountRepository
import app.awrad.core.testing.FakeAccountSettingsRepository
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ChangePasswordViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val accounts = FakeAccountRepository(SignInState.SignedIn(FakeAccountRepository.ACCOUNT))
    private val settings = FakeAccountSettingsRepository(accounts)
    private val viewModel by lazy { ChangePasswordViewModel(settings) }
    private val state get() = viewModel.state.value

    private fun type(current: String, new: String) {
        viewModel.onAction(ChangePasswordAction.CurrentPasswordChanged(current))
        viewModel.onAction(ChangePasswordAction.NewPasswordChanged(new))
    }

    @Test
    fun `typing updates the state at once`() {
        viewModel.onAction(ChangePasswordAction.NewPasswordChanged("a"))
        assertEquals("a", state.newPassword)
        viewModel.onAction(ChangePasswordAction.NewPasswordChanged("ab"))
        assertEquals("ab", state.newPassword)
    }

    @Test
    fun `a short new password is caught before sending`() {
        type(current = "a long passphrase", new = "short")
        viewModel.onAction(ChangePasswordAction.Submit)

        assertEquals(InputProblem.PASSWORD_TOO_SHORT, state.newPasswordProblem)
        assertTrue(settings.calls.isEmpty())
    }

    @Test
    fun `a wrong current password shows under its field`() {
        settings.changePasswordResult =
            AccountResult.Failure(AccountError.InvalidInput(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT)))
        type(current = "not it", new = "another long passphrase")
        viewModel.onAction(ChangePasswordAction.Submit)

        assertEquals(InputProblem.CURRENT_PASSWORD_INCORRECT, state.currentPasswordProblem)
        assertNull(state.newPasswordProblem)
        assertNull(state.error)

        viewModel.onAction(ChangePasswordAction.CurrentPasswordChanged("a long passphrase"))
        assertNull(state.currentPasswordProblem)
    }

    @Test
    fun `a common new password from the server shows under the new password`() {
        settings.changePasswordResult =
            AccountResult.Failure(AccountError.InvalidInput(setOf(InputProblem.PASSWORD_TOO_COMMON)))
        type(current = "a long passphrase", new = "password1234")
        viewModel.onAction(ChangePasswordAction.Submit)

        assertEquals(InputProblem.PASSWORD_TOO_COMMON, state.newPasswordProblem)
    }

    @Test
    fun `a change clears the form and says the others are signed out`() {
        type(current = "a long passphrase", new = "another long passphrase")
        viewModel.onAction(ChangePasswordAction.Submit)

        assertEquals(listOf("change_password"), settings.calls)
        assertTrue(state.isDone)
        assertEquals("", state.currentPassword)
        assertEquals("", state.newPassword)
        assertTrue(accounts.currentSession is SignInState.SignedIn)
    }

    @Test
    fun `a rate limit is the page's error`() {
        settings.changePasswordResult = AccountResult.Failure(AccountError.RateLimited(30))
        type(current = "a long passphrase", new = "another long passphrase")
        viewModel.onAction(ChangePasswordAction.Submit)

        assertEquals(AccountError.RateLimited(30), state.error)
        assertEquals(false, state.isBusy)
    }
}
