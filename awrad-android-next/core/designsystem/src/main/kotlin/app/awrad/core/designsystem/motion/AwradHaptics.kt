package app.awrad.core.designsystem.motion

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalView
import app.awrad.core.designsystem.theme.AwradHaptic

/**
 * Haptic feedback by meaning (`haptic` in `motion.json`): [tick] for a count, a tab or a step, [threshold] for
 * crossing a release point, [success] for reaching a target. It uses the view's haptic feedback, so it follows
 * the system's touch-feedback setting and needs no permission. Haptics stay under reduced motion.
 */
@Stable
public class AwradHaptics internal constructor(private val view: View) {
    public fun perform(haptic: AwradHaptic) {
        view.performHapticFeedback(haptic.feedbackConstant())
    }

    public fun tick() {
        perform(AwradHaptic.Tick)
    }

    public fun threshold() {
        perform(AwradHaptic.Threshold)
    }

    public fun success() {
        perform(AwradHaptic.Success)
    }
}

/** The haptics of the current view. */
@Composable
public fun rememberAwradHaptics(): AwradHaptics {
    val view = LocalView.current
    return remember(view) { AwradHaptics(view) }
}

/**
 * The platform feedback for each meaning. Before API 34 a threshold is a long press, and before API 30 a success
 * is too: the contract's alternative, a one-second vibration, would need the VIBRATE permission.
 */
internal fun AwradHaptic.feedbackConstant(): Int = when (this) {
    AwradHaptic.Tick -> HapticFeedbackConstants.CLOCK_TICK
    AwradHaptic.Threshold -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE
    } else {
        HapticFeedbackConstants.LONG_PRESS
    }
    AwradHaptic.Success -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        HapticFeedbackConstants.CONFIRM
    } else {
        HapticFeedbackConstants.LONG_PRESS
    }
}
