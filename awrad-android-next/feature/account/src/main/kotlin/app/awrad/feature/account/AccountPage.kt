package app.awrad.feature.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.component.AwradLinearProgress
import app.awrad.core.designsystem.motion.AwradContentSwap
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * The frame of every account page: Back, the title, a progress line while [isBusy], the [status], then
 * [content]. Scrolls, and keeps clear of system bars and the keyboard. A new title, the progress line and the
 * status cross-fade in place (`contentSwap`).
 */
@Composable
internal fun AccountPage(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    isBusy: Boolean = false,
    status: PageStatus? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .safeDrawingPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AwradTheme.spacing.pageMargin, vertical = AwradTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.lg),
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.account_action_back),
                )
            }
            AwradContentSwap(targetState = title, label = "title") { text ->
                Text(text = text, modifier = Modifier.semantics { heading() }, style = AwradTheme.type.title)
            }
            // One item, so an absent status adds no gap.
            Column {
                BusyIndicator(isBusy = isBusy)
                StatusMessage(status = status)
            }
            content()
        }
    }
}

/** Keeps its height while idle, so the form doesn't jump when a request starts. */
@Composable
private fun BusyIndicator(isBusy: Boolean, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth().height(AwradTheme.sizes.ringStroke)) {
        AwradContentSwap(targetState = isBusy, label = "busy") { busy ->
            if (busy) AwradLinearProgress()
        }
    }
}

/**
 * Announced by screen readers when it changes. Appearing, changing and going, it cross-fades in place while the
 * page makes room for it (`contentSwap`).
 */
@Composable
private fun StatusMessage(status: PageStatus?, modifier: Modifier = Modifier) {
    AwradContentSwap(targetState = status, modifier = modifier, label = "status") { shown ->
        if (shown != null) {
            Text(
                text = shown.text,
                modifier = Modifier
                    .padding(top = AwradTheme.spacing.lg)
                    .semantics { liveRegion = LiveRegionMode.Polite },
                style = AwradTheme.type.bodySmall,
                color = if (shown.isError) AwradTheme.colors.error else AwradTheme.colors.accent,
            )
        }
    }
}

/** The status for an error, or else a notice; null when there's neither. */
@Composable
internal fun pageStatus(error: Int?, notice: Int?): PageStatus? = when {
    error != null -> PageStatus(stringResource(error), isError = true)
    notice != null -> PageStatus(stringResource(notice), isError = false)
    else -> null
}
