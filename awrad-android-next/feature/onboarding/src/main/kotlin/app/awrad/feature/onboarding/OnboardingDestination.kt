package app.awrad.feature.onboarding

import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/** Type-safe destination: no route strings, no hand-parsed arguments. */
@Serializable
public data object OnboardingDestination

/** The feature's whole public interface: one destination and one exit callback. */
public fun NavGraphBuilder.onboardingScreen(onFinish: () -> Unit) {
    composable<OnboardingDestination> { entry ->
        AwradPage(scope = this, key = entry) { OnboardingRoute(onFinish = onFinish) }
    }
}
