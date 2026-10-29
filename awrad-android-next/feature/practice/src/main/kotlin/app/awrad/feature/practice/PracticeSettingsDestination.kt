package app.awrad.feature.practice

import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/**
 * "Practice settings" (slice 3d): when the day resets, where the phone is, the calculation method, madhab, week
 * start and Hijri corrections, with today's Hijri date and Maghrib. It works signed out and offline.
 */
@Serializable
public data object PracticeSettingsDestination

/** The page: [onBack] leaves it. Choosing a place happens inside it. */
public fun NavGraphBuilder.practiceSettingsScreen(onBack: () -> Unit) {
    composable<PracticeSettingsDestination> { entry ->
        AwradPage(scope = this, key = entry) { PracticeSettingsRoute(onBack = onBack) }
    }
}
