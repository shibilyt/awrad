package app.awrad.next.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradBottomBar
import app.awrad.core.designsystem.component.AwradBottomBarItem
import app.awrad.core.designsystem.component.AwradBottomBarLayout
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.feature.library.LibraryDestination
import app.awrad.feature.library.LibraryTab
import app.awrad.next.R
import app.awrad.next.home.HomeTab
import kotlinx.serialization.Serializable

/** The main tabs under the floating bottom bar. Pages such as a collection or the account open over them. */
@Serializable
data object MainDestination

/** The tabs that exist so far; Goals and Community come with their slices. */
enum class MainTab { Home, Library }

/**
 * The floating bottom bar over the selected tab. Tabs swap with `tabSwitch`, keep their scroll and search while
 * hidden, and Back on Library returns to Home before it leaves the app.
 */
@Composable
fun MainShell(
    onNavigate: (LibraryDestination) -> Unit,
    onOpenAccount: () -> Unit,
    onOpenDataSync: () -> Unit,
    onRestartOnboarding: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var tab by rememberSaveable { mutableStateOf(MainTab.Home) }
    val tabs = rememberSaveableStateHolder()
    val motion = AwradTheme.motion
    BackHandler(enabled = tab != MainTab.Home) { tab = MainTab.Home }
    AwradBottomBarLayout(
        modifier = modifier.background(AwradTheme.colors.background),
        bottomBar = {
            AwradBottomBar(
                items = listOf(
                    AwradBottomBarItem(stringResource(R.string.shell_tab_home), AwradIcons.Home),
                    AwradBottomBarItem(stringResource(R.string.shell_tab_library), AwradIcons.Library),
                ),
                selectedIndex = tab.ordinal,
                onSelect = { tab = MainTab.entries[it] },
            )
        },
    ) {
        AnimatedContent(targetState = tab, transitionSpec = { motion.tabSwitch() }, label = "mainTab") { shown ->
            tabs.SaveableStateProvider(shown.name) {
                when (shown) {
                    MainTab.Home -> HomeTab(
                        onOpenAccount = onOpenAccount,
                        onOpenDataSync = onOpenDataSync,
                        onRestartOnboarding = onRestartOnboarding,
                        onNavigate = onNavigate,
                        onViewLibrary = { tab = MainTab.Library },
                    )
                    MainTab.Library -> LibraryTab(onNavigate = onNavigate)
                }
            }
        }
    }
}
