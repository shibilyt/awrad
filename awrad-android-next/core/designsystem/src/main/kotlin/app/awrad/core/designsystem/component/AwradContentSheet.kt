package app.awrad.core.designsystem.component

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.ZeroCornerSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.theme.AwradContainer
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.LocalAwradContainer

/**
 * The area under a large-title header, such as My Goals (components.md, "Content sheet"): a `surface` fill with
 * `contentSheet` (32) top corners that fills the rest of the screen and scrolls its [content]. Content is inset
 * `pageMargin` and `sectionGap`, items `rowGap` apart; [contentPadding] adds to it (the bottom bar's clearance).
 * Cards and fields inside fill with `background` (it sets [LocalAwradContainer]).
 */
@Composable
public fun AwradContentSheet(
    modifier: Modifier = Modifier,
    scrollState: ScrollState = rememberScrollState(),
    contentPadding: PaddingValues = PaddingValues(),
    content: @Composable ColumnScope.() -> Unit,
) {
    val spacing = AwradTheme.spacing
    val shape = AwradTheme.shapes.contentSheet.copy(bottomStart = ZeroCornerSize, bottomEnd = ZeroCornerSize)
    CompositionLocalProvider(
        LocalAwradContainer provides AwradContainer.Surface,
        LocalContentColor provides AwradTheme.colors.onSurface,
    ) {
        Column(
            modifier = modifier
                .fillMaxSize()
                .clip(shape)
                .background(AwradTheme.colors.surface)
                .verticalScroll(scrollState)
                .padding(contentPadding)
                .padding(horizontal = spacing.pageMargin, vertical = spacing.sectionGap),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
            content = content,
        )
    }
}

/** A section's title inside a content sheet or page: `sectionTitle`, `onSurface`, marked as a heading. */
@Composable
public fun AwradSectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier.semantics { heading() },
        style = AwradTheme.type.sectionTitle,
        color = AwradTheme.colors.onSurface,
    )
}
