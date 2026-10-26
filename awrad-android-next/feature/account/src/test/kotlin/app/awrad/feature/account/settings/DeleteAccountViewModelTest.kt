package app.awrad.feature.account.settings

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.account.SignOutReason
import app.awrad.core.testing.FakeAccountRepository
import app.awrad.core.testing.FakeAccountSettingsRepository
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DeleteAccountViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val accounts = FakeAccountRepository(SignInState.SignedIn(FakeAccountRepository.ACCOUNT))
    private val settings = FakeAccountSettingsRepository(accounts)
    private val viewModel by lazy { DeleteAccountViewModel(settings) }
    private val state get() = viewModel.state.value

    @Test
    fun `nothing is deleted without the password and a confirmation`() {
        viewModel.onAction(DeleteAccountAction.Submit)
        assertFalse(state.isConfirming)

        viewModel.onAction(DeleteAccountAction.PasswordChanged("a long passphrase"))
        viewModel.onAction(DeleteAccountAction.Submit)
        assertTrue(state.isConfirming)

        viewModel.onAction(DeleteAccountAction.Dismiss)
        viewModel.onAction(DeleteAccountAction.Confirm)

        assertFalse(state.isConfirming)
        assertTrue(settings.calls.isEmpty())
    }

    @Test
    fun `confirming deletes the account and signs the device out`() {
        viewModel.onAction(DeleteAccountAction.PasswordChanged("a long passphrase"))
        viewModel.onAction(DeleteAccountAction.Submit)
        viewModel.onAction(DeleteAccountAction.Confirm)

        assertEquals(listOf("delete_account"), settings.calls)
        assertEquals(SignInState.SignedOut(SignOutReason.ACCOUNT_DELETED), accounts.currentSession)
        assertEquals("", state.password)
    }

    @Test
    fun `a wrong password shows under the field and keeps the account`() {
        settings.deleteResult =
            AccountResult.Failure(AccountError.InvalidInput(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT)))
        viewModel.onAction(DeleteAccountAction.PasswordChanged("not it"))
        viewModel.onAction(DeleteAccountAction.Submit)
        viewModel.onAction(DeleteAccountAction.Confirm)

        assertEquals(InputProblem.CURRENT_PASSWORD_INCORRECT, state.passwordProblem)
        assertFalse(state.isBusy)
        assertTrue(accounts.currentSession is SignInState.SignedIn)
    }

    @Test
    fun `no connection is the page's error`() {
        settings.deleteResult = AccountResult.Failure(AccountError.NoConnection)
        viewModel.onAction(DeleteAccountAction.PasswordChanged("a long passphrase"))
        viewModel.onAction(DeleteAccountAction.Submit)
        viewModel.onAction(DeleteAccountAction.Confirm)

        assertEquals(AccountError.NoConnection, state.error)
        assertEquals("a long passphrase", state.password)
    }
}
