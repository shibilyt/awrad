package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
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
 * A collection of dhikrs on Home and in the Library: a `collectionTile` (128) square card with the `tile` shape
 * and the card's fill (`surface` on the page). The [title] (`rowTitle`, up to two lines) and the [count] ("100
 * Dhikrs", `caption`, `onSurfaceVariant`) sit at the top; a small round `forward` arrow (`roundButtonSmall`,
 * `primary`, flipped in RTL) at the bottom end. The whole tile is one tap target with the card's `press`; the
 * arrow is part of it, not a second button, so screen readers hear one button: the title and the count.
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
    AwradCard(
        onClick = onClick,
        modifier = modifier.size(AwradTheme.sizes.collectionTile),
        enabled = enabled,
        size = AwradCardSize.Tile,
        contentPadding = PaddingValues(spacing.md),
        spacing = spacing.xxs,
    ) {
        Text(
            text = title,
            style = AwradTheme.type.rowTitle,
            color = AwradTheme.colors.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = count,
            style = AwradTheme.type.caption,
            color = AwradTheme.colors.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(modifier = Modifier.weight(1f))
        ForwardArrow(modifier = Modifier.align(Alignment.End))
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
