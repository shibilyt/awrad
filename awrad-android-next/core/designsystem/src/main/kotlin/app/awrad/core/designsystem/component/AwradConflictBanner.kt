package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * The conflict banner (components.md, "Conflict banner"), at the top of a dhikr's page while it has an open
 * conflict: a `card`-shaped container padded `cardPadding` and filled `secondaryContainer` (never the `error`
 * roles), with the `error` icon (`icon` size) at the start and [text] ("Changed on another device") in `body`,
 * both `onSecondaryContainer`; then two text buttons aligned to the end, [keepMine] and [useTheirs], their
 * labels `onSecondaryContainer` too. It's announced when it appears.
 */
@Composable
public fun AwradConflictBanner(
    text: String,
    keepMine: String,
    useTheirs: String,
    onKeepMine: () -> Unit,
    onUseTheirs: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    val spacing = AwradTheme.spacing
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(AwradTheme.shapes.card)
            .background(colors.secondaryContainer)
            .padding(spacing.cardPadding)
            .semantics(mergeDescendants = false) { liveRegion = LiveRegionMode.Polite },
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(spacing.inlineGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = AwradIcons.Error,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.icon),
                tint = colors.onSecondaryContainer,
            )
            Text(text = text, style = AwradTheme.type.body, color = colors.onSecondaryContainer)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(spacing.sm, Alignment.End),
        ) {
            // On `secondaryContainer`, so `onSecondaryContainer` labels: `accent` is the fill's colour in dark mode.
            val onFill = AwradTextButtonFill.SecondaryContainer
            AwradTextButton(text = keepMine, onClick = onKeepMine, onFill = onFill)
            AwradTextButton(text = useTheirs, onClick = onUseTheirs, onFill = onFill)
        }
    }
}
