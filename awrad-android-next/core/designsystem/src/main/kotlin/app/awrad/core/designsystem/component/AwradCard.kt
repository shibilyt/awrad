package app.awrad.core.designsystem.component

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.theme.AwradContainer
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.LocalAwradContainer

/**
 * Grouped content on a `surface` fill with the `card` shape, without a border or shadow. Its rows are separated
 * by spacing, never by divider lines. Fields and secondary buttons inside fill with `background` (it sets
 * [LocalAwradContainer]). A list of rows that pad themselves (such as `ListItem`) passes a smaller
 * [contentPadding] and no [spacing].
 */
@Composable
public fun AwradCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(AwradTheme.spacing.cardPadding),
    spacing: Dp = AwradTheme.spacing.rowGap,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = AwradTheme.shapes.card,
        color = AwradTheme.colors.surface,
        contentColor = AwradTheme.colors.onSurface,
    ) {
        CardContent(contentPadding = contentPadding, spacing = spacing, content = content)
    }
}

/** A card that is one tap target, such as a collection tile. It shrinks a little while pressed (`press`). */
@Composable
public fun AwradCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    contentPadding: PaddingValues = PaddingValues(AwradTheme.spacing.cardPadding),
    spacing: Dp = AwradTheme.spacing.rowGap,
    content: @Composable ColumnScope.() -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    Surface(
        onClick = onClick,
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Card)
            .fillMaxWidth(),
        enabled = enabled,
        shape = AwradTheme.shapes.card,
        color = AwradTheme.colors.surface,
        contentColor = AwradTheme.colors.onSurface,
        interactionSource = interactionSource,
    ) {
        CardContent(contentPadding = contentPadding, spacing = spacing, content = content)
    }
}

@Composable
private fun CardContent(
    contentPadding: PaddingValues,
    spacing: Dp,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    CompositionLocalProvider(LocalAwradContainer provides AwradContainer.Surface) {
        Column(
            modifier = modifier.padding(contentPadding),
            verticalArrangement = Arrangement.spacedBy(spacing),
            content = content,
        )
    }
}
