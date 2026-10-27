package app.awrad.feature.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradCollectionTile
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr

/**
 * A dhikr in a list: a tile card with its title (`rowTitle`) over one line of its Arabic (`quranLine`, right to
 * left, ellipsized), and a trailing `chevron`. The whole row opens the dhikr.
 */
@Composable
internal fun DhikrRow(
    dhikr: Dhikr,
    language: ContentLanguage,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    AwradCard(onClick = onClick, modifier = modifier, size = AwradCardSize.Tile) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.inlineGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dhikr.title.localized(language),
                    style = AwradTheme.type.rowTitle,
                    color = colors.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                // Full width so the right-to-left line starts at the right and ellipsizes at the left.
                Text(
                    text = dhikr.arabicLines.joinToString(" "),
                    modifier = Modifier.fillMaxWidth(),
                    style = AwradTheme.type.quranLine.copy(textDirection = TextDirection.Rtl),
                    color = colors.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Icon(
                imageVector = AwradIcons.Chevron,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.icon),
                tint = colors.onSurfaceVariant,
            )
        }
    }
}

/** The collections as a row of tiles that scrolls sideways, inset by the page margin. */
@Composable
internal fun CollectionTilesRow(
    collections: List<Collection>,
    language: ContentLanguage,
    onOpen: (Collection) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = AwradTheme.spacing.pageMargin),
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
    ) {
        items(collections, key = { it.key }) { collection ->
            AwradCollectionTile(
                title = collection.title.localized(language),
                count = dhikrCount(collection.dhikrs.size),
                onClick = { onOpen(collection) },
            )
        }
    }
}
