package app.awrad.core.designsystem.component

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.theme.AwradTheme

/** A thin bar (`ringStroke` high) while work of unknown length runs, in `progress` on an `outline` track. */
@Composable
public fun AwradLinearProgress(modifier: Modifier = Modifier) {
    LinearProgressIndicator(
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.ringStroke),
        color = AwradTheme.colors.progress,
        trackColor = AwradTheme.colors.outline,
    )
}

/**
 * A thin bar (`ringStroke` high) for work of known length, such as audio playing: [progress] (0 to 1, read in the
 * draw phase) in `progress` on an `outline` track, without Material's gap or end dot.
 */
@Composable
public fun AwradLinearProgress(progress: () -> Float, modifier: Modifier = Modifier) {
    LinearProgressIndicator(
        progress = progress,
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.ringStroke),
        color = AwradTheme.colors.progress,
        trackColor = AwradTheme.colors.outline,
        strokeCap = StrokeCap.Round,
        gapSize = 0.dp,
        drawStopIndicator = {},
    )
}

/** A spinner while a page loads, in `progress`. */
@Composable
public fun AwradCircularProgress(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier = modifier, color = AwradTheme.colors.progress)
}
