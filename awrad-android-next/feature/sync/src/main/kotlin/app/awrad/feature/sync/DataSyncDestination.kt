package app.awrad.feature.sync

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/**
 * "Data and sync" (slice 3b): where syncing stands, conflicts, and the local profiles on this phone, each of which
 * can be removed. It works signed out too: the data on the phone is there either way.
 */
@Serializable
public data object DataSyncDestination

/** The page: [onBack] leaves it, [onOpenAccount] signs in (sync is opt-in). */
public fun NavGraphBuilder.dataSyncScreen(onBack: () -> Unit, onOpenAccount: () -> Unit) {
    composable<DataSyncDestination> { entry ->
        AwradPage(scope = this, key = entry) { DataSyncRoute(onBack = onBack, onOpenAccount = onOpenAccount) }
    }
}

/**
 * The questions and notices the change queue raises wherever the user is, for the app shell to place over its
 * pages: the first sign-in with anonymous data, a deleted account's data, and changes the server refused.
 */
@Composable
public fun SyncPrompts(modifier: Modifier = Modifier) {
    SyncPromptsRoute(modifier = modifier)
}
