package app.awrad.awrad_dhikrgoalstracker

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.awrad.awrad_dhikrgoalstracker.notification.WorkerKeys
import app.awrad.awrad_dhikrgoalstracker.service.DhikrCountingService
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradBottomBar
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualScreen
import app.awrad.awrad_dhikrgoalstracker.ui.navigation.AwradDestination
import app.awrad.awrad_dhikrgoalstracker.ui.navigation.AwradNavGraph
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject
import app.awrad.awrad_dhikrgoalstracker.data.repository.AuthRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.ForegroundProgressSyncCoordinator

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject lateinit var authRepository: AuthRepository
    @Inject lateinit var foregroundProgressSyncCoordinator: ForegroundProgressSyncCoordinator

    private val mainViewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
        enableEdgeToEdge()
        setContent {
            AwradApp(mainViewModel = mainViewModel)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        foregroundProgressSyncCoordinator.setAppForeground(true)
    }

    override fun onStop() {
        foregroundProgressSyncCoordinator.setAppForeground(false)
        super.onStop()
    }

    private fun handleNotificationIntent(intent: Intent) {
        // Wird reminder tap.
        intent.getStringExtra(WorkerKeys.EXTRA_WIRD_ID)?.let {
            mainViewModel.onWirdDeepLink(it)
            return
        }
        // awrad:// deep links — awrad://wirds and awrad://todays-wird (both open the wird list).
        intent.data?.let { uri ->
            if (uri.scheme == "https" && uri.pathSegments.take(2) == listOf("auth", "verify-email")) {
                uri.lastPathSegment?.takeIf { it.isNotBlank() }?.let { token ->
                    lifecycleScope.launch { authRepository.verifyEmail(token) }
                }
                return
            }
            if (uri.scheme == "awrad" && uri.host in setOf("wirds", "todays-wird", "today-wird")) {
                mainViewModel.onWirdDeepLink(null)
                return
            }
        }
        val goalId = intent.getStringExtra(DhikrCountingService.EXTRA_GOAL_ID)
            ?.let { runCatching { java.util.UUID.fromString(it) }.getOrNull() } ?: return
        val slotId = intent.getStringExtra(DhikrCountingService.EXTRA_SLOT_ID)
            ?.let { runCatching { java.util.UUID.fromString(it) }.getOrNull() }
        mainViewModel.onNotificationGoalId(goalId, slotId)
    }
}

@Composable
fun AwradApp(
    mainViewModel: MainViewModel = hiltViewModel(),
) {
    val mainState by mainViewModel.uiState.collectAsState()

    // Explicit user preference wins. "Follow system" (null) defers to the OS dark mode setting.
    val darkMode = when (mainState) {
        is MainUiState.Ready -> (mainState as MainUiState.Ready).darkMode
        else -> null
    }
    val isDark = darkMode ?: isSystemInDarkTheme()

    AwradDhikrGoalsTrackerTheme(darkTheme = isDark) {
        when (val state = mainState) {
            is MainUiState.Loading -> {
                Box(modifier = Modifier.fillMaxSize())
            }
            is MainUiState.Ready -> {
            val startDestination = if (state.isOnboarded) {
                AwradDestination.Home.route
            } else {
                AwradDestination.Onboarding.route
            }

            val navController = rememberNavController()
            val navBackStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = navBackStackEntry?.destination?.route
            val isOnboardingFlow = !state.isOnboarded || currentRoute == AwradDestination.Onboarding.route

            // Navigate to counting screen on every notification tap (cold or hot)
            LaunchedEffect(Unit) {
                mainViewModel.notificationGoalEvents.collect { event ->
                    if (state.isOnboarded) {
                        navController.navigate(AwradDestination.Counting.createRoute(event.goalId, event.slotId)) {
                            popUpTo(AwradDestination.Home.route) { inclusive = false }
                            launchSingleTop = true
                        }
                    }
                }
            }

            // Wird reminder taps + awrad:// deep links.
            LaunchedEffect(Unit) {
                mainViewModel.wirdNavEvents.collect { wirdId ->
                    if (state.isOnboarded) {
                        val route = if (wirdId != null) {
                            AwradDestination.WirdDetail.createRoute(wirdId)
                        } else {
                            AwradDestination.WirdList.route
                        }
                        navController.navigate(route) {
                            popUpTo(AwradDestination.Home.route) { inclusive = false }
                            launchSingleTop = true
                        }
                    }
                }
            }

            val showBottomBar = currentRoute in listOf(
                AwradDestination.Home.route,
                AwradDestination.Goals.route,
                AwradDestination.Library.route,
                AwradDestination.Community.route,
            )

            Box(modifier = Modifier.fillMaxSize()) {
                RitualScreen {
                    AwradNavGraph(
                        navController = navController,
                        startDestination = startDestination,
                        modifier = Modifier.fillMaxSize(),
                    )
                }

                if (!isOnboardingFlow) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .fillMaxWidth()
                            .windowInsetsTopHeight(WindowInsets.statusBars)
                            .background(statusBarContainerColor(currentRoute)),
                    )
                }

                if (showBottomBar) {
                    AwradBottomBar(
                        navController = navController,
                        modifier = Modifier.align(Alignment.BottomCenter),
                    )
                }
            }
        }
        }
    }
}

private val surfaceStatusBarRoutes = setOf(
    AwradDestination.Library.route,
    AwradDestination.CreateGoal.route,
    AwradDestination.Category.route,
    AwradDestination.Counting.route,
    AwradDestination.GoalDetail.route,
    AwradDestination.EditGoal.route,
    AwradDestination.DhikrDetail.route,
    AwradDestination.WirdList.route,
    AwradDestination.WirdDetail.route,
    AwradDestination.WirdReader.route,
    AwradDestination.CreateDhikr.route,
    AwradDestination.Login.route,
    AwradDestination.Signup.route,
    AwradDestination.ForgotPassword.route,
)

private fun String?.isSurfaceStatusBarRoute(): Boolean =
    this in surfaceStatusBarRoutes || this?.startsWith("create_goal") == true

@Composable
private fun statusBarContainerColor(route: String?) =
    if (route.isSurfaceStatusBarRoute() && !isAwradDarkTheme() && route != AwradDestination.Counting.route) {
        MaterialTheme.colorScheme.surface
    } else {
        MaterialTheme.colorScheme.background
    }
