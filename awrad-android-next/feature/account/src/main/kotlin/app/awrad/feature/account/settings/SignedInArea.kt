package app.awrad.feature.account.settings

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.awrad.core.domain.account.Account
import app.awrad.feature.account.R
import kotlinx.serialization.Serializable

/*
 * The signed-in account area (slice 2b). Its pages live in a nested NavHost, internal to the feature, so
 * each page's ViewModel lives as long as the page. When the session ends (signed out here or elsewhere,
 * or the account deleted), AccountRoute replaces the whole area with the sign-in screen.
 */

@Serializable
internal data object OverviewPage

@Serializable
internal data object DevicesPage

@Serializable
internal data object ChangePasswordPage

@Serializable
internal data object ChangeEmailPage

@Serializable
internal data object DeleteAccountPage

/** Everything the signed-in account page can ask for. */
internal enum class OverviewAction { DEVICES, CHANGE_PASSWORD, CHANGE_EMAIL, DELETE_ACCOUNT, SIGN_OUT }

@Composable
internal fun SignedInArea(
    account: Account,
    onSignOut: () -> Unit,
    onExit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val navController = rememberNavController()
    // Read through state, so a new email or new callbacks don't rebuild the graph.
    val currentAccount by rememberUpdatedState(account)
    val signOut by rememberUpdatedState(onSignOut)
    val exit by rememberUpdatedState(onExit)
    val back: () -> Unit = { navController.popBackStack() }
    NavHost(navController = navController, startDestination = OverviewPage, modifier = modifier) {
        composable<OverviewPage> {
            AccountOverviewScreen(
                account = currentAccount,
                onAction = { action ->
                    when (action) {
                        OverviewAction.DEVICES -> navController.navigate(DevicesPage)
                        OverviewAction.CHANGE_PASSWORD -> navController.navigate(ChangePasswordPage)
                        OverviewAction.CHANGE_EMAIL -> navController.navigate(ChangeEmailPage)
                        OverviewAction.DELETE_ACCOUNT -> navController.navigate(DeleteAccountPage)
                        OverviewAction.SIGN_OUT -> signOut()
                    }
                },
                onBack = { exit() },
            )
        }
        composable<DevicesPage> { DevicesRoute(onBack = back) }
        composable<ChangePasswordPage> { ChangePasswordRoute(onBack = back) }
        composable<ChangeEmailPage> { ChangeEmailRoute(onBack = back) }
        composable<DeleteAccountPage> { DeleteAccountRoute(onBack = back) }
    }
}

@StringRes
internal fun DevicesNotice.message(): Int = when (this) {
    DevicesNotice.REVOKED_ONE -> R.string.account_notice_revoked_one
    DevicesNotice.REVOKED_OTHERS -> R.string.account_notice_revoked_others
}
