package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.lifecycle.Lifecycle
import androidx.navigation.NavController
import androidx.navigation.NavOptionsBuilder

private val LayeredEasing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
private const val MainRootTransitionDuration = 300
private const val MainRootFadeInDuration = 240
private const val MainRootFadeOutDuration = 160
private const val DepthTransitionDuration = 320
private const val DepthPopFadeDuration = 220

val awradMainRootRoutes = setOf(
    AwradDestination.Home.route,
    AwradDestination.Goals.route,
    AwradDestination.Library.route,
    AwradDestination.Community.route,
)

private fun mainRootRouteIndex(route: String?): Int? = when (route) {
    AwradDestination.Home.route -> 0
    AwradDestination.Goals.route -> 1
    AwradDestination.Library.route -> 2
    AwradDestination.Community.route -> 3
    else -> null
}

private fun isMainRootTransition(fromRoute: String?, toRoute: String?): Boolean {
    val fromIndex = mainRootRouteIndex(fromRoute) ?: return false
    val toIndex = mainRootRouteIndex(toRoute) ?: return false
    return fromIndex != toIndex
}

private fun mainRootEnterTransition(): EnterTransition =
    scaleIn(
        animationSpec = tween(MainRootTransitionDuration, easing = LayeredEasing),
        initialScale = 0.985f,
    ) + fadeIn(
        animationSpec = tween(MainRootFadeInDuration, easing = LayeredEasing),
        initialAlpha = 0.4f,
    )

private fun mainRootExitTransition(): ExitTransition =
    scaleOut(
        animationSpec = tween(MainRootTransitionDuration, easing = LayeredEasing),
        targetScale = 1.01f,
    ) + fadeOut(
        animationSpec = tween(MainRootFadeOutDuration, easing = LayeredEasing),
    )

fun awradEnterTransition(fromRoute: String?, toRoute: String?): EnterTransition {
    if (isMainRootTransition(fromRoute, toRoute)) {
        return mainRootEnterTransition()
    }

    return scaleIn(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        initialScale = 0.96f,
    ) + fadeIn(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        initialAlpha = 0.35f,
    )
}

fun awradExitTransition(fromRoute: String?, toRoute: String?): ExitTransition {
    if (isMainRootTransition(fromRoute, toRoute)) {
        return mainRootExitTransition()
    }

    return scaleOut(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        targetScale = 0.985f,
    )
}

fun awradPopEnterTransition(fromRoute: String?, toRoute: String?): EnterTransition {
    if (isMainRootTransition(fromRoute, toRoute)) {
        return mainRootEnterTransition()
    }

    return scaleIn(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        initialScale = 0.985f,
    ) + fadeIn(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        initialAlpha = 0.6f,
    )
}

fun awradPopExitTransition(fromRoute: String?, toRoute: String?): ExitTransition {
    if (isMainRootTransition(fromRoute, toRoute)) {
        return mainRootExitTransition()
    }

    return scaleOut(
        animationSpec = tween(DepthTransitionDuration, easing = LayeredEasing),
        targetScale = 0.96f,
    ) + fadeOut(
        animationSpec = tween(DepthPopFadeDuration, easing = LayeredEasing),
    )
}

private fun NavController.isReadyForNavigation(): Boolean =
    currentBackStackEntry?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.STARTED) == true

fun NavController.navigateSafely(route: String): Boolean {
    if (!isReadyForNavigation()) return false
    navigate(route) { launchSingleTop = true }
    return true
}

fun NavController.navigateSafely(
    route: String,
    builder: NavOptionsBuilder.() -> Unit,
): Boolean {
    if (!isReadyForNavigation()) return false
    navigate(route) {
        launchSingleTop = true
        builder()
    }
    return true
}

fun NavController.navigateTopLevelSafely(route: String): Boolean {
    if (!isReadyForNavigation()) return false
    navigate(route) {
        popUpTo(graph.startDestinationId) {
            saveState = true
        }
        launchSingleTop = true
        restoreState = true
    }
    return true
}
