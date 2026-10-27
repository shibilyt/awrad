package app.awrad.feature.account.settings

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.awrad.core.designsystem.motion.AwradPage
import app.awrad.core.designsystem.motion.LocalAwradPageTransitions
import app.awrad.core.designsystem.motion.rememberAwradPageTransitions
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
    // The same page transitions (and screen depth, and predictive back) as the app's own NavHost.
    val pages = rememberAwradPageTransitions()
    CompositionLocalProvider(LocalAwradPageTransitions provides pages) {
        NavHost(
            navController = navController,
            startDestination = OverviewPage,
            modifier = modifier,
            enterTransition = { pages.enter(this) },
            exitTransition = { pages.exit(this) },
            popEnterTransition = { pages.popEnter(this) },
            popExitTransition = { pages.popExit(this) },
        ) {
            composable<OverviewPage> { entry ->
                AwradPage(scope = this, key = entry) {
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
            }
            composable<DevicesPage> { entry -> AwradPage(scope = this, key = entry) { DevicesRoute(onBack = back) } }
            composable<ChangePasswordPage> { entry ->
                AwradPage(scope = this, key = entry) { ChangePasswordRoute(onBack = back) }
            }
            composable<ChangeEmailPage> { entry ->
                AwradPage(scope = this, key = entry) { ChangeEmailRoute(onBack = back) }
            }
            composable<DeleteAccountPage> { entry ->
                AwradPage(scope = this, key = entry) { DeleteAccountRoute(onBack = back) }
            }
        }
    }
}

@StringRes
internal fun DevicesNotice.message(): Int = when (this) {
    DevicesNotice.REVOKED_ONE -> R.string.account_notice_revoked_one
    DevicesNotice.REVOKED_OTHERS -> R.string.account_notice_revoked_others
}
