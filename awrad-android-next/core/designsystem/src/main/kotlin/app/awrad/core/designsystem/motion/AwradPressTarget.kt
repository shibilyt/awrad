package app.awrad.core.designsystem.motion

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.node.CompositionLocalConsumerModifierNode
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.currentValueOf
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import app.awrad.core.designsystem.theme.AwradEasing
import app.awrad.core.designsystem.theme.AwradMotions.Press
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** What is pressed, which sets how far it shrinks (`press` in `motion.json`). */
public enum class AwradPressTarget(internal val scale: Float) {
    /** A card: to 0.985. */
    Card(Press.cardScale),

    /** A button: to 0.98. */
    Button(Press.buttonScale),
}

/**
 * `press` feedback: while [interactionSource] is pressed, the element shrinks to its [target]'s scale over
 * `pressDuration`; released, it springs back on `spatialFast`. Pass the same [interactionSource] to the
 * clickable. The scale is applied in the element's layer, so a press neither recomposes nor re-lays out
 * anything. Under reduced motion it doesn't scale (the ripple still shows the press).
 */
public fun Modifier.pressFeedback(interactionSource: InteractionSource, target: AwradPressTarget): Modifier =
    this then PressFeedbackElement(interactionSource, target.scale)

private const val HASH = 31

private val PressSpec = tween<Float>(Press.pressDurationMillis, easing = AwradEasing.emphasized)

// Not a data class: its generated copy() returns a Modifier without a receiver, which crashes Compose's lint check.
private class PressFeedbackElement(
    val interactionSource: InteractionSource,
    val pressedScale: Float,
) : ModifierNodeElement<PressFeedbackNode>() {
    override fun create(): PressFeedbackNode = PressFeedbackNode(interactionSource, pressedScale)

    override fun update(node: PressFeedbackNode) {
        node.update(interactionSource, pressedScale)
    }

    override fun equals(other: Any?): Boolean = other is PressFeedbackElement &&
        interactionSource == other.interactionSource && pressedScale == other.pressedScale

    override fun hashCode(): Int = HASH * interactionSource.hashCode() + pressedScale.hashCode()

    override fun InspectorInfo.inspectableProperties() {
        name = "pressFeedback"
        properties["pressedScale"] = pressedScale
    }
}

private class PressFeedbackNode(
    private var interactionSource: InteractionSource,
    private var pressedScale: Float,
) : Modifier.Node(), LayoutModifierNode, CompositionLocalConsumerModifierNode {

    private val scale = Animatable(1f)
    private var collecting: Job? = null

    override fun onAttach() {
        collect()
    }

    fun update(interactionSource: InteractionSource, pressedScale: Float) {
        this.pressedScale = pressedScale
        if (interactionSource != this.interactionSource) {
            this.interactionSource = interactionSource
            if (isAttached) collect()
        }
    }

    private fun collect() {
        collecting?.cancel()
        collecting = coroutineScope.launch {
            val presses = mutableListOf<PressInteraction.Press>()
            interactionSource.interactions.collect { interaction ->
                when (interaction) {
                    is PressInteraction.Press -> presses += interaction
                    is PressInteraction.Release -> presses -= interaction.press
                    is PressInteraction.Cancel -> presses -= interaction.press
                }
                animate(isPressed = presses.isNotEmpty())
            }
        }
    }

    private fun animate(isPressed: Boolean) {
        val motion = currentValueOf(LocalAwradMotion)
        coroutineScope.launch {
            when {
                motion.isReduced -> scale.snapTo(1f)
                // The tokens give the press a duration only; it eases like the page transitions.
                isPressed -> scale.animateTo(pressedScale, PressSpec)
                else -> scale.animateTo(1f, Press.releaseSpring.spec())
            }
        }
    }

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            placeable.placeWithLayer(0, 0) {
                val value = scale.value
                scaleX = value
                scaleY = value
            }
        }
    }
}
