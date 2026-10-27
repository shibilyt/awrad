package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * A label in a pill, such as a dhikr's tag: the `chip` shape (fully rounded) filled like a secondary control
 * (`secondaryContainer` on the page, `background` on a `surface` area), the [text] in `label` with its content
 * colour, padded `md` by `xs`. It isn't tappable.
 */
@Composable
public fun AwradChip(text: String, modifier: Modifier = Modifier) {
    val spacing = AwradTheme.spacing
    Text(
        text = text,
        modifier = modifier
            .heightIn(min = AwradTheme.sizes.navPillHeight)
            .background(AwradTheme.secondaryFill, AwradTheme.shapes.chip)
            .padding(horizontal = spacing.md, vertical = spacing.xs)
            .wrapContentHeight(),
        style = AwradTheme.type.label,
        color = AwradTheme.onSecondaryFill,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}
