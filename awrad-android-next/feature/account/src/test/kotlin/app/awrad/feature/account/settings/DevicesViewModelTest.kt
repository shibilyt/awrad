package app.awrad.feature.account.settings

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.SignInState
import app.awrad.core.testing.FakeAccountRepository
import app.awrad.core.testing.FakeAccountSettingsRepository
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DevicesViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val now = Instant.parse("2026-10-27T07:00:00Z")
    private val accounts = FakeAccountRepository(SignInState.SignedIn(FakeAccountRepository.ACCOUNT))
    private val settings = FakeAccountSettingsRepository(accounts)
    private val viewModel by lazy { DevicesViewModel(settings, Clock.fixed(now, ZoneOffset.UTC)) }
    private val state get() = viewModel.state.value
    private val phone = FakeAccountSettingsRepository.SESSIONS[0]
    private val browser = FakeAccountSettingsRepository.SESSIONS[1]

    @Test
    fun `the list loads with this device first, and the time it loaded`() {
        settings.sessionsResult = AccountResult.Success(listOf(browser, phone))

        assertEquals(listOf(phone, browser), state.sessions)
        assertEquals(now, state.loadedAt)
        assertEquals(listOf(browser), state.others)
        assertTrue(state.canRevoke)
    }

    @Test
    fun `revoking a device asks first, then signs it out and reloads`() {
        viewModel.onAction(DevicesAction.Revoke(browser))

        assertEquals(DevicesConfirmation.RevokeOne(browser), state.confirming)
        assertEquals(listOf("sessions"), settings.calls)

        viewModel.onAction(DevicesAction.Confirm)

        assertEquals(listOf("sessions", "revoke ${browser.id.value}", "sessions"), settings.calls)
        assertEquals(DevicesNotice.REVOKED_ONE, state.notice)
        assertNull(state.confirming)
        assertEquals(false, state.isBusy)
    }

    @Test
    fun `dismissing the confirmation signs nothing out`() {
        viewModel.onAction(DevicesAction.RevokeOthers)
        viewModel.onAction(DevicesAction.Dismiss)
        viewModel.onAction(DevicesAction.Confirm)

        assertEquals(listOf("sessions"), settings.calls)
    }

    @Test
    fun `this device isn't revoked from the list`() {
        viewModel.onAction(DevicesAction.Revoke(phone))

        assertNull(state.confirming)
    }

    @Test
    fun `signing out every other device keeps this one`() {
        viewModel.onAction(DevicesAction.RevokeOthers)
        settings.sessionsResult = AccountResult.Success(listOf(phone))
        viewModel.onAction(DevicesAction.Confirm)

        assertEquals(listOf("sessions", "revoke_others", "sessions"), settings.calls)
        assertEquals(DevicesNotice.REVOKED_OTHERS, state.notice)
        assertEquals(listOf(phone), state.sessions)
        assertEquals(false, state.canRevoke)
    }

    @Test
    fun `a session that had already ended says so and the list refreshes`() {
        settings.revokeResult = AccountResult.Failure(AccountError.NotFound)
        viewModel.onAction(DevicesAction.Revoke(browser))
        settings.sessionsResult = AccountResult.Success(listOf(phone))
        viewModel.onAction(DevicesAction.Confirm)

        assertEquals(AccountError.NotFound, state.error)
        assertNull(state.notice)
        assertEquals(listOf(phone), state.sessions)
    }

    @Test
    fun `a failed load offers to try again`() {
        settings.sessionsResult = AccountResult.Failure(AccountError.NoConnection)

        assertEquals(AccountError.NoConnection, state.error)
        assertTrue(state.canRetry)

        settings.sessionsResult = AccountResult.Success(FakeAccountSettingsRepository.SESSIONS)
        viewModel.onAction(DevicesAction.Reload)

        assertNull(state.error)
        assertEquals(2, state.sessions?.size)
    }
}
