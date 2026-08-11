package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import app.awrad.awrad_dhikrgoalstracker.data.repository.VerificationOrigin
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradScreenWrapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.category.CategoryScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.CountingScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.CountingViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail.DhikrDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail.QuranDhikrReaderScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalRemindersScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalScheduleScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.EditGoalScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.GoalDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.CreateGoalScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.GoalsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.home.HomeScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryCollectionScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryFeaturedCollection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding.OnboardingScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.settings.SettingsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.ForgotPasswordScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.LoginScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.SignupScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.VerificationScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityChallengesScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityCirclesScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityPostDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityProfileScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunitySavedScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityStatsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityMessagesScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.community.CommunityNotificationsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr.CreateDhikrScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.managetags.ManageTagsScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdDetailScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdEditorScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdListScreen
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdReaderScreen
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.util.UUID

@Composable
fun AwradNavGraph(
    navController: NavHostController,
    startDestination: String,
    modifier: Modifier = Modifier,
    onOpenCommunityMenu: () -> Unit = {},
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
                onNavigateToVerification = {
                    navController.navigate(AwradDestination.VerifyEmail.createRoute()) {
                        launchSingleTop = true
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
                    onNavigateToCollection = { collection ->
                        navController.navigateSafely(AwradDestination.LibraryCollection.createRoute(collection))
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
                    onNavigateToCollection = { collection ->
                        navController.navigateSafely(AwradDestination.LibraryCollection.createRoute(collection))
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute())
                    },
                    onNavigateToDhikrDetail = { dhikrId ->
                        navController.navigateSafely(AwradDestination.DhikrDetail.createRoute(dhikrId))
                    },
                    onNavigateToCreateDhikr = {
                        navController.navigateSafely(AwradDestination.CreateDhikr.createRoute())
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

        composable(
            route = AwradDestination.LibraryCollection.route,
            arguments = listOf(navArgument("collection") { type = NavType.StringType }),
        ) { backStackEntry ->
            val collection = LibraryFeaturedCollection.fromRouteValue(
                backStackEntry.arguments?.getString("collection"),
            ) ?: return@composable
            WrappedAwradDestination(navController) {
                LibraryCollectionScreen(
                    collection = collection,
                    onNavigateBack = { navController.popBackStack() },
                    onNavigateToDhikrDetail = { dhikrId ->
                        navController.navigateSafely(AwradDestination.DhikrDetail.createRoute(dhikrId))
                    },
                    onNavigateToCreateDhikr = {
                        navController.navigateSafely(AwradDestination.CreateDhikr.createRoute())
                    },
                )
            }
        }

        composable(
            route = AwradDestination.CreateDhikr.route,
            arguments = listOf(
                navArgument("dhikrId") {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                },
            ),
        ) {
            WrappedAwradDestination(navController) {
                CreateDhikrScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onDhikrCreated = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.ManageTags.route,
            arguments = listOf(navArgument("dhikrId") { type = NavType.StringType }),
        ) {
            WrappedAwradDestination(navController) {
                ManageTagsScreen(
                    onNavigateBack = { navController.popBackStack() },
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
                    onNavigateToVerification = {
                        navController.navigateSafely(AwradDestination.VerifyEmail.createRoute())
                    },
                    onNavigateToStats = { navController.navigateSafely(AwradDestination.CommunityStats.route) },
                    onNavigateToCircles = { navController.navigateSafely(AwradDestination.CommunityCircles.route) },
                    onNavigateToSaved = { navController.navigateSafely(AwradDestination.CommunitySaved.route) },
                    onNavigateToPost = { navController.navigateSafely(AwradDestination.CommunityPostDetail.route) },
                    onNavigateToMessages = { navController.navigateSafely(AwradDestination.CommunityMessages.route) },
                    onNavigateToNotifications = {
                        navController.navigateSafely(AwradDestination.CommunityNotifications.route)
                    },
                    onOpenMenu = onOpenCommunityMenu,
                )
            }
        }

        composable(AwradDestination.CommunityStats.route) {
            WrappedAwradDestination(navController) { CommunityStatsScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityChallenges.route) {
            WrappedAwradDestination(navController) { CommunityChallengesScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityCircles.route) {
            WrappedAwradDestination(navController) { CommunityCirclesScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunitySaved.route) {
            WrappedAwradDestination(navController) { CommunitySavedScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityProfile.route) {
            WrappedAwradDestination(navController) { CommunityProfileScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityPostDetail.route) {
            WrappedAwradDestination(navController) { CommunityPostDetailScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityMessages.route) {
            WrappedAwradDestination(navController) { CommunityMessagesScreen(onNavigateBack = navController::navigateUp) }
        }
        composable(AwradDestination.CommunityNotifications.route) {
            WrappedAwradDestination(navController) {
                CommunityNotificationsScreen(onNavigateBack = navController::navigateUp)
            }
        }

        composable(
            route = AwradDestination.Login.route,
            arguments = listOf(navArgument("email") {
                type = NavType.StringType
                nullable = true
                defaultValue = null
            }, navArgument("origin") {
                type = NavType.StringType
                nullable = true
                defaultValue = null
            }),
        ) { backStackEntry ->
            val loginOrigin = VerificationOrigin.entries.firstOrNull {
                it.storageValue == backStackEntry.arguments?.getString("origin")
            } ?: VerificationOrigin.Account
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
                        if (loginOrigin == VerificationOrigin.Onboarding) {
                            navController.popBackStack()
                        } else {
                            navController.popBackStack(AwradDestination.Community.route, inclusive = false)
                        }
                    },
                    onVerificationRequired = {
                        navController.navigateSafely(AwradDestination.VerifyEmail.createRoute()) {
                            popUpTo(AwradDestination.Login.route) { inclusive = true }
                        }
                    },
                    initialEmail = backStackEntry.arguments?.getString("email").orEmpty(),
                    origin = loginOrigin,
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
                    onVerificationRequired = {
                        navController.navigateSafely(AwradDestination.VerifyEmail.createRoute()) {
                            popUpTo(AwradDestination.Signup.route) { inclusive = true }
                        }
                    },
                )
            }
        }

        composable(
            route = AwradDestination.VerifyEmail.route,
            arguments = listOf(navArgument("token") {
                type = NavType.StringType
                nullable = true
                defaultValue = null
            }),
        ) { backStackEntry ->
            WrappedAwradDestination(navController) {
                VerificationScreen(
                    token = backStackEntry.arguments?.getString("token"),
                    onNavigateBack = { navController.popBackStack() },
                    onVerified = {
                        if (navController.previousBackStackEntry?.destination?.route == AwradDestination.Onboarding.route) {
                            navController.popBackStack()
                        } else {
                            navController.navigate(AwradDestination.Community.route) {
                                popUpTo(AwradDestination.Home.route) { inclusive = false }
                                launchSingleTop = true
                            }
                        }
                    },
                    onSignIn = { email, origin ->
                        navController.navigate(
                            AwradDestination.Login.createRoute(email, origin.storageValue),
                        ) {
                            popUpTo(AwradDestination.VerifyEmail.route) { inclusive = true }
                        }
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
                type = NavType.StringType
                nullable = true
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
                    onNavigateToQuranReader = { dhikrId ->
                        navController.navigateSafely(AwradDestination.QuranDhikrReader.createRoute(dhikrId))
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
                navArgument("goalId") { type = NavType.StringType },
                navArgument("slotId") {
                    type = NavType.StringType
                    nullable = true
                },
            ),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull() ?: return@composable
            val slotId = backStackEntry.arguments?.getString("slotId")?.toAwradIdOrNull()
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
                    onNavigateToQuranReader = { dhikrId, slotId ->
                        navController.navigateSafely(
                            AwradDestination.QuranDhikrReader.createRoute(dhikrId, goalId, slotId),
                        )
                    },
                )
            }
        }

        composable(
            route = AwradDestination.GoalDetail.route,
            arguments = listOf(navArgument("goalId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull() ?: return@composable
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
            arguments = listOf(navArgument("goalId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull() ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.EditGoalSchedule.route,
            arguments = listOf(navArgument("goalId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull() ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalScheduleScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.EditGoalReminders.route,
            arguments = listOf(navArgument("goalId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull() ?: return@composable
            WrappedAwradDestination(navController) {
                EditGoalRemindersScreen(
                    goalId = goalId,
                    onNavigateBack = { navController.popBackStack() },
                )
            }
        }

        composable(
            route = AwradDestination.DhikrDetail.route,
            arguments = listOf(navArgument("dhikrId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val dhikrId = backStackEntry.arguments?.getString("dhikrId")?.toAwradIdOrNull() ?: return@composable
            WrappedAwradDestination(navController) {
                DhikrDetailScreen(
                    onNavigateBack = {
                        navController.popBackStack()
                    },
                    onNavigateToCreateGoal = {
                        navController.navigateSafely(AwradDestination.CreateGoal.createRoute(dhikrId))
                    },
                    onNavigateToQuranReader = { readerDhikrId ->
                        navController.navigateSafely(AwradDestination.QuranDhikrReader.createRoute(readerDhikrId))
                    },
                    onNavigateToEditDhikr = { editId ->
                        navController.navigateSafely(AwradDestination.CreateDhikr.createRoute(editId))
                    },
                    onNavigateToManageTags = { tagDhikrId ->
                        navController.navigateSafely(AwradDestination.ManageTags.createRoute(tagDhikrId))
                    },
                )
            }
        }

        composable(
            route = AwradDestination.QuranDhikrReader.route,
            arguments = listOf(
                navArgument("dhikrId") { type = NavType.StringType },
                navArgument("goalId") { type = NavType.StringType; nullable = true },
                navArgument("slotId") { type = NavType.StringType; nullable = true },
            ),
        ) { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId")?.toAwradIdOrNull()
            val slotId = backStackEntry.arguments?.getString("slotId")?.toAwradIdOrNull()
            val countingEntry = navController.previousBackStackEntry
                ?.takeIf { goalId != null && it.destination.route == AwradDestination.Counting.route }
            val readerCountingViewModel = countingEntry?.let {
                hiltViewModel<CountingViewModel>(it)
            } ?: hiltViewModel(backStackEntry)
            WrappedAwradDestination(navController) {
                QuranDhikrReaderScreen(
                    goalId = goalId,
                    initialSlotId = slotId,
                    onNavigateBack = { navController.popBackStack() },
                    countingViewModel = readerCountingViewModel,
                    bindCountingContext = countingEntry == null,
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

private fun NavController.returnToCountingFromGoalDetail(goalId: AwradId) {
    val previousEntry = previousBackStackEntry
    val previousIsSameCountingGoal =
        previousEntry?.destination?.route == AwradDestination.Counting.route &&
            previousEntry.arguments?.getString("goalId")?.toAwradIdOrNull() == goalId

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

private fun String.toAwradIdOrNull(): AwradId? = runCatching(UUID::fromString).getOrNull()
