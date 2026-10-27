package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * A collection of dhikrs on Home and in the Library: a `collectionTile` (128) wide card with the `tile` shape, the
 * card's fill (`surface` on the page) and `cardPadding` inside; at least as tall as it is wide, and taller when the
 * text is larger. The [title] (`rowTitle`) takes up to two lines, breaking only between words; a word or a title
 * too long for them ends in an ellipsis. The [count] ("4 dhikrs", `caption`, `onSurfaceVariant`) sits under it,
 * and a small round `forward` arrow (`roundButtonSmall`, `primary`, flipped in RTL) at the bottom end. The whole
 * tile is one tap target with the card's `press`; the arrow is part of it, not a second button, so screen readers
 * hear one button: the title and the count. In a row of tiles, give the row `IntrinsicSize.Max` height and each
 * tile `fillMaxHeight()`, so a taller one (a larger font, a tall glyph such as ﷺ) doesn't leave the others short.
 */
@Composable
public fun AwradCollectionTile(
    title: String,
    count: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val spacing = AwradTheme.spacing
    val tile = AwradTheme.sizes.collectionTile
    AwradCard(
        onClick = onClick,
        modifier = modifier.width(tile),
        enabled = enabled,
        size = AwradCardSize.Tile,
        spacing = spacing.none,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .heightIn(min = tile - spacing.cardPadding * 2),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(spacing.xxs)) {
                WordWrapText(
                    text = title,
                    style = AwradTheme.type.rowTitle,
                    color = AwradTheme.colors.onSurface,
                    maxLines = 2,
                    width = tile - spacing.cardPadding * 2,
                )
                Text(
                    text = count,
                    style = AwradTheme.type.caption,
                    color = AwradTheme.colors.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            ForwardArrow(
                modifier = Modifier
                    .align(Alignment.End)
                    .padding(top = spacing.xxs),
            )
        }
    }
}

/** The round button's small face (components.md, "Round button"), without its own tap target. */
@Composable
private fun ForwardArrow(modifier: Modifier = Modifier) {
    val sizes = AwradTheme.sizes
    Box(
        modifier = modifier
            .size(sizes.roundButtonSmall)
            .clip(AwradTheme.shapes.roundButton)
            .background(AwradTheme.colors.primary),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = AwradIcons.Forward,
            contentDescription = null,
            modifier = Modifier.size(sizes.iconSmall),
            tint = AwradTheme.colors.onPrimary,
        )
    }
}
