package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.ui.graphics.TransformOrigin
import androidx.lifecycle.Lifecycle
import androidx.navigation.NavController
import androidx.navigation.NavOptionsBuilder

private val EmphasizedDecelerateEasing = CubicBezierEasing(0.2f, 0.85f, 0.7f, 1f)
private val EmphasizedAccelerateEasing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)
private const val TransitionDuration = 420

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

fun awradEnterTransition(fromRoute: String?, toRoute: String?): EnterTransition {
    val fromIndex = mainRootRouteIndex(fromRoute)
    val toIndex = mainRootRouteIndex(toRoute)
    if (fromIndex != null && toIndex != null) {
        val direction = if (toIndex >= fromIndex) 1 else -1
        return slideInHorizontally(
            animationSpec = tween(240, easing = EmphasizedDecelerateEasing),
            initialOffsetX = { direction * (it * 0.16f).toInt() },
        ) + fadeIn(animationSpec = tween(180))
    }

    return slideInHorizontally(
        animationSpec = tween(TransitionDuration, easing = EmphasizedDecelerateEasing),
        initialOffsetX = { (it * 0.45f).toInt() },
    ) + scaleIn(
        animationSpec = tween(TransitionDuration, easing = EmphasizedDecelerateEasing),
        initialScale = 0.94f,
        transformOrigin = TransformOrigin(0.5f, 0.5f),
    ) + fadeIn(
        animationSpec = tween(TransitionDuration, easing = EmphasizedAccelerateEasing),
    )
}

fun awradExitTransition(fromRoute: String?, toRoute: String?): ExitTransition {
    val fromIndex = mainRootRouteIndex(fromRoute)
    val toIndex = mainRootRouteIndex(toRoute)
    if (fromIndex != null && toIndex != null) {
        val direction = if (toIndex >= fromIndex) -1 else 1
        return slideOutHorizontally(
            animationSpec = tween(220, easing = EmphasizedAccelerateEasing),
            targetOffsetX = { direction * (it * 0.12f).toInt() },
        ) + fadeOut(animationSpec = tween(150))
    }

    return slideOutHorizontally(
        animationSpec = tween(TransitionDuration, easing = EmphasizedAccelerateEasing),
        targetOffsetX = { -(it * 0.18f).toInt() },
    ) + fadeOut(
        animationSpec = tween(TransitionDuration / 2, easing = EmphasizedAccelerateEasing),
    )
}

fun awradPopEnterTransition(fromRoute: String?, toRoute: String?): EnterTransition =
    slideInHorizontally(
        animationSpec = tween(TransitionDuration, easing = EmphasizedDecelerateEasing),
        initialOffsetX = { -(it * 0.22f).toInt() },
    ) + scaleIn(
        animationSpec = tween(TransitionDuration, easing = EmphasizedDecelerateEasing),
        initialScale = 0.96f,
    ) + fadeIn(
        animationSpec = tween(TransitionDuration / 2, easing = EmphasizedDecelerateEasing),
    )

fun awradPopExitTransition(fromRoute: String?, toRoute: String?): ExitTransition =
    slideOutHorizontally(
        animationSpec = tween(TransitionDuration, easing = EmphasizedAccelerateEasing),
        targetOffsetX = { (it * 0.45f).toInt() },
    ) + scaleOut(
        animationSpec = tween(TransitionDuration, easing = EmphasizedAccelerateEasing),
        targetScale = 0.94f,
        transformOrigin = TransformOrigin(0.5f, 0.5f),
    ) + fadeOut(
        animationSpec = tween(TransitionDuration / 2, easing = EmphasizedAccelerateEasing),
    )

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
