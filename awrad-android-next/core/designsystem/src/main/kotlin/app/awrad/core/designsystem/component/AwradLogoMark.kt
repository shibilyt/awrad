package app.awrad.core.designsystem.component

import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import app.awrad.core.designsystem.R

/** The Awrad logo (misbaha ring and Arabic mark). Decorative: no content description. */
@Composable
public fun AwradLogoMark(modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(
            if (isSystemInDarkTheme()) R.drawable.awrad_logo_dark else R.drawable.awrad_logo_light,
        ),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = modifier,
    )
}
