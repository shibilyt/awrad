package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradScreenWrapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.category.CategoryScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.CountingScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail.DhikrDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalRemindersScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalScheduleScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.GoalDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.CreateGoalScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.GoalsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.home.HomeScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding.OnboardingScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.settings.SettingsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.ForgotPasswordScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.LoginScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.SignupScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr.CreateDhikrScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdEditorScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdListScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdReaderScreen

@Composable
fun AwradNavGraph(
    navController: NavHostController,
    startDestination: String,
    modifier: Modifier = Modifier,
) {
    NavHost(
        navController = navController,
        startDestination = startDestination,
        modifier = modifier,
        enterTransition = {
            awradEnterTransition(initialState.destination.route, targetState.destination.route)
        },
        exitTransition = {
            awradExitTransition(initialState.destination.route, targetState.destination.route)
        },
        popEnterTransition = {
            awradPopEnterTransition(initialState.destination.route, targetState.destination.route)
        },
        popExitTransition = {
            awradPopExitTransition(initialState.destination.route, targetState.destination.route)
        },
    ) {
        composable(AwradDestination.Onboarding.route) {
            OnboardingScreen(
                onOnboardingComplete = { firstGoalId ->
                    navController.navigate(AwradDestination.Home.route) {
                        popUpTo(AwradDestination.Onboarding.route) { inclusive = true }
                    }
                    if (firstGoalId != null) {
                        // Land the user directly on their new goal's counting screen,
                        // with Home beneath so system-back returns to Home.
                        navController.navigate(AwradDestination.Counting.createRoute(firstGoalId))
                    }
                },
            )
        }

        composable(AwradDestination.Home.route) {
            WrappedAwradDestination(navController) {
                HomeScreen(
                    onNavigateToGoal = { goalId ->
                        navController.navigateSafely(AwradDestination.Counting.createRoute(goalId))
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute())
                    },
                    onNavigateToGoals = {
                        navController.navigateTopLevelSafely(AwradDestination.Goals.route)
                    },
                    onNavigateToCategory = { category ->
                        navController.navigateSafely(AwradDestination.Category.createRoute(category))
                    },
                    onNavigateToSettings = {
                        navController.navigateSafely(AwradDestination.Settings.route)
                    },
                    onNavigateToLibrary = {
                        navController.navigateTopLevelSafely(AwradDestination.Library.route)
                    },
                    onNavigateToWirdList = {
                        navController.navigateSafely(AwradDestination.WirdList.route)
                    },
                    onNavigateToWirdReader = { wirdId, partId ->
                        navController.navigateSafely(
                            AwradDestination.WirdReader.createRoute(wirdId, partId),
                        )
                    },
                )
            }
        }

        composable(AwradDestination.Goals.route) {
            WrappedAwradDestination(navController) {
                GoalsScreen(
                    onNavigateToCounting = { goalId ->
                        navController.navigateSafely(AwradDestination.Counting.createRoute(goalId))
                    },
                    onNavigateToGoalDetail = { goalId ->
                        navController.navigateSafely(AwradDestination.GoalDetail.createRoute(goalId))
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute())
                    },
                )
            }
        }

        composable(AwradDestination.Library.route) {
            WrappedAwradDestination(navController) {
                LibraryScreen(
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute())
                    },
                    onNavigateToDhikrDetail = { dhikrId ->
                        navController.navigateSafely(AwradDestination.DhikrDetail.createRoute(dhikrId))
                    },
                    onNavigateToCreateDhikr = {
                        navController.navigateSafely(AwradDestination.CreateDhikr.route)
                    },
                    onNavigateToWird = { wirdId ->
                        navController.navigateSafely(AwradDestination.WirdDetail.createRoute(wirdId))
                    },
                    onCreateWird = {
                        navController.navigateSafely(AwradDestination.WirdCreate.route)
                    },
                )
            }
        }

        composable(AwradDestination.CreateDhikr.route) {
            WrappedAwradDestination(navController) {
                CreateDhikrScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onDhikrCreated = { navController.popBackStack() },
                )
            }
        }

        composable(AwradDestination.Community.route) {
            WrappedAwradDestination(navController) {
                CommunityScreen(
                    onNavigateToLogin = {
                        navController.navigateSafely(AwradDestination.Login.route)
                    },
                    onNavigateToSignup = {
                        navController.navigateSafely(AwradDestination.Signup.route)
                    },
                )
            }
        }

        composable(AwradDestination.Login.route) {
            WrappedAwradDestination(navController) {
                LoginScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToSignup = {
                        navController.navigateSafely(AwradDestination.Signup.route) {
                            popUpTo(AwradDestination.Community.route)
                        }
                    },
                    onNavigateToForgotPassword = {
                        navController.navigateSafely(AwradDestination.ForgotPassword.route)
                    },
                    onLoginSuccess = {
                        navController.popBackStack(AwradDestination.Community.route, inclusive = false)
                    },
                )
            }
        }

        composable(AwradDestination.ForgotPassword.route) {
            WrappedAwradDestination(navController) {
                ForgotPasswordScreen(
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(AwradDestination.Signup.route) {
            WrappedAwradDestination(navController) {
                SignupScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToLogin = {
                        navController.navigateSafely(AwradDestination.Login.route) {
                            popUpTo(AwradDestination.Community.route)
                        }
                    },
                    onSignupSuccess = {
                        navController.popBackStack(AwradDestination.Community.route, inclusive = false)
                    },
                )
            }
        }

        composable(AwradDestination.Settings.route) {
            WrappedAwradDestination(navController) {
                SettingsScreen(onNavigateBack = { navController.navigateUp() })
            }
        }

        composable(
            route = AwradDestination.CreateGoal.route,
            arguments = listOf(navArgument("dhikrId") {
                type = NavType.LongType
                defaultValue = -1L
            }),
        ) {
            WrappedAwradDestination(navController) {
                CreateGoalScreen(
                    onGoalCreated = { goalId ->
                        navController.popBackStack()
                        navController.navigateSafely(AwradDestination.Counting.createRoute(goalId))
                    },
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                )
            }
        }

        composable(
            route = AwradDestination.Category.route,
            arguments = listOf(navArgument("category") { type = NavType.StringType }),
        ) {
            WrappedAwradDestination(navController) {
                CategoryScreen(
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute())
                    },
                    onNavigateToDhikrDetail = { dhikrId ->
                        navController.navigateSafely(AwradDestination.DhikrDetail.createRoute(dhikrId))
                    },
                )
            }
        }

        composable(
            route = AwradDestination.Counting.route,
            arguments = listOf(
                navArgument("goalId") { type = NavType.LongType },
                navArgument("slotId") {
                    type = NavType.LongType
                    defaultValue = -1L
                },
            ),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getLong("goalId") ?: return@composable
            val slotId = backStackEntry.arguments?.getLong("slotId")?.takeIf { it > 0 }
            WrappedAwradDestination(navController) {
                CountingScreen(
                    goalId = goalId,
                    initialSlotId = slotId,
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                    onNavigateToGoalDetail = {
                        navController.navigateSafely(AwradDestination.GoalDetail.createRoute(goalId))
                    },
                )
            }
        }

        composable(
            route = AwradDestination.GoalDetail.route,
            arguments = listOf(navArgument("goalId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getLong("goalId") ?: return@composable
            WrappedAwradDestination(navController) {
                GoalDetailScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToCounting = {
                        navController.returnToCountingFromGoalDetail(goalId)
                    },
                    onNavigateToEdit = {
                        navController.navigateSafely(AwradDestination.EditGoal.createRoute(goalId))
                    },
                    onNavigateToEditSchedule = {
                        navController.navigateSafely(AwradDestination.EditGoalSchedule.createRoute(goalId))
                    },
                    onNavigateToEditReminders = {
                        navController.navigateSafely(AwradDestination.EditGoalReminders.createRoute(goalId))
                    },
                )
            }
        }

        composable(
            route = AwradDestination.EditGoal.route,
            arguments = listOf(navArgument("goalId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getLong("goalId") ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.EditGoalSchedule.route,
            arguments = listOf(navArgument("goalId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getLong("goalId") ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalScheduleScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.EditGoalReminders.route,
            arguments = listOf(navArgument("goalId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getLong("goalId") ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalRemindersScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.DhikrDetail.route,
            arguments = listOf(navArgument("dhikrId") { type = NavType.LongType }),
        ) { backStackEntry ->
            val dhikrId = backStackEntry.arguments?.getLong("dhikrId") ?: return@composable
            WrappedAwradDestination(navController) {
                DhikrDetailScreen(
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute(dhikrId))
                    },
                )
            }
        }

        composable(AwradDestination.WirdList.route) {
            WrappedAwradDestination(navController) {
                WirdListScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToWird = { wirdId ->
                        navController.navigateSafely(AwradDestination.WirdDetail.createRoute(wirdId))
                    },
                    onCreateWird = {
                        navController.navigateSafely(AwradDestination.WirdCreate.route)
                    },
                )
            }
        }

        composable(AwradDestination.WirdCreate.route) {
            WrappedAwradDestination(navController) {
                WirdEditorScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onSaved = { wirdId ->
                        navController.navigateSafely(AwradDestination.WirdDetail.createRoute(wirdId)) {
                            popUpTo(AwradDestination.WirdCreate.route) { inclusive = true }
                        }
                    },
                )
            }
        }

        composable(
            route = AwradDestination.WirdEdit.route,
            arguments = listOf(navArgument("wirdId") { type = NavType.StringType }),
        ) {
            WrappedAwradDestination(navController) {
                WirdEditorScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onSaved = { navController.popBackStack() },
                    onDeleted = {
                        navController.navigateSafely(AwradDestination.WirdList.route) {
                            popUpTo(AwradDestination.WirdList.route) { inclusive = true }
                        }
                    },
                )
            }
        }

        composable(
            route = AwradDestination.WirdDetail.route,
            arguments = listOf(navArgument("wirdId") { type = NavType.StringType }),
        ) {
            WrappedAwradDestination(navController) {
                WirdDetailScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToReader = { wirdId, partId ->
                        navController.navigateSafely(AwradDestination.WirdReader.createRoute(wirdId, partId))
                    },
                    onNavigateToEdit = { wirdId ->
                        navController.navigateSafely(AwradDestination.WirdEdit.createRoute(wirdId))
                    },
                )
            }
        }

        composable(
            route = AwradDestination.WirdReader.route,
            arguments = listOf(
                navArgument("wirdId") { type = NavType.StringType },
                navArgument("partId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val wirdId = backStackEntry.arguments?.getString("wirdId").orEmpty()
            WrappedAwradDestination(navController) {
                WirdReaderScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToPart = { newPartId ->
                        navController.navigateSafely(AwradDestination.WirdReader.createRoute(wirdId, newPartId)) {
                            popUpTo(AwradDestination.WirdReader.route) { inclusive = true }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun WrappedAwradDestination(
    navController: NavController,
    content: @Composable () -> Unit,
) {
    AwradScreenWrapper(
        navController = navController,
        mainRootRoutes = awradMainRootRoutes,
        content = content,
    )
}

private fun NavController.returnToCountingFromGoalDetail(goalId: Long) {
    val previousEntry = previousBackStackEntry
    val previousIsSameCountingGoal =
        previousEntry?.destination?.route == AwradDestination.Counting.route &&
            previousEntry.arguments?.getLong("goalId") == goalId

    if (previousIsSameCountingGoal) {
        popBackStack()
    } else {
        navigateSafely(AwradDestination.Counting.createRoute(goalId)) {
            popUpTo(AwradDestination.GoalDetail.route) {
                inclusive = true
            }
        }
    }
}
