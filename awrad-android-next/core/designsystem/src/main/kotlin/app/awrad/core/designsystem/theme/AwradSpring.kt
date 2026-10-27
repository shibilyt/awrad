package app.awrad.core.designsystem.theme

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Immutable

/**
 * A spring from `motion.json` (mass 1). [spec] makes the Compose spring; iOS converts the same numbers with
 * `response = 2π / √stiffness`, `dampingFraction = dampingRatio`. Prefer `AwradTheme.motion`, which swaps springs
 * for a cross-fade under reduced motion.
 */
@Immutable
public class AwradSpring(public val dampingRatio: Float, public val stiffness: Float) {

    /** `spring(dampingRatio, stiffness)`, settling within [visibilityThreshold] when given. */
    public fun <T> spec(visibilityThreshold: T? = null): SpringSpec<T> =
        spring(dampingRatio = dampingRatio, stiffness = stiffness, visibilityThreshold = visibilityThreshold)

    override fun equals(other: Any?): Boolean =
        other is AwradSpring && dampingRatio == other.dampingRatio && stiffness == other.stiffness

    override fun hashCode(): Int = HASH * dampingRatio.hashCode() + stiffness.hashCode()

    override fun toString(): String = "AwradSpring(dampingRatio=$dampingRatio, stiffness=$stiffness)"

    private companion object {
        const val HASH = 31
    }
}
