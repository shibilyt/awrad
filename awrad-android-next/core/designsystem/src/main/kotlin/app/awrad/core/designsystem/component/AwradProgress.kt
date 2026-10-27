package app.awrad.core.designsystem.component

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
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

/** A spinner while a page loads, in `progress`. */
@Composable
public fun AwradCircularProgress(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier = modifier, color = AwradTheme.colors.progress)
}
