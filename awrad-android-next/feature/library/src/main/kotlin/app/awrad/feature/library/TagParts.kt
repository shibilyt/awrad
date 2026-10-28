package app.awrad.feature.library

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.UserTag

/**
 * The Library's tag filter: a chip per tag that scrolls sideways, then "Manage tags". A dhikr shows when it has
 * every selected tag.
 */
@Composable
internal fun TagFilterRow(
    tags: List<UserTag>,
    selected: Set<AwradId>,
    onToggle: (AwradId) -> Unit,
    onManage: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(start = spacing.pageMargin, end = spacing.pageMargin - spacing.md),
        horizontalArrangement = Arrangement.spacedBy(spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tags.forEach { tag ->
            key(tag.id.value) {
                AwradChip(text = tag.name, selected = tag.id in selected, onSelectedChange = { onToggle(tag.id) })
            }
        }
        AwradTextButton(text = stringResource(R.string.library_manage_tags), onClick = onManage)
    }
}

/**
 * The conflict banner ("Changed on another device"): this dhikr (or its tags) changed elsewhere after the edit
 * made here. **Keep mine** sends this phone's version again; **Use theirs** takes the other device's. Announced
 * when it appears.
 */
@Composable
internal fun ConflictBanner(
    message: String,
    onKeepMine: () -> Unit,
    onUseTheirs: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradCard(
        modifier = modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = false) { liveRegion = LiveRegionMode.Polite },
        spacing = AwradTheme.spacing.sm,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs)) {
            Text(
                text = stringResource(R.string.library_conflict_title),
                style = AwradTheme.type.cardTitle,
                color = AwradTheme.colors.onSurface,
            )
            Text(text = message, style = AwradTheme.type.bodySmall, color = AwradTheme.colors.onSurfaceVariant)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            AwradRowButton(
                text = stringResource(R.string.library_conflict_keep_mine),
                onClick = onKeepMine,
                variant = AwradButtonVariant.Main,
            )
            AwradRowButton(
                text = stringResource(R.string.library_conflict_use_theirs),
                onClick = onUseTheirs,
                variant = AwradButtonVariant.Secondary,
            )
        }
    }
}
