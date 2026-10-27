package app.awrad.feature.account

import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/**
 * The account flow: sign in, register, verify, reset the password, or the signed-in account with sign out.
 * Its steps are internal; the flow shows the account screen whenever this device is signed in.
 */
@Serializable
public data object AccountDestination

/** The feature's whole public interface: one destination and one exit callback. */
public fun NavGraphBuilder.accountScreen(onBack: () -> Unit) {
    composable<AccountDestination> { entry ->
        AwradPage(scope = this, key = entry) { AccountRoute(onBack = onBack) }
    }
}
