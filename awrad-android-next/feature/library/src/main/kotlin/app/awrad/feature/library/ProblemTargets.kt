package app.awrad.feature.library

import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester

/**
 * Where the editor's problems show, so a failed save can take the reader to the first one even when it's above
 * what's on screen: it scrolls the spot into view, then moves focus there. A field with focus is read out by a
 * screen reader with its error, and the summary line is focusable for the same reason.
 */
@Stable
internal class ProblemTargets {
    private val views = mutableMapOf<ProblemSpot, BringIntoViewRequester>()
    private val focusers = mutableMapOf<ProblemSpot, FocusRequester>()

    fun view(spot: ProblemSpot): BringIntoViewRequester = views.getOrPut(spot) { BringIntoViewRequester() }

    fun focus(spot: ProblemSpot): FocusRequester = focusers.getOrPut(spot) { FocusRequester() }

    /** Scrolls to [spot] and focuses it; a spot nothing marked is skipped. */
    suspend fun reveal(spot: ProblemSpot) {
        val focuser = focusers[spot] ?: return
        views[spot]?.bringIntoView()
        focuser.requestFocus()
    }
}

/**
 * Marks where [spot] shows, for [targets]. Mark each spot once at most, before the spot's own modifiers; a spot
 * without a focusable element of its own focuses the first one inside it.
 */
internal fun Modifier.problemSpot(targets: ProblemTargets, spot: ProblemSpot): Modifier =
    bringIntoViewRequester(targets.view(spot)).focusRequester(targets.focus(spot))

/** The editor's [ProblemTargets], revealing the first problem after each failed save. */
@Composable
internal fun rememberProblemTargets(state: EditorUiState): ProblemTargets {
    val targets = remember { ProblemTargets() }
    LaunchedEffect(state.failedSaves) {
        if (state.failedSaves > 0) state.firstProblemSpot()?.let { targets.reveal(it) }
    }
    return targets
}
