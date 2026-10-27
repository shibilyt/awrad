package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.theme.AwradContainer
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.LocalAwradContainer

/**
 * Grouped content or a list item, without a border or shadow. It fills the other way from what it sits on:
 * `surface` on a `background`, `background` on a `surface` area such as the content sheet (it reads
 * [LocalAwradContainer] and sets it for its content, so fields inside follow). Rows inside are [spacing] apart,
 * never divided by lines. A list of rows that pad themselves passes a smaller [contentPadding] and no [spacing].
 */
@Composable
public fun AwradCard(
    modifier: Modifier = Modifier,
    size: AwradCardSize = AwradCardSize.Card,
    contentPadding: PaddingValues = PaddingValues(AwradTheme.spacing.cardPadding),
    spacing: Dp = AwradTheme.spacing.rowGap,
    content: @Composable ColumnScope.() -> Unit,
) {
    CardBody(
        modifier = modifier.cardFill(size.shape(), AwradTheme.fill),
        contentPadding = contentPadding,
        spacing = spacing,
        content = content,
    )
}

/**
 * A card that is one tap target, such as a goal or a collection tile. It shrinks a little while pressed
 * (`press`, `cardScale`); disabled, it's drawn at `states.disabled.opacity` and ignores taps.
 */
@Composable
public fun AwradCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    size: AwradCardSize = AwradCardSize.Card,
    contentPadding: PaddingValues = PaddingValues(AwradTheme.spacing.cardPadding),
    spacing: Dp = AwradTheme.spacing.rowGap,
    content: @Composable ColumnScope.() -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    CardBody(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Card)
            .disabledOpacity(enabled)
            .cardFill(size.shape(), AwradTheme.fill)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            ),
        contentPadding = contentPadding,
        spacing = spacing,
        content = content,
    )
}

@Composable
private fun AwradCardSize.shape(): Shape = when (this) {
    AwradCardSize.Card -> AwradTheme.shapes.card
    AwradCardSize.Tile -> AwradTheme.shapes.tile
}

/** [fill] is [AwradTheme.fill]: the other colour from where the card sits. */
private fun Modifier.cardFill(shape: Shape, fill: Color): Modifier = this
    .fillMaxWidth()
    .clip(shape)
    .background(fill)

@Composable
private fun CardBody(
    contentPadding: PaddingValues,
    spacing: Dp,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    // Content inside fills the other way again: a card on the background is a surface, and the reverse.
    val inside = when (LocalAwradContainer.current) {
        AwradContainer.Background -> AwradContainer.Surface
        AwradContainer.Surface -> AwradContainer.Background
    }
    CompositionLocalProvider(
        LocalAwradContainer provides inside,
        LocalContentColor provides AwradTheme.colors.onSurface,
    ) {
        Column(
            modifier = modifier.padding(contentPadding),
            verticalArrangement = Arrangement.spacedBy(spacing),
            content = content,
        )
    }
}
