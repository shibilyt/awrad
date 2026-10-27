package app.awrad.core.designsystem.component

import androidx.compose.ui.semantics.Role

/*
 * The state rules behind the components, kept apart from drawing so unit tests can check them.
 */

/** What shows under a text field: an error (with the `error` border) or a hint. */
internal sealed interface FieldMessage {
    val text: String

    data class Error(override val text: String) : FieldMessage

    data class Hint(override val text: String) : FieldMessage
}

/**
 * The message under a field. An error wins over [supportingText]. A blank [error] is no error: the border never
 * appears without a message to explain it.
 */
internal fun fieldMessage(error: String?, supportingText: String?): FieldMessage? = when {
    !error.isNullOrBlank() -> FieldMessage.Error(error)
    !supportingText.isNullOrBlank() -> FieldMessage.Hint(supportingText)
    else -> null
}

/** One square of the step indicator. */
internal enum class StepState { Done, Current, Ahead }

/** The squares for [step] (1-based) of [count]: done before it, then the current one, then those ahead. */
internal fun stepStates(step: Int, count: Int): List<StepState> {
    require(count >= 1) { "A flow has at least one step, was $count" }
    require(step in 1..count) { "step must be in 1..$count, was $step" }
    return List(count) { index ->
        when {
            index + 1 < step -> StepState.Done
            index + 1 == step -> StepState.Current
            else -> StepState.Ahead
        }
    }
}

/** The accessibility role of an option row in [mode]. */
internal fun optionRowRole(mode: AwradSelectionMode): Role = when (mode) {
    AwradSelectionMode.Single -> Role.RadioButton
    AwradSelectionMode.Multiple -> Role.Checkbox
}

/** Segmented pills hold two to four views. */
internal val SegmentCount: IntRange = 2..4

/** Checks a segmented control's options and selection. */
internal fun requireSegments(count: Int, selectedIndex: Int) {
    require(count in SegmentCount) { "Segmented pills hold ${SegmentCount.first} to ${SegmentCount.last}, was $count" }
    require(selectedIndex in 0 until count) { "selectedIndex must be in 0 until $count, was $selectedIndex" }
}

/** The index to report when [tapped] is tapped while [selectedIndex] is selected: null when it already is. */
internal fun segmentToSelect(selectedIndex: Int, tapped: Int): Int? = tapped.takeIf { it != selectedIndex }
