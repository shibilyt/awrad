package app.awrad.core.designsystem.motion

import android.content.ContentResolver
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode

/** The system settings that turn animations off; any of them at 0 asks for reduced motion. */
private val AnimationScales = listOf(
    Settings.Global.ANIMATOR_DURATION_SCALE,
    Settings.Global.TRANSITION_ANIMATION_SCALE,
)

/**
 * Whether the system asks for reduced motion. Android has no separate flag: the accessibility setting "Remove
 * animations" (and the developer options) set the animation scales to 0, so a 0 animator-duration or
 * transition scale means reduced motion.
 */
internal fun isReducedMotion(animatorDurationScale: Float, transitionAnimationScale: Float): Boolean =
    animatorDurationScale == 0f || transitionAnimationScale == 0f

private fun ContentResolver.isReducedMotion(): Boolean = isReducedMotion(
    animatorDurationScale = Settings.Global.getFloat(this, Settings.Global.ANIMATOR_DURATION_SCALE, 1f),
    transitionAnimationScale = Settings.Global.getFloat(this, Settings.Global.TRANSITION_ANIMATION_SCALE, 1f),
)

/** The system's reduced-motion setting, updated while the app runs when the user changes it. Off in previews. */
@Composable
internal fun rememberSystemReducedMotion(): Boolean {
    if (LocalInspectionMode.current) return false
    val resolver = LocalContext.current.contentResolver
    var isReduced by remember(resolver) { mutableStateOf(resolver.isReducedMotion()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                isReduced = resolver.isReducedMotion()
            }
        }
        AnimationScales.forEach { resolver.registerContentObserver(Settings.Global.getUriFor(it), false, observer) }
        isReduced = resolver.isReducedMotion()
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return isReduced
}
