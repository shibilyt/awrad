package app.awrad.feature.account.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.inListOrder
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.Instant
import javax.inject.Inject

/** What the devices page asks to confirm before it signs anything out. */
internal sealed interface DevicesConfirmation {
    data class RevokeOne(val session: AccountSession) : DevicesConfirmation

    data object RevokeOthers : DevicesConfirmation
}

internal enum class DevicesNotice { REVOKED_ONE, REVOKED_OTHERS }

/**
 * The devices page: every account session, this device first. [sessions] is null until the first load;
 * [loadedAt] is when it loaded, for "last used" times.
 */
internal data class DevicesUiState(
    val sessions: List<AccountSession>? = null,
    val loadedAt: Instant = Instant.EPOCH,
    val isBusy: Boolean = false,
    val error: AccountError? = null,
    val notice: DevicesNotice? = null,
    val confirming: DevicesConfirmation? = null,
) {
    val others: List<AccountSession> get() = sessions.orEmpty().filterNot { it.isCurrent }

    val canRevoke: Boolean get() = !isBusy && others.isNotEmpty()

    /** Nothing to show yet, and the load failed: offer to try again. */
    val canRetry: Boolean get() = !isBusy && sessions == null
}

internal sealed interface DevicesAction {
    data object Reload : DevicesAction

    /** Asks to confirm signing [session] out. This device signs out from the account page instead. */
    data class Revoke(val session: AccountSession) : DevicesAction

    data object RevokeOthers : DevicesAction

    data object Confirm : DevicesAction

    data object Dismiss : DevicesAction
}

@HiltViewModel
internal class DevicesViewModel @Inject constructor(
    private val settings: AccountSettingsRepository,
    private val clock: Clock,
) : ViewModel() {

    private val mutableState = MutableStateFlow(DevicesUiState())
    val state: StateFlow<DevicesUiState> = mutableState.asStateFlow()

    init {
        busy { load() }
    }

    fun onAction(action: DevicesAction) {
        when (action) {
            DevicesAction.Reload -> busy { load() }
            is DevicesAction.Revoke -> if (!action.session.isCurrent) {
                confirm(DevicesConfirmation.RevokeOne(action.session))
            }
            DevicesAction.RevokeOthers -> confirm(DevicesConfirmation.RevokeOthers)
            DevicesAction.Confirm -> revoke()
            DevicesAction.Dismiss -> mutableState.update { it.copy(confirming = null) }
        }
    }

    private fun confirm(confirmation: DevicesConfirmation) {
        if (mutableState.value.isBusy) return
        mutableState.update { it.copy(confirming = confirmation) }
    }

    private fun revoke() {
        val confirmation = mutableState.value.confirming ?: return
        mutableState.update { it.copy(confirming = null) }
        busy {
            val (result, notice) = when (confirmation) {
                is DevicesConfirmation.RevokeOne ->
                    settings.revokeAccountSession(confirmation.session.id) to DevicesNotice.REVOKED_ONE
                DevicesConfirmation.RevokeOthers ->
                    settings.revokeOtherAccountSessions() to DevicesNotice.REVOKED_OTHERS
            }
            when (result) {
                is AccountResult.Success -> mutableState.update { it.copy(notice = notice) }
                // Already ended (or a retry of one that worked): say so, and show the list as it is now.
                is AccountResult.Failure -> mutableState.update { it.copy(error = result.error) }
            }
            load(keepStatus = true)
        }
    }

    private suspend fun load(keepStatus: Boolean = false) {
        when (val result = settings.accountSessions()) {
            is AccountResult.Success -> mutableState.update {
                it.copy(sessions = result.value.inListOrder(), loadedAt = clock.instant())
            }
            is AccountResult.Failure -> mutableState.update {
                // A failed reload keeps the error of the revoke before it, if there was one.
                if (keepStatus && it.error != null) it else it.copy(error = result.error, notice = null)
            }
        }
    }

    /** Runs [block] busy, clearing the last status; a second request while busy is ignored. */
    private fun busy(block: suspend () -> Unit) {
        if (mutableState.value.isBusy) return
        mutableState.update { it.copy(isBusy = true, error = null, notice = null) }
        viewModelScope.launch {
            try {
                block()
            } finally {
                mutableState.update { it.copy(isBusy = false) }
            }
        }
    }
}
