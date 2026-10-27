package app.awrad.core.designsystem.component

import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import app.awrad.core.designsystem.R

/** The tokens have no logo size; this is the onboarding hero's. */
private val LogoSize = 148.dp

/**
 * The Awrad logo (misbaha ring and Arabic mark), 148 square unless [modifier] sizes it. Decorative: no content
 * description.
 */
@Composable
public fun AwradLogoMark(modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(
            if (isSystemInDarkTheme()) R.drawable.awrad_logo_dark else R.drawable.awrad_logo_light,
        ),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = modifier.size(LogoSize),
    )
}
