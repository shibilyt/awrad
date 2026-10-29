package app.awrad.next.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import app.awrad.core.designsystem.motion.AwradPage
import app.awrad.core.designsystem.motion.LocalAwradPageTransitions
import app.awrad.core.designsystem.motion.rememberAwradPageTransitions
import app.awrad.feature.account.AccountDestination
import app.awrad.feature.account.accountScreen
import app.awrad.feature.library.libraryScreen
import app.awrad.feature.onboarding.OnboardingDestination
import app.awrad.feature.onboarding.onboardingScreen
import app.awrad.feature.practice.PracticeSettingsDestination
import app.awrad.feature.practice.practiceSettingsScreen
import app.awrad.feature.sync.DataSyncDestination
import app.awrad.feature.sync.SyncPrompts
import app.awrad.feature.sync.dataSyncScreen
import app.awrad.next.AppShellViewModel
import app.awrad.next.StartDestination

/**
 * Wires features together. Each feature contributes one `NavGraphBuilder`
 * extension; this file only decides how they connect.
 *
 * Pages move with the shared page transitions (`pagePush`, `pagePop`; ARCHITECTURE.md, "Motion"): every
 * destination wraps its content in `AwradPage`, so the page behind rounds and dims (`screenDepth`), and
 * predictive back seeks the pop transition with the gesture.
 */
@Composable
fun AwradNavHost(
    modifier: Modifier = Modifier,
    shell: AppShellViewModel = hiltViewModel(),
) {
    val start by shell.startDestination.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val startRoute: Any? = remember(start != null) {
        when (start) {
            StartDestination.Onboarding -> OnboardingDestination
            StartDestination.Home -> MainDestination
            null -> null
        }
    }
    if (startRoute == null) {
        // DataStore answers within a frame or two; keep the window background meanwhile.
        Box(modifier = modifier.fillMaxSize().background(MaterialTheme.colorScheme.background))
        return
    }
    val pages = rememberAwradPageTransitions()
    CompositionLocalProvider(LocalAwradPageTransitions provides pages) {
        NavHost(
            navController = navController,
            startDestination = startRoute,
            modifier = modifier,
            enterTransition = { pages.enter(this) },
            exitTransition = { pages.exit(this) },
            popEnterTransition = { pages.popEnter(this) },
            popExitTransition = { pages.popExit(this) },
        ) {
            onboardingScreen(onFinish = { navController.replaceStackWith(MainDestination) })
            composable<MainDestination> { entry ->
                AwradPage(scope = this, key = entry) {
                    MainShell(
                        onNavigate = { navController.navigate(it) },
                        onOpenAccount = { navController.navigate(AccountDestination) },
                        onOpenDataSync = { navController.navigate(DataSyncDestination) },
                        onOpenPracticeSettings = { navController.navigate(PracticeSettingsDestination) },
                        onRestartOnboarding = { navController.replaceStackWith(OnboardingDestination) },
                    )
                }
            }
            libraryScreen(onNavigate = { navController.navigate(it) }, onBack = { navController.popBackStack() })
            accountScreen(onBack = { navController.popBackStack() })
            practiceSettingsScreen(onBack = { navController.popBackStack() })
            dataSyncScreen(
                onBack = { navController.popBackStack() },
                onOpenAccount = { navController.navigate(AccountDestination) },
            )
        }
        // The first sign-in's question, a deleted account's data, and refused changes, over any page.
        SyncPrompts()
    }
}

private fun NavHostController.replaceStackWith(destination: Any) {
    navigate(destination) {
        popUpTo(graph.id) { inclusive = true }
        launchSingleTop = true
    }
}
