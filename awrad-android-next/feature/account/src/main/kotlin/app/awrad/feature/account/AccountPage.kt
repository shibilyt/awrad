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
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.component.AwradLinearProgress
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * The frame of every account page: Back, the title, a progress line while [isBusy], the [status], then
 * [content]. Scrolls, and keeps clear of system bars and the keyboard.
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
                .padding(horizontal = 28.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.account_action_back),
                )
            }
            Text(
                text = title,
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.headlineMedium,
            )
            BusyIndicator(isBusy = isBusy)
            if (status != null) StatusMessage(status = status)
            content()
        }
    }
}

/** Keeps its height while idle, so the form doesn't jump when a request starts. */
@Composable
private fun BusyIndicator(isBusy: Boolean, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth().height(4.dp)) {
        if (isBusy) AwradLinearProgress()
    }
}

/** Announced by screen readers when it changes. */
@Composable
private fun StatusMessage(status: PageStatus, modifier: Modifier = Modifier) {
    Text(
        text = status.text,
        modifier = modifier.semantics { liveRegion = LiveRegionMode.Polite },
        style = MaterialTheme.typography.bodyMedium,
        color = if (status.isError) AwradTheme.colors.error else AwradTheme.colors.accent,
    )
}

/** The status for an error, or else a notice; null when there's neither. */
@Composable
internal fun pageStatus(error: Int?, notice: Int?): PageStatus? = when {
    error != null -> PageStatus(stringResource(error), isError = true)
    notice != null -> PageStatus(stringResource(notice), isError = false)
    else -> null
}
