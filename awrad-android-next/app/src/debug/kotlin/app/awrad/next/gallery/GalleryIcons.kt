package app.awrad.next.gallery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** How many icons the gallery shows per row. */
private const val ICONS_PER_ROW = 3

/** Every shared icon (`AwradIcons`) with its name in icons.json; `back` and `forward` flip in RTL. */
@Composable
internal fun IconsSection(modifier: Modifier = Modifier) {
    GallerySection(title = stringResource(R.string.gallery_section_icons), modifier = modifier) {
        AwradIcons.all.chunked(ICONS_PER_ROW).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
                row.forEach { (name, icon) -> IconSample(name = name, icon = icon, modifier = Modifier.weight(1f)) }
                repeat(ICONS_PER_ROW - row.size) { Spacer(modifier = Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun IconSample(name: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(AwradTheme.sizes.icon),
            tint = AwradTheme.colors.onSurface,
        )
        // The contract's name for the icon, not translated: it's what code uses.
        Text(text = name, style = AwradTheme.type.caption, color = AwradTheme.colors.onSurfaceVariant)
    }
}
